# =====================================================================
# Loyapally's VCF 9.1 Brownfield Deployment Framework
# =====================================================================
SHELL := /bin/bash

IAC_DIR    := iac
STAGES_DIR := $(IAC_DIR)/stages
SITE       := $(IAC_DIR)/config/site.yaml
STAGES     := $(sort $(notdir $(wildcard $(STAGES_DIR)/*)))

# Usage: make plan STAGE=30-network-pools
STAGE ?=

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@echo "Loyapally's VCF 9.1 Brownfield Deployment Framework"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Stages: $(STAGES)"
	@echo "Run a single stage:  make plan STAGE=30-network-pools"

.PHONY: preflight
preflight: ## Run environment preflight checks (DNS/NTP/tooling)
	@$(IAC_DIR)/scripts/preflight.sh

.PHONY: fmt
fmt: ## Format all Terraform files
	@cd $(IAC_DIR) && terraform fmt -recursive

.PHONY: fmt-check
fmt-check: ## Check Terraform formatting (CI)
	@cd $(IAC_DIR) && terraform fmt -recursive -check

.PHONY: validate
validate: ## terraform init + validate every stage
	@set -e; for s in $(STAGES); do \
		echo "==> validate $$s"; \
		( cd $(STAGES_DIR)/$$s && terraform init -input=false -backend=false >/dev/null && terraform validate ); \
	done

.PHONY: lock
lock: ## Regenerate multi-platform provider lock files for every stage
	@set -e; for s in $(STAGES); do \
		echo "==> lock $$s"; \
		( cd $(STAGES_DIR)/$$s && terraform providers lock \
			-platform=linux_amd64 -platform=darwin_amd64 \
			-platform=darwin_arm64 -platform=windows_amd64 ); \
	done

.PHONY: init
init: _require_stage ## Init a single stage (STAGE=...)
	@cd $(STAGES_DIR)/$(STAGE) && terraform init -input=false

.PHONY: plan
plan: _require_stage ## Plan a single stage (STAGE=...)
	@cd $(STAGES_DIR)/$(STAGE) && terraform init -input=false >/dev/null && terraform plan

.PHONY: apply
apply: _require_stage ## Apply a single stage (STAGE=...)
	@cd $(STAGES_DIR)/$(STAGE) && terraform init -input=false >/dev/null && terraform apply

.PHONY: _require_stage
_require_stage:
	@if [ -z "$(STAGE)" ]; then echo "ERROR: set STAGE=<stage>, e.g. make plan STAGE=30-network-pools"; exit 1; fi
	@if [ ! -d "$(STAGES_DIR)/$(STAGE)" ]; then echo "ERROR: unknown stage '$(STAGE)'. Stages: $(STAGES)"; exit 1; fi

.PHONY: site
site: ## Create iac/config/site.yaml from the example if missing
	@if [ -f "$(SITE)" ]; then echo "$(SITE) already exists"; else cp $(IAC_DIR)/config/site.example.yaml $(SITE) && echo "created $(SITE)"; fi
