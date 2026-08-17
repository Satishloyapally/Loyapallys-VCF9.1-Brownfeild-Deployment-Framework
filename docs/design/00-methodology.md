# 00 — Brownfield Design Methodology

This document describes the end-to-end methodology this framework uses to bring
an existing vSphere estate into **VMware Cloud Foundation 9.1** and then grow it.
Each phase maps to one or more IaC stages under
[`../../iac/stages`](../../iac/stages) and to keys in
[`iac/config/site.example.yaml`](../../iac/config/site.example.yaml).

The methodology has six phases:

```
Assess  →  Choose (converge | import)  →  Ready  →  Adopt  →  Expand  →  Upgrade to 9.1
```

The first two manual gates (converge / import) are performed in the VCF
Installer or VCF Operations UI because neither has a Terraform resource in the
`vmware/vcf` provider. Everything after adoption is IaC.

## Phase 1 — Assess the existing estate

Inventory the current vSphere environment before deciding anything:

- vCenter version and edition, and whether it is already connected to an SDDC
  Manager.
- ESX host versions, cluster topology, and lifecycle mechanism (baselines vs
  vSphere Lifecycle Manager images).
- Storage: vSAN (OSA/ESA) presence and version, or other datastore types.
- NSX presence, version, and manager cluster shape.
- DRS automation level and use of vCenter High Availability (VCHA).

Minimum component versions for both converge and import:

| Component | Minimum version |
| --- | --- |
| VMware vCenter | 8.0 Update 3a or later |
| VMware ESX | 8.0 Update 3 or later |
| vSAN (optional) | 8.0 Update 3 |
| NSX (optional) | 4.2 or later |
| Target VCF instance (import only) | 9.0 or later |

Detailed gating conditions live in
[03-supported-scenario-matrix.md](./03-supported-scenario-matrix.md).

## Phase 2 — Choose converge vs import

- **No VCF yet** → **Converge** the estate into your first VCF 9.1 management
  domain. IaC gate: [`../../iac/stages/10-converge`](../../iac/stages/10-converge).
- **A VCF fleet already exists** → **Import** the existing vCenter as a VI
  workload domain. IaC gate:
  [`../../iac/stages/20-import-workload-domain`](../../iac/stages/20-import-workload-domain).

Full decision guidance, including the in-place upgrade alternative and the
pinned-version matrix, is in
[01-converge-vs-import-vs-upgrade.md](./01-converge-vs-import-vs-upgrade.md).

`site.yaml` keys: `version`, `fleet.installer` (converge), `fleet.sddc_manager`
(import and all expand stages).

## Phase 3 — Ready (prerequisites)

Validate readiness before touching either gate: forward and reverse DNS, NTP,
SSH enabled on the source vCenter, certificate trust, credentials, VLAN/network
plumbing, vLCM image conversion, DRS set to fully automated, and confirmation
that no existing SDDC Manager extension is registered. Run
[`../../iac/scripts/preflight.sh`](../../iac/scripts/preflight.sh) to check the
automatable items.

See [02-readiness-and-prerequisites.md](./02-readiness-and-prerequisites.md).

`site.yaml` keys: `infra.dns_domain`, `infra.dns_servers`, `infra.ntp_servers`,
`fleet.allow_unverified_tls`.

## Phase 4 — Adopt

After a manual gate completes, the resulting domain exists in SDDC Manager but
not in Terraform state. The adopt stages read it back with the read-only
`vcf_domain` data source (via the
[`../../iac/modules/adopt-domain`](../../iac/modules/adopt-domain) module) and
publish its IDs to later stages. No brownfield object is ever created or
destroyed by Terraform.

| Adopt target | Stage | `site.yaml` key |
| --- | --- | --- |
| Converged management domain | [`10-converge`](../../iac/stages/10-converge) | `adoption.management_domain_name` |
| Imported workload domain(s) | [`20-import-workload-domain`](../../iac/stages/20-import-workload-domain) | `adoption.imported_workload_domains[].name` |

## Phase 5 — Expand

With the fleet adopted, add new capacity using real resources. Ordering matters:
a network pool exists before hosts are commissioned, and an edge cluster is
deployed before a Supervisor (Supervisor ingress/egress rides the Tier-0).

| Expansion | Stage | Module | `site.yaml` key |
| --- | --- | --- | --- |
| Network pools | [`30-network-pools`](../../iac/stages/30-network-pools) | [`network-pool`](../../iac/modules/network-pool) | `network_pools` |
| Commission hosts | [`40-host-commission`](../../iac/stages/40-host-commission) | [`host-commission`](../../iac/modules/host-commission) | `hosts_to_commission` |
| New VI workload domain | [`50-workload-domain`](../../iac/stages/50-workload-domain) | [`workload-domain`](../../iac/modules/workload-domain), [`cluster`](../../iac/modules/cluster) | `new_workload_domain` |
| NSX Edge cluster | [`60-edge-cluster`](../../iac/stages/60-edge-cluster) | [`edge-cluster`](../../iac/modules/edge-cluster) | `edge_cluster` |
| Supervisor | [`70-supervisor`](../../iac/stages/70-supervisor) | [`supervisor`](../../iac/modules/supervisor) | `supervisor` |

Storage and NSX design constraints for the expansion are in
[06-storage.md](./06-storage.md) and [05-nsx-coexistence.md](./05-nsx-coexistence.md).

## Phase 6 — Upgrade to VCF 9.1

An imported domain enters the fleet at the **effective version of its earliest
component** (for example, vSphere 8 / NSX 4 comes in as a VCF 5.x workload
domain). Full VCF 9.1 features require every component at 9.1, so the domain is
upgraded through VCF Operations fleet lifecycle after adoption. Pinned and
legacy states are described in
[08-post-adoption-lifecycle-upgrade.md](./08-post-adoption-lifecycle-upgrade.md).

## Phase-to-artifact summary

| Phase | Stage(s) | Primary `site.yaml` keys |
| --- | --- | --- |
| Assess | — | — |
| Choose | `10-converge` or `20-import-workload-domain` | `version` |
| Ready | `preflight.sh` | `infra.*`, `fleet.allow_unverified_tls` |
| Adopt | `10-converge`, `20-import-workload-domain` | `adoption.*` |
| Expand | `30`–`70` | `network_pools`, `hosts_to_commission`, `new_workload_domain`, `edge_cluster`, `supervisor` |
| Upgrade | VCF Operations (manual) | `version` |

## References

- [Converging your existing vSphere infrastructure to a VCF or VVF platform](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/converging-your-existing-vsphere-infrastructure-to-a-vcf-or-vvf-platform-.html)
- [Import an Existing vCenter to Create a Workload Domain](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/building-your-private-cloud-infrastructure/working-with-workload-domains/import-an-existing-vcenter-to-create-a-workload-domain.html)
- Broadcom TechDocs, VMware Cloud Foundation 9.1
