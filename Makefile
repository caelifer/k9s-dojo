.PHONY: help doctor bootstrap deps setup up reset down teardown destroy list next check apply solution edit tui status cluster selftest ui ui-down ui-status target-state target-state-clear

SHELL := /bin/bash
CTX ?= aks-dojo-dev
KUBECONFIG := $(CURDIR)/.dojo/kubeconfig
export KUBECONFIG

# Every recipe runs inside the mise environment, so k9s, kubectl, kwokctl, python
# and their dependencies come from mise.toml instead of the host package manager.
RUN := mise exec --

help:
	@printf '\nk9s-dojo\n\n'
	@sed -n 's/^\([a-z-]*\):.*##\s*\(.*\)/  make \1\t\2/p' Makefile
	@printf '\n'

doctor: ## check host prerequisites (kernel, user namespaces, ports, toolchain)
	@bin/doctor

bootstrap: ## one-time per checkout: trust mise.toml, install the pinned toolchain
	@bin/bootstrap

deps: bootstrap ## alias for make bootstrap
	@:

setup: bootstrap cluster ## install the toolchain, build the clusters, hint the first step
	@printf '\nNext: make tui    (then: make next)\n\n'

cluster: ## create the sample clusters and apply the sample workloads
	@$(RUN) bin/cluster up

up: cluster ## alias for make cluster
	@:

reset: ## delete and rebuild the clusters from scratch
	@$(RUN) bin/cluster reset

down: reset ## alias for make reset
	@:

teardown: ## delete the clusters, keep the repository and the live UIs
	@$(RUN) bin/cluster down

destroy: ## stop the UIs, delete the clusters and remove all temporary state
	@$(RUN) bin/destroy

selftest: ## run every exercise with its reference answers (mutates the cluster)
	@$(RUN) bin/selftest

status: ## show cluster and exercise progress
	@$(RUN) bin/cluster status
	@$(RUN) bin/dojo progress

list: ## list every exercise and whether it is done
	@$(RUN) bin/dojo list

next: ## show the exercise you should be doing
	@$(RUN) bin/dojo next

check: ## verify the current exercise, or `make check N=04`
	@$(RUN) bin/dojo check $(N)

apply: ## apply an exercise's manifests, e.g. `make apply N=17`
	@$(RUN) bin/dojo apply $(N)

solution: ## print the reference answers, e.g. `make solution N=04`
	@$(RUN) bin/dojo solution $(N)

edit: ## open the exercise answer file, e.g. `make edit N=04`
	@$(RUN) bin/dojo edit $(N)

target-state: ## build the finished capstone so it can be inspected live
	@$(RUN) bin/target-state apply

target-state-clear: ## remove the target state again
	@$(RUN) bin/target-state clear

ui: ## start the live LGTM UIs (Grafana on :3000, Tempo on :3200)
	@$(RUN) bin/ui up

ui-down: ## stop the live LGTM UIs
	@$(RUN) bin/ui down

ui-status: ## show which live UIs answer
	@$(RUN) bin/ui status

tui: ## run k9s against a dojo cluster (make tui CTX=aks-dojo-prod)
	@K9S_CONFIG_DIR=$(CURDIR)/k9s-config $(RUN) k9s --context $(CTX)
