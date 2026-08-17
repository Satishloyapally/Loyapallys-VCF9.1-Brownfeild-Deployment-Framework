# 08 — Post-Adoption Lifecycle and Upgrade

Onboarding is not the end state. An imported domain rarely enters at full
**VMware Cloud Foundation 9.1**; it must be upgraded after adoption. This
document describes the entry version behavior, the upgrade order, and the fleet
lifecycle mechanics.

## Entry version: earliest component wins

An imported domain enters the fleet at the **effective version of its earliest
component**. For example, an estate on vSphere 8 / NSX 4 comes in as a **VCF
5.x** workload domain. Full VCF 9.1 features require **all** components at 9.1,
so the domain must be upgraded through fleet lifecycle after adoption.

## Pinned and legacy states

The version combination of shared NSX and vCenter determines whether the domain
runs with full features, is pinned, or is in legacy mode (repeated here from
[01-converge-vs-import-vs-upgrade.md](./01-converge-vs-import-vs-upgrade.md)):

| Shared NSX | vCenter | State | Feature availability |
| --- | --- | --- | --- |
| 9.1 | 9.1 | Full VCF 9.1 | All features |
| 9.1 | 9.0.x | **Pinned** | Limited to vCenter 9.0.x capabilities |
| 4.2.x | 8.0.x | **Legacy mode** | Enters as a VCF 5.x-era domain |

To lift a pin or exit legacy mode, upgrade the lagging component until all
components reach 9.1.

## Upgrade order toward 9.1

Upgrade components in a dependency-aware order, driven through VCF Operations
fleet lifecycle:

1. **Management domain first.** The management domain (and its SDDC Manager /
   VCF Operations stack) leads the fleet; upgrade it before dependent workload
   domains.
2. **NSX.** Move shared NSX to 9.1 so workload domains are not held in legacy
   mode by an old NSX.
3. **vCenter.** Upgrade the domain's vCenter to 9.1 to lift a version pin.
4. **ESX hosts.** Upgrade hosts (via vLCM images) to complete the domain's move
   to 9.1.
5. **Re-check state.** Confirm the domain reports full VCF 9.1 features once all
   components are at 9.1.

Because clusters must be on **vLCM images** (not baselines), host upgrades are
image-driven — the same requirement that gated converge in
[02-readiness-and-prerequisites.md](./02-readiness-and-prerequisites.md).

## Fleet lifecycle via VCF Operations

Post-adoption lifecycle is managed centrally through **VCF Operations**:

- **Depot / bundles.** VCF Operations connects to the software depot and stages
  the install/upgrade **bundles** for each component and target version. In
  disconnected sites, bundles are downloaded and served from an offline depot.
- **Fleet management.** Upgrades are planned and applied per domain from the
  fleet view, respecting the management-domain-first order above.
- **Consistency.** Because an imported domain is registered like a native VI
  workload domain, these day-2 lifecycle operations behave consistently with
  natively created domains.

## Where the IaC fits

The IaC stages do **not** perform the version upgrade — that is a VCF Operations
fleet operation. The adopt stages
([`10-converge`](../../iac/stages/10-converge),
[`20-import-workload-domain`](../../iac/stages/20-import-workload-domain))
re-read the domain via the read-only `vcf_domain` data source, so after an
upgrade the reported version and component state refresh on the next plan
without recreating anything. The framework's `version` key stays pinned to
`9.1.0.0`, reflecting the target end state for every domain.

## References

- [Import an Existing vCenter to Create a Workload Domain](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/building-your-private-cloud-infrastructure/working-with-workload-domains/import-an-existing-vcenter-to-create-a-workload-domain.html)
- Broadcom TechDocs, VMware Cloud Foundation 9.1
