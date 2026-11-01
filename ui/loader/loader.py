#!/usr/bin/env python3
"""Dojo dummy loader.

A demonstration loader, not a benchmark: it runs a handful of cycles per minute
against the payload -- PromQL on Mimir, pushes and queries on Loki, trace search
on Tempo, health on Grafana -- and instruments itself with the OpenTelemetry SDK
so all three signals land in the stack it is exercising:

    spans   -> collector -> Tempo  -> traces_spanmetrics_* (service: dojo-loader)
    metrics -> collector -> Mimir  -> loader_cycles_total, loader_cycle_duration_seconds
    logs    -> collector -> Loki   -> {service_name="dojo-loader"}

It also injects the three things an exercise needs to be able to find:

    * failures   - an invalid PromQL query, a malformed Loki push and an unknown
                   Tempo route, each with a distinct span name and a non-2xx status
    * slowness   - a deliberately expensive range query, so p95 has a real spike
                   instead of a flat line
    * a heartbeat - healthy cycles, so the error ratio and latency have a baseline

Rate is deliberately low (one cycle every few seconds) and configurable through
LOADER_INTERVAL / ERROR_RATE / SLOW_RATE.
"""

from __future__ import annotations

import logging
import os
import random
import signal
import sys
import threading
import time
from typing import Callable

import requests
from opentelemetry import metrics, trace
from opentelemetry.exporter.otlp.proto.http._log_exporter import OTLPLogExporter
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

SERVICE_NAME = "dojo-loader"
SERVICE_VERSION = "1.0.0"

OTLP = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4318").rstrip("/")
MIMIR = os.environ.get("MIMIR_URL", "http://mimir:9009/prometheus").rstrip("/")
LOKI = os.environ.get("LOKI_URL", "http://loki:3100").rstrip("/")
TEMPO = os.environ.get("TEMPO_URL", "http://tempo:3200").rstrip("/")
GRAFANA = os.environ.get("GRAFANA_URL", "http://grafana:3000").rstrip("/")

INTERVAL = float(os.environ.get("LOADER_INTERVAL", "3.0"))
ERROR_RATE = float(os.environ.get("ERROR_RATE", "0.05"))
SLOW_RATE = float(os.environ.get("SLOW_RATE", "0.05"))
MAX_CYCLES = int(os.environ.get("LOADER_MAX_CYCLES", "0"))
# The backends in this stack answer in milliseconds, so a slow-dependency
# scenario has to add the delay itself; the span records it for what it is.
SLOW_DELAY = float(os.environ.get("SLOW_DELAY", "1.2"))
TIMEOUT = float(os.environ.get("LOADER_TIMEOUT", "10"))

resource = Resource.create(
    {
        "service.name": SERVICE_NAME,
        "service.version": SERVICE_VERSION,
        "service.instance.id": os.uname().nodename,
        "deployment.environment": "dojo",
        "telemetry.sdk.language": "python",
    }
)

tracer_provider = TracerProvider(resource=resource)
tracer_provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint=f"{OTLP}/v1/traces", timeout=10))
)
trace.set_tracer_provider(tracer_provider)
tracer = trace.get_tracer(SERVICE_NAME, SERVICE_VERSION)

metric_reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(endpoint=f"{OTLP}/v1/metrics", timeout=10),
    export_interval_millis=5000,
)
meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
metrics.set_meter_provider(meter_provider)
meter = metrics.get_meter(SERVICE_NAME, SERVICE_VERSION)

cycles = meter.create_counter("loader_cycles_total", description="Payload cycles run", unit="{cycle}")
errors = meter.create_counter("loader_errors_total", description="Payload cycles that failed", unit="{cycle}")
inflight = meter.create_up_down_counter("loader_inflight_cycles", description="Cycles in progress", unit="{cycle}")
cycle_seconds = meter.create_histogram(
    "loader_cycle_duration_seconds", description="Wall time per payload cycle", unit="s"
)
payload_bytes = meter.create_histogram(
    "loader_payload_bytes", description="Bytes returned by the payload", unit="By"
)
slo_breaches = meter.create_counter(
    "loader_slo_breaches_total", description="Cycles slower than the 500ms SLO", unit="{cycle}"
)

