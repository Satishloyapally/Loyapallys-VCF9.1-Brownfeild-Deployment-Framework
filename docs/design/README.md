# Design — Loyapally's VCF 9.1 Brownfield Deployment Framework

This directory holds the architectural design set for onboarding an **existing
vSphere estate** into **VMware Cloud Foundation 9.1** and then growing that
fleet with Infrastructure-as-Code.

## What "brownfield" means here

Brownfield onboarding is a three-part model:

1. **Converge** — a manual gate in the **VCF Installer UI** that turns an
   existing standalone vSphere environment into your *first* VCF 9.1
   management domain (SDDC Manager, VCF Operations, VCF Automation, Fleet
   Management; existing NSX is trusted if present). Use converge when you have
   **no VCF yet**.
2. **Import** — a manual gate in the **VCF Operations UI**
   (Inventory → Instance → Add Workload Domain → Import a vCenter) that adds an
   existing vCenter to an *already-existing* VCF fleet as a VI workload domain.
   Use import when a **VCF instance already exists**.
3. **Adopt-then-expand** — neither converge nor import has a Terraform resource
   in the `vmware/vcf` provider, so this framework's IaC **adopts** the
   resulting domains (read-only `vcf_domain` data sources) and then **expands**
   the fleet (network pools, hosts, workload domains, edge clusters,
   Supervisors) with real resources.

The single source of truth for the IaC is
[`iac/config/site.example.yaml`](../../iac/config/site.example.yaml). This
framework is pinned to **VCF 9.1 only** (`vmware/vcf` 0.18.1, `vmware/vsphere`
2.16.1, `vmware/nsxt` 3.12.0).

## Document index

| Document | Purpose |
| --- | --- |
| [00-methodology.md](./00-methodology.md) | End-to-end brownfield methodology: assess → choose → ready → adopt → expand → upgrade, mapped to stages and `site.yaml` keys. |
| [01-converge-vs-import-vs-upgrade.md](./01-converge-vs-import-vs-upgrade.md) | Decision guidance and comparison of Converge vs Import vs in-place Upgrade, plus the pinned/"back-in-time" version matrix. |
| [02-readiness-and-prerequisites.md](./02-readiness-and-prerequisites.md) | DNS, NTP, SSH, certificates, credentials, VLANs, vLCM image conversion, DRS, SDDC Manager extension checks. |
| [03-supported-scenario-matrix.md](./03-supported-scenario-matrix.md) | Supported vs not-supported configurations for converge and import, with remediation for each. |
| [04-domain-mapping.md](./04-domain-mapping.md) | How existing vSphere constructs map to VCF domains and clusters, including appliance placement flexibility on import. |
| [05-nsx-coexistence.md](./05-nsx-coexistence.md) | NSX Manager cluster requirement, DFW activation on import, Tier-0/Tier-1, eBGP/ECMP, edge-before-Supervisor ordering. |
| [06-storage.md](./06-storage.md) | vSAN ESA default, FTT → RAID → host-count guidance, importing existing vSAN, out-of-scope datastores. |
| [07-security-and-identity.md](./07-security-and-identity.md) | SSO/identity, certificate trust, secrets via `TF_VAR_*`, FIPS, DFW default-on implications. |
| [08-post-adoption-lifecycle-upgrade.md](./08-post-adoption-lifecycle-upgrade.md) | Earliest-component entry version, upgrade order to 9.1, VCF Operations lifecycle, depot/bundles. |
| [09-design-decisions-register.md](./09-design-decisions-register.md) | Register of the default design decisions with rationale and ties to `site.yaml` / stages. |

## Related documentation

- Deployment runbooks: `../deployment/` (e.g. `../deployment/converge-runbook.md`)
- Day-2 operations: `../operations/day-2-operations.md`
- IaC reference: [`../../iac/README.md`](../../iac/README.md)

## References

- [Converging your existing vSphere infrastructure to a VCF or VVF platform](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/converging-your-existing-vsphere-infrastructure-to-a-vcf-or-vvf-platform-.html)
- [Import an Existing vCenter to Create a Workload Domain](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/building-your-private-cloud-infrastructure/working-with-workload-domains/import-an-existing-vcenter-to-create-a-workload-domain.html)
- Broadcom TechDocs, VMware Cloud Foundation 9.1
