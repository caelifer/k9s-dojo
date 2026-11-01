.PHONY: help setup up reset down teardown list next check solution edit tui status cluster

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

teardown: ## delete the cluster, keep the repository
	@bin/cluster down

status: ## show cluster and exercise progress
	@bin/cluster status
	@bin/dojo progress

list: ## list every exercise and whether it is done
	@bin/dojo list

next: ## show the exercise you should be doing
	@bin/dojo next

check: ## verify the current exercise, or `make check N=04`
	@bin/dojo check $(N)

solution: ## print the reference answers, e.g. `make solution N=04`
	@bin/dojo solution $(N)

edit: ## open the exercise answer file, e.g. `make edit N=04`
	@bin/dojo edit $(N)

tui: ## run k9s against a dojo cluster (make tui CTX=aks-dojo-prod)
	@K9S_CONFIG_DIR=$(CURDIR)/k9s-config k9s --context $(CTX)