log_provider = LoggerProvider(resource=resource)
log_provider.add_log_record_processor(
    BatchLogRecordProcessor(OTLPLogExporter(endpoint=f"{OTLP}/v1/logs", timeout=10))
)
logging.basicConfig(level=logging.INFO, stream=sys.stdout)
logger = logging.getLogger(SERVICE_NAME)
logger.addHandler(LoggingHandler(level=logging.INFO, logger_provider=log_provider))
stream_handler = logging.StreamHandler(sys.stdout)
stream_handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
logger.addHandler(stream_handler)
logger.setLevel(logging.INFO)
logger.propagate = False

SLO_SECONDS = 0.5


# --- healthy cycles: the baseline -------------------------------------------
def mimir_query() -> tuple[str, str, dict]:
    return "GET", f"{MIMIR}/api/v1/query", {"params": {"query": "count(kube_pod_info)"}}


def mimir_series() -> tuple[str, str, dict]:
    return "GET", f"{MIMIR}/api/v1/series", {"params": {"match[]": '{job="kube-state-metrics"}'}}


def loki_push() -> tuple[str, str, dict]:
    now = time.time_ns()
    body = {
        "streams": [
            {
                "stream": {"service_name": SERVICE_NAME, "source": "dummy-loader"},
                "values": [[str(now), f"loader heartbeat {int(now / 1e9)}"]],
            }
        ]
    }
    return "POST", f"{LOKI}/loki/api/v1/push", {"json": body}


def loki_query() -> tuple[str, str, dict]:
    end = time.time_ns()
    return (
        "GET",
        f"{LOKI}/loki/api/v1/query_range",
        {
            "params": {
                "query": '{service_name=~"dojo-loader|worker"}',
                "limit": 5,
                "start": end - 600 * 10**9,
                "end": end,
            }
        },
    )


def tempo_search() -> tuple[str, str, dict]:
    return "GET", f"{TEMPO}/api/search", {"params": {"limit": 5}}


def grafana_health() -> tuple[str, str, dict]:
    return "GET", f"{GRAFANA}/api/health", {}


HEALTHY: dict[str, Callable[[], tuple[str, str, dict]]] = {
    "mimir_query": mimir_query,
    "mimir_series": mimir_series,
    "loki_push": loki_push,
    "loki_query": loki_query,
    "tempo_search": tempo_search,
    "grafana_health": grafana_health,
}


# --- injected faults: things to find in the dashboards ----------------------
def mimir_bad_query() -> tuple[str, str, dict]:
    """PromQL the server rejects: 400, a real parse error in the body."""
    return "GET", f"{MIMIR}/api/v1/query", {"params": {"query": "sum(rate( up [5m]" }}


def loki_bad_push() -> tuple[str, str, dict]:
    """A push with an unparseable timestamp: Loki answers 400."""
    return (
        "POST",
        f"{LOKI}/loki/api/v1/push",
        {
            "json": {
                "streams": [
                    {
                        "stream": {"service_name": SERVICE_NAME, "source": "dummy-loader"},
                        "values": [["not-a-timestamp", "loader: deliberate bad push"]],
                    }
                ]
            }
        },
    )


def tempo_unknown_route() -> tuple[str, str, dict]:
    """A route Tempo does not serve: 404, visible as a failed span."""
    return "GET", f"{TEMPO}/api/v2/definitely-not-a-route", {}


def grafana_missing_dashboard() -> tuple[str, str, dict]:
    """Grafana answers 404 for a dashboard uid that does not exist."""
    return "GET", f"{GRAFANA}/api/dashboards/uid/dojo-not-a-dashboard", {}


FAULTS: dict[str, Callable[[], tuple[str, str, dict]]] = {
    "mimir_bad_query": mimir_bad_query,
    "loki_bad_push": loki_bad_push,
    "tempo_unknown_route": tempo_unknown_route,
    "grafana_missing_dashboard": grafana_missing_dashboard,
}


# --- injected slowness: a p95 spike to find --------------------------------
def slow_backend() -> tuple[str, str, dict]:
    """A dependency that takes ~SLOW_DELAY seconds to answer.

    The HTTP call itself is real (Grafana health); the delay stands in for a
    backend that is slow in production, which is the performance problem the
    exercise is meant to surface. The span carries loader.simulated_delay so the
    delay is never mistaken for real server time.
    """
    return "GET", f"{GRAFANA}/api/health", {"simulate_delay": SLOW_DELAY}


SLOW: dict[str, Callable[[], tuple[str, str, dict]]] = {
    "slow_backend": slow_backend,
}

