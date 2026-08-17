# 09 — Design Decisions Register

This register captures the **default** design decisions this framework makes for
brownfield onboarding into **VMware Cloud Foundation 9.1**. Each decision has a
stable ID, a rationale, and a tie to the `site.yaml` key and/or stage that
implements it. Deviating from a default is a deliberate choice and should be
recorded per site.

| ID | Decision | Rationale | Ties to |
| --- | --- | --- | --- |
| BF-001 | Adopt brownfield domains via the read-only `vcf_domain` **data source**, not a Terraform import-resource | Neither converge nor import has a `vmware/vcf` resource; reading the domain keeps the manual gates authoritative and never lets Terraform create/destroy the adopted domain | `adoption.*`; [`10-converge`](../../iac/stages/10-converge), [`20-import-workload-domain`](../../iac/stages/20-import-workload-domain), [`adopt-domain`](../../iac/modules/adopt-domain) |
| BF-002 | Converge when no VCF exists; import when a VCF fleet exists | Matches the two supported manual entry paths and their preconditions | `version`, `fleet.installer`, `fleet.sddc_manager`; [01-converge-vs-import-vs-upgrade.md](./01-converge-vs-import-vs-upgrade.md) |
| BF-003 | **vSAN ESA** is the default storage | ESA is the VCF 9.1 default and requires vLCM images (already a converge prerequisite) | `new_workload_domain.cluster.vsan.esa_enabled`; [`workload-domain`](../../iac/modules/workload-domain), [06-storage.md](./06-storage.md) |
| BF-004 | Size clusters from **FTT → RAID → host count** | Ensures the cluster has enough hosts to satisfy the chosen resiliency (FTT=1/RAID-5 ≥ 4–5 hosts; FTT=2 ≥ 6–7) | `new_workload_domain.cluster.vsan.failures_to_tolerate`, `hosts_to_commission`; [06-storage.md](./06-storage.md) |
| BF-005 | NSX must be a **3-node NSX Manager cluster** | Only supported NSX setup for VCF workload domains | `new_workload_domain.nsx`; [05-nsx-coexistence.md](./05-nsx-coexistence.md) |
| BF-006 | Treat DFW as **default-on after import** | Import activates NSX on DPGs, switching on the Distributed Firewall across workloads | [`20-import-workload-domain`](../../iac/stages/20-import-workload-domain); [05-nsx-coexistence.md](./05-nsx-coexistence.md), [07-security-and-identity.md](./07-security-and-identity.md) |
| BF-007 | Deploy the **edge cluster before the Supervisor** | Supervisor ingress/egress ride the Tier-0 gateway | `edge_cluster`, `supervisor`; [`60-edge-cluster`](../../iac/stages/60-edge-cluster) before [`70-supervisor`](../../iac/stages/70-supervisor) |
| BF-008 | Create the **network pool before commissioning hosts** | Host vSAN/vMotion/TEP addressing must exist before a cluster is formed | `network_pools`, `hosts_to_commission`; [`30-network-pools`](../../iac/stages/30-network-pools) before [`40-host-commission`](../../iac/stages/40-host-commission) |
| BF-009 | Tier-0 uses **eBGP with ECMP** (active-active) | Resilient, multi-path north-south routing to the physical fabric | `edge_cluster.routing_type`, `edge_cluster.high_availability`; [`edge-cluster`](../../iac/modules/edge-cluster), [05-nsx-coexistence.md](./05-nsx-coexistence.md) |
| BF-010 | **Secrets only via `TF_VAR_*`** environment variables, never in `site.yaml` | Keeps the single source of truth safe to commit/share; no plaintext credentials | all `TF_VAR_*`; [07-security-and-identity.md](./07-security-and-identity.md) |
| BF-011 | Framework is **pinned to VCF 9.1 only** | Deterministic behavior against one release; `version: 9.1.0.0` | `version`; [00-methodology.md](./00-methodology.md) |
| BF-012 | Pin providers: `vmware/vcf` 0.18.1, `vmware/vsphere` 2.16.1, `vmware/nsxt` 3.12.0 | Reproducible plans/applies across environments | each stage's `versions.tf` |
| BF-013 | **Isolated per-stage Terraform state** | Limits blast radius; each numbered stage plans/applies independently and passes IDs forward | [`../../iac/stages`](../../iac/stages) (`10`–`70`) |
| BF-014 | Validate readiness with **`preflight.sh`** before any gate | Catches DNS/NTP/SSH/vLCM/DRS/SDDC-extension issues before manual work begins | [`../../iac/scripts/preflight.sh`](../../iac/scripts/preflight.sh); [02-readiness-and-prerequisites.md](./02-readiness-and-prerequisites.md) |
| BF-015 | **Upgrade after adoption** through VCF Operations to reach full 9.1 | Imported domains enter at the earliest component's version; features require all components at 9.1 | VCF Operations lifecycle; [08-post-adoption-lifecycle-upgrade.md](./08-post-adoption-lifecycle-upgrade.md) |
| BF-016 | **All clusters of a vCenter onboard together** | Partial/subset import is not supported | [03-supported-scenario-matrix.md](./03-supported-scenario-matrix.md), [04-domain-mapping.md](./04-domain-mapping.md) |
| BF-017 | Non-vSAN principal datastores are **out of default scope** | Default design targets vSAN ESA for expansion and retains existing vSAN on import | [06-storage.md](./06-storage.md) |

## References

- [Converging your existing vSphere infrastructure to a VCF or VVF platform](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/converging-your-existing-vsphere-infrastructure-to-a-vcf-or-vvf-platform-.html)
- [Import an Existing vCenter to Create a Workload Domain](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/building-your-private-cloud-infrastructure/working-with-workload-domains/import-an-existing-vcenter-to-create-a-workload-domain.html)
- Broadcom TechDocs, VMware Cloud Foundation 9.1
