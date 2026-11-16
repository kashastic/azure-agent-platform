# One way to run every stack, locally and in CI.
#
#   make plan STACK=foundation     plan one stack (writes tfplan)
#   make apply STACK=foundation    apply that saved plan
#   make destroy STACK=aks         destroy one stack
#   make up                        foundation -> access -> aks -> platform
#   make down                      platform -> aks (the cheap foundation stays)
#   make kubeconfig                point kubectl at the cluster (Entra ID sign-in)

ENV   ?= dev
STACK ?= foundation
DIR   := infra/envs/$(ENV)/$(STACK)
TF    := terraform -chdir=$(DIR)

.PHONY: init plan apply destroy up down kubeconfig fmt

init:
	$(TF) init -backend-config=../backend.hcl

plan: init
	$(TF) plan -var-file=../common.tfvars -out=tfplan

apply:
	$(TF) apply tfplan

destroy: init
	$(TF) destroy -var-file=../common.tfvars

up:
	@for stack in foundation access aks platform; do \
		$(MAKE) plan apply STACK=$$stack || exit 1; \
	done

down:
	$(MAKE) destroy STACK=platform
	$(MAKE) destroy STACK=aks

kubeconfig:
	az aks get-credentials --resource-group rg-agentplat-$(ENV)-aks --name aks-agentplat-$(ENV) --overwrite-existing
	kubelogin convert-kubeconfig -l azurecli

fmt:
	terraform fmt -recursive infra