stop = threading.Event()


def handle_signal(signum, _frame):
    logger.info("received signal %s, flushing telemetry", signum)
    stop.set()


def run_cycle(name: str, factory: Callable[[], tuple[str, str, dict]], kind: str) -> None:
    method, url, kwargs = factory()
    delay = float(kwargs.pop("simulate_delay", 0) or 0)
    inflight.add(1, {"scenario": name, "kind": kind})
    started = time.monotonic()
    status_code = 0
    size = 0
    ok = False
    with tracer.start_as_current_span(f"payload.{name}") as span:
        span.set_attribute("loader.scenario", name)
        span.set_attribute("loader.kind", kind)
        span.set_attribute("http.request.method", method)
        span.set_attribute("url.full", url)
        try:
            with tracer.start_as_current_span("http.client.request") as http_span:
                http_span.set_attribute("http.request.method", method)
                http_span.set_attribute("server.address", url.split("/")[2])
                http_span.set_attribute("url.full", url)
                response = requests.request(method, url, timeout=TIMEOUT, **kwargs)
                status_code = response.status_code
                size = len(response.content)
                http_span.set_attribute("http.response.status_code", status_code)
                http_span.set_attribute("http.response.body.size", size)
                ok = response.ok
                if not ok:
                    http_span.set_status(
                        trace.Status(trace.StatusCode.ERROR, f"HTTP {status_code}")
                    )
        except requests.RequestException as exc:
            span.record_exception(exc)
            ok = False

        if delay:
            span.set_attribute("loader.simulated_delay_seconds", delay)
            time.sleep(delay)

        elapsed = time.monotonic() - started
        span.set_attribute("loader.ok", ok)
        span.set_attribute("http.response.status_code", status_code)
        span.set_attribute("loader.duration_seconds", elapsed)
        if not ok:
            span.set_status(trace.Status(trace.StatusCode.ERROR, f"HTTP {status_code}"))

    attributes = {"scenario": name, "kind": kind, "status": "ok" if ok else "error"}
    cycles.add(1, attributes)
    cycle_seconds.record(elapsed, {"scenario": name, "kind": kind})
    payload_bytes.record(size, {"scenario": name, "kind": kind})
    if elapsed > SLO_SECONDS:
        slo_breaches.add(1, {"scenario": name})

    if not ok:
        errors.add(1, attributes)
        logger.warning("cycle %s failed status=%s duration_ms=%.1f", name, status_code, elapsed * 1000)
    elif elapsed > SLO_SECONDS:
        logger.warning(
            "cycle %s slow duration_ms=%.1f (SLO %.0fms)", name, elapsed * 1000, SLO_SECONDS * 1000
        )
    else:
        logger.info(
            "cycle %s ok status=%s bytes=%d duration_ms=%.1f",
            name,
            status_code,
            size,
            elapsed * 1000,
        )
    inflight.add(-1, {"scenario": name, "kind": kind})


def pick() -> tuple[str, Callable[[], tuple[str, str, dict]], str]:
    roll = random.random()
    if roll < SLOW_RATE and SLOW:
        name = random.choice(sorted(SLOW))
        return name, SLOW[name], "slow"
    if roll < SLOW_RATE + ERROR_RATE and FAULTS:
        name = random.choice(sorted(FAULTS))
        return name, FAULTS[name], "fault"
    name = random.choice(sorted(HEALTHY))
    return name, HEALTHY[name], "healthy"


def main() -> int:
    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    logger.info(
        "dummy loader starting: otlp=%s interval=%ss error_rate=%s slow_rate=%s max_cycles=%s",
        OTLP,
        INTERVAL,
        ERROR_RATE,
        SLOW_RATE,
        MAX_CYCLES or "unlimited",
    )

    count = 0
    while not stop.is_set():
        name, factory, kind = pick()
        run_cycle(name, factory, kind)
        count += 1
        if MAX_CYCLES and count >= MAX_CYCLES:
            break
        stop.wait(INTERVAL)

    logger.info("dummy loader stopping after %d cycles", count)
    tracer_provider.force_flush(timeout_millis=5000)
    meter_provider.force_flush(timeout_millis=5000)
    log_provider.force_flush(timeout_millis=5000)
    tracer_provider.shutdown()
    meter_provider.shutdown()
    log_provider.shutdown()
    return 0


if __name__ == "__main__":
    sys.exit(main())
