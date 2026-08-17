# IaC — VCF 9.1 Brownfield (adopt-then-expand)

Terraform for adopting a brownfield VMware Cloud Foundation 9.1 estate and
expanding the resulting fleet. It uses the official providers `vmware/vcf`,
`vmware/vsphere`, and `vmware/nsxt`.

## Model: manual gates + IaC

Brownfield onboarding has two entry paths, and **both are manual gates** —
the `vmware/vcf` provider has no converge/import resource:

| Path | Where | What it does |
| --- | --- | --- |
| **Converge** | VCF Installer UI | Turns your existing standalone vSphere into your **first** VCF 9.1 management domain. |
| **Import** | VCF Operations UI | Adds an existing vCenter (with vSAN/NSX) to an **existing** fleet as a VI workload domain. |

After a gate completes, this IaC **adopts** the resulting domain (read-only
`data "vcf_domain"`) and then **expands** the fleet with new network pools,
hosts, workload domains, edge clusters, and Supervisors.

## Layout

```
iac/
├── config/
│   ├── site.example.yaml   # single source of truth — copy to site.yaml (git-ignored)
│   └── README.md           # schema reference
├── modules/
│   ├── adopt-domain/       # data "vcf_domain" — adopt converged/imported domains
│   ├── network-pool/       # vcf_network_pool
│   ├── host-commission/    # vcf_host
│   ├── workload-domain/    # vcf_domain (new VI WLD)
│   ├── cluster/            # vcf_cluster (add cluster to a domain)
│   ├── edge-cluster/       # vcf_edge_cluster (Tier-0/Tier-1 + eBGP)
│   └── supervisor/         # vsphere_supervisor (vSphere IaaS / Tanzu)
├── stages/
│   ├── 10-converge/              # adopt the converged management domain
│   ├── 20-import-workload-domain/# adopt imported vCenter workload domains
│   ├── 30-network-pools/         # create network pools (fleet expansion)
│   ├── 40-host-commission/       # commission ESX hosts
│   ├── 50-workload-domain/       # create a new VI workload domain
│   ├── 60-edge-cluster/          # deploy NSX Edge cluster
│   └── 70-supervisor/            # activate vSphere Supervisor
└── scripts/
    ├── preflight.sh        # read-only DNS/NTP/tooling checks
    ├── deploy-installer.sh # deploy the VCF Installer OVA (converge entry point)
    └── thumbprints.sh      # collect SSL/SSH thumbprints
```

Each stage keeps **isolated Terraform state** and reads the shared
`config/site.yaml`. Run stages in order; the manual converge/import gates
happen before stages 10/20 respectively (see `docs/deployment/`).

## Quick start

```bash
# 1. Create your site definition
make site                      # copies site.example.yaml -> site.yaml
$EDITOR iac/config/site.yaml

# 2. Provide secrets via environment (never in site.yaml)
export TF_VAR_sddc_manager_password='********'
export TF_VAR_host_password='********'
export TF_VAR_vcenter_root_password='********'
export TF_VAR_nsx_admin_password='********'
export TF_VAR_sso_domain_password='********'
export TF_VAR_edge_admin_password='********'
export TF_VAR_edge_audit_password='********'
export TF_VAR_edge_root_password='********'
export TF_VAR_bgp_peer_password='********'
export TF_VAR_vsphere_password='********'

# 3. Validate everything
make fmt-check
make validate

# 4. Run a stage
make plan  STAGE=30-network-pools
make apply STAGE=30-network-pools
```

## Requirements

- Terraform >= 1.7 (CI pins 1.9.8)
- VCF 9.1 fleet reachable from where you run Terraform
- Providers (pinned in each stage's `.terraform.lock.hcl`):
  `vmware/vcf 0.18.1`, `vmware/vsphere 2.16.1`, `vmware/nsxt 3.12.0`

## Notes

- **This framework is VCF 9.1 only.** The `version` key in `site.yaml`
  documents the target BOM; imported domains enter at their earliest
  component version and are upgraded to 9.1 afterward.
- Secrets are supplied only through `TF_VAR_*` environment variables.
  `site.yaml` and `*.tfvars` are git-ignored.
