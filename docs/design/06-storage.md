# 06 — Storage

This document covers the storage design defaults for **VMware Cloud Foundation
9.1** brownfield onboarding and expansion.

## vSAN ESA is the default

**vSAN ESA (Express Storage Architecture)** is the default storage in VCF 9.1.
Clusters using vSAN must use **vSphere Lifecycle Manager (vLCM) images** — not
baselines — which is also a converge prerequisite (see
[02-readiness-and-prerequisites.md](./02-readiness-and-prerequisites.md) and
[03-supported-scenario-matrix.md](./03-supported-scenario-matrix.md)).

The expansion workload domain enables ESA by default. In
[`iac/config/site.example.yaml`](../../iac/config/site.example.yaml):

```yaml
new_workload_domain:
  cluster:
    vsan:
      datastore_name: wld-vi-02-vsan01
      esa_enabled: true
      failures_to_tolerate: 1
      dedup_and_compression_enabled: false
```

This block is consumed by
[`../../iac/stages/50-workload-domain`](../../iac/stages/50-workload-domain)
via the [`workload-domain`](../../iac/modules/workload-domain) module.

## FTT → RAID → host-count guidance

The `failures_to_tolerate` (FTT) setting drives the RAID method and therefore
the minimum host count for the cluster. Size the cluster to satisfy the chosen
FTT/RAID before committing hosts in `hosts_to_commission`.

| FTT | RAID method | Minimum hosts |
| --- | --- | --- |
| 1 | RAID-1 (mirroring) | 3 |
| 1 | RAID-5 (erasure coding) | 4–5 |
| 2 | RAID-6 / erasure coding | 6–7 |

Guidance:

- **FTT=1 with RAID-1** is the smallest footprint (3 hosts) but least
  space-efficient.
- **FTT=1 with RAID-5** improves usable capacity but needs **≥ 4–5 hosts**.
- **FTT=2** protects against two concurrent failures and needs **≥ 6–7 hosts**.

The example commissions four hosts (`hosts_to_commission`) for `wld-vi-02`,
which supports FTT=1 with RAID-5.

## Importing existing vSAN

An existing vSAN datastore is retained when the domain is imported. It must
already satisfy the version floor (vSAN **8.0 Update 3** when present) and its
cluster must be on vLCM images. Importing does not convert OSA to ESA; the
datastore comes in as configured and can be addressed by day-2 operations the
same way as a native domain.

## Out-of-scope datastores

Other datastore types (for example NFS, VMFS/FC, or vVols as principal storage
for new domains) are **out of the default scope** of this framework. The default
design targets vSAN ESA for expansion and retains existing vSAN on import.
Introducing another principal storage type is a deliberate deviation from the
defaults recorded in [09-design-decisions-register.md](./09-design-decisions-register.md).

## References

- [Import an Existing vCenter to Create a Workload Domain](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/building-your-private-cloud-infrastructure/working-with-workload-domains/import-an-existing-vcenter-to-create-a-workload-domain.html)
- Broadcom TechDocs, VMware Cloud Foundation 9.1
