# Loyapally's VCF 9.1 Brownfield Deployment Framework

Onboard an existing (brownfield) vSphere estate into VMware Cloud Foundation
9.1 and then grow it as code. Onboarding happens through one of two manual
gates — **converge** (VCF Installer UI: standalone vSphere → first VCF 9.1
management domain) or **import** (VCF Operations UI: existing vCenter → VI
workload domain in an existing fleet) — after which the Terraform in
[`iac/`](iac/README.md) **adopts** the resulting domain read-only and
**expands** the fleet with network pools, hosts, workload domains, edge
clusters, and Supervisors.

## Repository layout

```
.
├── iac/                     # Terraform: adopt-then-expand a VCF 9.1 fleet
│   ├── config/              # site.example.yaml — single source of truth
│   ├── modules/             # adopt-domain, network-pool, host-commission,
│   │                        #   workload-domain, cluster, edge-cluster, supervisor
│   ├── stages/              # 10-converge → 70-supervisor (isolated state each)
│   └── scripts/             # preflight.sh, deploy-installer.sh, thumbprints.sh
├── docs/
│   ├── design/              # methodology, converge vs. import, readiness, ...
│   ├── deployment/          # prerequisites, architecture, runbooks
│   └── operations/          # day-2 operations, troubleshooting
├── Makefile                 # site, preflight, fmt-check, validate, lock, plan, apply
└── .github/                 # CI workflow (terraform.yml)
```

## Where to start

| I want to… | Go to… |
| --- | --- |
| Understand the code layout, stages, and modules | [`iac/README.md`](iac/README.md) |
| Understand the methodology and design decisions | [`docs/design/README.md`](docs/design/README.md) |
| Onboard an estate (converge/import runbooks, prerequisites) | [`docs/deployment/README.md`](docs/deployment/README.md) |
| Operate the fleet day-2 and troubleshoot | [`docs/operations/README.md`](docs/operations/README.md) |

## Quick start

```bash
# 1. Create your site definition (single source of truth)
make site                      # copies site.example.yaml -> site.yaml (git-ignored)
$EDITOR iac/config/site.yaml

# 2. Provide secrets via environment only (never in site.yaml)
export TF_VAR_sddc_manager_password='********'
# ...plus the other TF_VAR_* secrets your stages need

# 3. Validate every stage
make validate

# 4. Run a stage
make plan  STAGE=30-network-pools
make apply STAGE=30-network-pools
```

## Requirements

- Terraform >= 1.7
- Providers: `vmware/vcf 0.18.1`, `vmware/vsphere 2.16.1`, `vmware/nsxt 3.12.0`
- A reachable VCF 9.1 fleet (converge/import gate completed for the domain you adopt)

The framework is pinned to VCF 9.1 only and is validated with
`terraform validate` across all stages.
