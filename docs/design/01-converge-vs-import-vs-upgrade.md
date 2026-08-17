# 01 — Converge vs Import vs Upgrade

This document gives the decision guidance for onboarding an existing vSphere
estate into **VMware Cloud Foundation 9.1**. There are two brownfield entry
paths (converge and import) and one adjacent path (in-place upgrade of an
existing VCF domain). Picking the right one is the first architectural decision.

## The three paths at a glance

- **Converge** — performed in the **VCF Installer UI**. Turns an *existing
  standalone* vSphere environment into your **first** VCF 9.1 management domain,
  deploying/attaching SDDC Manager, VCF Operations, VCF Automation, and Fleet
  Management, and trusting existing NSX if present. Choose when you have **no
  VCF yet**.
- **Import** — performed in the **VCF Operations UI**
  (Inventory → Instance → Add Workload Domain → Import a vCenter). Adds an
  *existing* vCenter (with or without vSAN/NSX) to an **already-existing** VCF
  fleet as a VI workload domain. Choose when a **VCF instance already exists**.
- **Upgrade** — the in-place lifecycle operation that moves an *already
  onboarded* VCF domain to a newer release. This is not an onboarding path; it
  is what you run **after** converge or import to reach full VCF 9.1.

## Comparison table

| Aspect | Converge | Import | Upgrade (in-place) |
| --- | --- | --- | --- |
| Entry UI | VCF Installer | VCF Operations | VCF Operations (lifecycle) |
| Precondition | No VCF instance yet | VCF instance 9.0 or later exists | Domain already managed by VCF |
| Produces | First management domain | VI workload domain | Higher component versions |
| Scope | Standalone vSphere → VCF | Existing vCenter → VCF fleet | Existing VCF domain |
| Deploys mgmt stack? | Yes (SDDC Manager, VCF Operations, VCF Automation, Fleet Management) | No — joins existing fleet | No |
| Cluster granularity | All clusters of the vCenter together | All clusters of the vCenter together | N/A |
| NSX handling | Existing NSX is trusted/registered | Activates NSX on DPGs → **DFW switches on** | N/A |
| Terraform resource? | No — manual gate, then adopt | No — manual gate, then adopt | No — manual/fleet operation |
| IaC gate | [`10-converge`](../../iac/stages/10-converge) | [`20-import-workload-domain`](../../iac/stages/20-import-workload-domain) | — |
| Min versions | vCenter 8.0 U3a+, ESX 8.0 U3+, vSAN 8.0 U3 (opt), NSX 4.2+ (opt) | Same, plus target VCF 9.0+ | — |

Import registers the estate the same way a native VI workload domain is
created, so day-2 operations behave consistently afterward. The one behavioral
surprise on import is that NSX is activated on the cluster's distributed port
groups, which switches on the **NSX Distributed Firewall (DFW)** across every
running workload — see [05-nsx-coexistence.md](./05-nsx-coexistence.md) and
[07-security-and-identity.md](./07-security-and-identity.md).

## When to pick each

Choose **Converge** when:

- You have a standalone vSphere estate and **no** VCF instance.
- You want that estate to become the management domain / first VCF instance.
- The estate satisfies the "supported to converge" conditions in
  [03-supported-scenario-matrix.md](./03-supported-scenario-matrix.md).

Choose **Import** when:

- A VCF 9.0-or-later fleet already exists.
- You want to bring an existing vCenter under management as a VI workload
  domain, keeping its clusters, and optionally its vSAN and NSX.
- You accept that DFW becomes active on the imported clusters' workloads.

Choose **Upgrade** when:

- The domain is already onboarded (via converge or import) and you need to move
  its components toward VCF 9.1 to unlock the full feature set. See
  [08-post-adoption-lifecycle-upgrade.md](./08-post-adoption-lifecycle-upgrade.md).

## "Back-in-time" / pinned-version matrix

An imported domain enters the fleet at the **effective version of its earliest
component**. Because NSX and vCenter can be at different versions, the domain
lands in one of three states. The matrix below shows the common combinations.

| Shared NSX version | vCenter version | Resulting state | Feature availability |
| --- | --- | --- | --- |
| 9.1 | 9.1 | Full VCF 9.1 | All VCF 9.1 features |
| 9.1 | 9.0.x | **Pinned** | Features limited to what vCenter 9.0.x supports |
| 4.2.x | 8.0.x | **Legacy mode** | Enters as a VCF 5.x-era workload domain; limited features |
| 4.2+ | 9.x | Mixed / transitional | Upgrade the lagging component to lift the pin |

Reading the matrix:

- **Full features** require *every* component at 9.1.
- A **pinned** state occurs when a newer shared NSX (9.1) is paired with an
  older vCenter (9.0.x); the domain is held to the older vCenter's capabilities
  until vCenter is upgraded.
- **Legacy mode** is the oldest supported combination (for example NSX 4.2.x
  with vCenter 8.0.x), which comes in as a VCF 5.x workload domain.

The remedy for pinned and legacy states is the same: upgrade the lagging
component(s) through VCF Operations fleet lifecycle until all reach 9.1. The
upgrade order and depot/bundle mechanics are covered in
[08-post-adoption-lifecycle-upgrade.md](./08-post-adoption-lifecycle-upgrade.md).

## References

- [Converging your existing vSphere infrastructure to a VCF or VVF platform](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/converging-your-existing-vsphere-infrastructure-to-a-vcf-or-vvf-platform-.html)
- [Import an Existing vCenter to Create a Workload Domain](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/building-your-private-cloud-infrastructure/working-with-workload-domains/import-an-existing-vcenter-to-create-a-workload-domain.html)
- Broadcom TechDocs, VMware Cloud Foundation 9.1
