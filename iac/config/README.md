# `site.yaml` schema

`site.yaml` is the single source of truth consumed by every stage. Copy
`site.example.yaml` to `site.yaml` (git-ignored) and edit it for your site.
**Never put passwords in this file** — all secrets are provided through
`TF_VAR_*` environment variables (see `iac/README.md`).

## Top-level keys

| Key | Used by | Purpose |
| --- | --- | --- |
| `version` | all / docs | Target VCF BOM. This framework is pinned to `9.1.0.0`. |
| `fleet.sddc_manager` | adopt + expand stages | SDDC Manager host/username for the `vcf` provider. |
| `fleet.installer` | converge gate / stage 10 | VCF Installer host/username. |
| `fleet.allow_unverified_tls` | providers | `true` only for labs with self-signed certs. |
| `infra` | stage 70, preflight | DNS domain, DNS servers, NTP servers. |
| `adoption.management_domain_name` | stage 10 | Name of the converged management domain to adopt. |
| `adoption.imported_workload_domains[]` | stage 20 | Names of imported vCenter workload domains to adopt. |
| `network_pools[]` | stage 30 | vSAN/vMotion VLANs, subnets, IP ranges. |
| `hosts_to_commission[]` | stage 40 | ESX hosts to commission (fqdn, username, storage_type, pool). |
| `new_workload_domain` | stage 50 | vCenter/NSX/SSO/cluster spec for a new VI workload domain. |
| `edge_cluster` | stage 60 | Tier-0/Tier-1 edge nodes, uplinks, BGP peers. |
| `supervisor` | stage 70 | Supervisor cluster, networks, CIDRs, namespace. |

## Secret mapping (environment variables)

| `TF_VAR_*` | Consumed by |
| --- | --- |
| `TF_VAR_sddc_manager_password` | all adopt/expand stages (SDDC Manager) |
| `TF_VAR_installer_password` | converge gate (Installer UI) |
| `TF_VAR_host_password` | stage 40 (ESX root) |
| `TF_VAR_vcenter_root_password` | stage 50 (new vCenter root) |
| `TF_VAR_nsx_admin_password` / `TF_VAR_nsx_audit_password` | stage 50 (NSX) |
| `TF_VAR_sso_domain_password` | stage 50 (SSO) |
| `TF_VAR_edge_admin_password` / `TF_VAR_edge_audit_password` / `TF_VAR_edge_root_password` | stage 60 (edge nodes) |
| `TF_VAR_bgp_peer_password` | stage 60 (BGP peers) |
| `TF_VAR_vsphere_password` | stage 70 (Supervisor vCenter) |

Optional keys use `try(...)` in the stages, so you can omit expansion
sections you don't need.
