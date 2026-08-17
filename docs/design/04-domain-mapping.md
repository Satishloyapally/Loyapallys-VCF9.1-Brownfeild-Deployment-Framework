# 04 — Domain Mapping

This document describes how existing vSphere constructs map onto **VMware Cloud
Foundation 9.1** domains and clusters when you converge or import, and how this
framework adopts the result.

## Core mapping

| Existing construct | Converge (no VCF yet) | Import (VCF fleet exists) |
| --- | --- | --- |
| Standalone vCenter | Becomes the **management domain** (first VCF instance) | Becomes a **VI workload domain** in the existing fleet |
| Clusters under that vCenter | All clusters converge together | All clusters import together |
| Existing vSAN datastore | Retained; must use vLCM images | Retained (see [06-storage.md](./06-storage.md)) |
| Existing NSX (if present) | Trusted/registered during converge | Activated on the clusters' DPGs (DFW turns on) |

Both gates operate at **vCenter granularity**: every cluster managed by the
source vCenter is brought in together. Partial (subset) selection of clusters is
not supported — see [03-supported-scenario-matrix.md](./03-supported-scenario-matrix.md).

## Converge: standalone vSphere → management domain

Converge deploys or attaches the VCF management stack (SDDC Manager, VCF
Operations, VCF Automation, Fleet Management) onto the existing estate, turning
it into the **first** management domain. If NSX already exists it is trusted and
registered rather than redeployed. After the gate,
[`../../iac/stages/10-converge`](../../iac/stages/10-converge) adopts the
domain by name (`adoption.management_domain_name`) using the read-only
`vcf_domain` data source in
[`../../iac/modules/adopt-domain`](../../iac/modules/adopt-domain).

## Import: existing vCenter → VI workload domain

Import adds the existing vCenter to an already-running VCF fleet as a VI
workload domain, registering it the same way a native VI workload domain is
created so day-2 behavior is consistent. After the gate,
[`../../iac/stages/20-import-workload-domain`](../../iac/stages/20-import-workload-domain)
adopts each imported domain listed under
`adoption.imported_workload_domains[].name`.

## Appliance placement flexibility (import)

For **imported** domains, the vCenter and NSX appliances may live in the
imported workload domain **or** in the management domain, and **mixed
placement** is possible. This flexibility is not available when you create a
fresh workload domain (where appliance placement follows the standard VI
workload domain topology).

| Placement option | vCenter | NSX Manager cluster |
| --- | --- | --- |
| In the imported workload domain | Supported | Supported |
| In the management domain | Supported | Supported |
| Mixed (e.g. vCenter in WLD, NSX in mgmt) | Supported | Supported |

If NSX is present it must be a **3-node NSX Manager cluster**, regardless of
where it is placed — see [05-nsx-coexistence.md](./05-nsx-coexistence.md).

## Where expansion domains fit

New capacity added by the expansion stages does **not** use the placement
flexibility above; it follows standard VI workload domain topology. The example
`new_workload_domain` in
[`iac/config/site.example.yaml`](../../iac/config/site.example.yaml) creates
`wld-vi-02` with its own vCenter and NSX, commissioned from hosts in the shared
network pool. See [00-methodology.md](./00-methodology.md) for the full
expansion sequence.

| Domain | Origin | Stage |
| --- | --- | --- |
| `mgmt-domain` | Converge (adopted) | [`10-converge`](../../iac/stages/10-converge) |
| `wld-brownfield-01` | Import (adopted) | [`20-import-workload-domain`](../../iac/stages/20-import-workload-domain) |
| `wld-vi-02` | Expansion (created) | [`50-workload-domain`](../../iac/stages/50-workload-domain) |

## References

- [Import an Existing vCenter to Create a Workload Domain](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/building-your-private-cloud-infrastructure/working-with-workload-domains/import-an-existing-vcenter-to-create-a-workload-domain.html)
- [Converging your existing vSphere infrastructure to a VCF or VVF platform](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/converging-your-existing-vsphere-infrastructure-to-a-vcf-or-vvf-platform-.html)
- Broadcom TechDocs, VMware Cloud Foundation 9.1
