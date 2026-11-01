#!/usr/bin/env python3
"""Write a kubeconfig the live UI containers can use.

The dojo API servers listen on the host loopback, so a container cannot reach
127.0.0.1. This rewrites the selected context to the container host alias and
disables certificate verification (the serving certificate has a 127.0.0.1 SAN,
not the alias), which is what the collector's k8s_events receiver needs.

usage: kubeconfig-ui.py SOURCE TARGET CONTEXT HOST
"""
import sys

import yaml


def main() -> None:
    source_path, target_path, context_name, host = sys.argv[1:5]
    with open(source_path, encoding="utf-8") as handle:
        config = yaml.safe_load(handle)

    context = next(c for c in config["contexts"] if c["name"] == context_name)
    cluster_name = context["context"]["cluster"]
    cluster = next(c for c in config["clusters"] if c["name"] == cluster_name)

    server = cluster["cluster"]["server"]
    host_port = server.rsplit("/", 1)[-1]  # 127.0.0.1:32764
    port = host_port.rsplit(":", 1)[-1]
    cluster["cluster"]["server"] = f"https://{host}:{port}"
    cluster["cluster"].pop("certificate-authority-data", None)
    cluster["cluster"]["insecure-skip-tls-verify"] = True
    config["clusters"] = [cluster]
    config["contexts"] = [context]
    config["users"] = [
        u for u in config["users"] if u["name"] == context["context"]["user"]
    ]
    config["current-context"] = context_name

    with open(target_path, "w", encoding="utf-8") as handle:
        yaml.safe_dump(config, handle, sort_keys=False)


if __name__ == "__main__":
    main()
