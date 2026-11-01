.PHONY: help setup up reset down teardown destroy list next check apply solution edit tui status cluster selftest ui ui-down ui-status target-state target-state-clear

SHELL := /bin/bash
CTX ?= aks-dojo-dev
KUBECONFIG := $(CURDIR)/.dojo/kubeconfig
export KUBECONFIG

help:
	@printf '\nk9s-dojo\n\n'
	@sed -n 's/^\([a-z-]*\):.*##\s*\(.*\)/  make \1\t\2/p' Makefile
	@printf '\n'

setup: cluster ## build the sample clusters and seed them, then hint the first step
	@printf '\nNext: make tui    (then: make next)\n\n'

cluster: ## create the sample cluster and apply the sample workloads
	@bin/cluster up

up: cluster ## alias for make cluster
	@:

reset: ## delete and rebuild the cluster from scratch
	@bin/cluster reset

down: reset ## alias for make reset
	@:

teardown: ## delete the clusters, keep the repository and the live UIs
	@bin/cluster down

destroy: ## stop the UIs, delete the clusters and remove all temporary state
	@bin/destroy

selftest: ## run every exercise with its reference answers (mutates the cluster)
	@bin/selftest

status: ## show cluster and exercise progress
	@bin/cluster status
	@bin/dojo progress

list: ## list every exercise and whether it is done
	@bin/dojo list

next: ## show the exercise you should be doing
	@bin/dojo next

check: ## verify the current exercise, or `make check N=04`
	@bin/dojo check $(N)

apply: ## apply an exercise's manifests, e.g. `make apply N=17`
	@bin/dojo apply $(N)

solution: ## print the reference answers, e.g. `make solution N=04`
	@bin/dojo solution $(N)

edit: ## open the exercise answer file, e.g. `make edit N=04`
	@bin/dojo edit $(N)

target-state: ## build the finished capstone so it can be inspected live
	@bin/target-state apply

target-state-clear: ## remove the target state again
	@bin/target-state clear

ui: ## start the live LGTM UIs (Grafana on :3000, Tempo on :3200)
	@bin/ui up

ui-down: ## stop the live LGTM UIs
	@bin/ui down

ui-status: ## show which live UIs answer
	@bin/ui status

tui: ## run k9s against a dojo cluster (make tui CTX=aks-dojo-prod)
	@K9S_CONFIG_DIR=$(CURDIR)/k9s-config k9s --context $(CTX)
