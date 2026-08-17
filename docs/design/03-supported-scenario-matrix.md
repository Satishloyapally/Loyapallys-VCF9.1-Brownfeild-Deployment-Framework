# 03 — Supported Scenario Matrix

This document enumerates which existing-estate configurations are supported for
**converge** and **import** into **VMware Cloud Foundation 9.1**, and how to
remediate each not-supported case. Validate these against the estate during the
readiness phase ([02-readiness-and-prerequisites.md](./02-readiness-and-prerequisites.md))
before opening either gate.

## Version floor (both paths)

| Component | Minimum |
| --- | --- |
| VMware vCenter | 8.0 Update 3a or later |
| VMware ESX | 8.0 Update 3 or later |
| vSAN (optional) | 8.0 Update 3 |
| NSX (optional) | 4.2 or later |
| Target VCF instance (import only) | 9.0 or later |

## Converge — supported vs not supported

| Configuration | Status | Remediation / note |
| --- | --- | --- |
| vCenter at 8.0 U3a+, ESX at 8.0 U3+ | Supported | — |
| Optional vSAN 8.0 U3 / NSX 4.2+ present | Supported | Existing NSX is trusted/registered during converge. |
| SSH enabled on source vCenter | Required | Enable SSH on the source vCenter before converging. |
| Forward + reverse DNS and NTP configured | Required | Fix DNS/PTR and NTP before converging. |
| Partial import of clusters | **Not supported** | All clusters managed by a vCenter are imported **together**; you cannot converge a subset. |
| Clusters using vCenter High Availability (VCHA) | **Not supported** | Remove VCHA before converging. |
| vCenter already connected to an SDDC Manager | **Not supported** | The existing SDDC Manager extension must not be present; remove it first. |
| Clusters using baselines for lifecycle management | **Not supported** | Convert clusters to vSphere Lifecycle Manager (vLCM) images first. |
| Clusters using manual or partially automated DRS | **Not supported** | Set DRS to **fully automated**. |
| Standalone ESX hosts / single-host clusters | **Not supported** | Not supported unless another qualifying cluster exists in the same vCenter. |
| vCenter VM hosted on a cluster managed by a different vCenter | **Not supported** | Relocate the vCenter VM so it is not managed by a different vCenter. |

## Import — supported considerations

Import registers the estate the same way a native VI workload domain is
created, so day-2 operations behave consistently afterward. The version floor
above applies, plus the target VCF instance must be 9.0 or later.

| Configuration | Status | Remediation / note |
| --- | --- | --- |
| Existing vCenter with or without vSAN/NSX | Supported | Optional components follow the same version floor. |
| All clusters of the vCenter | Imported together | Partial (subset) import is not available. |
| NSX present | Supported (with condition) | NSX must be a **3-node NSX Manager cluster** — the only supported setup for VCF workload domains. |
| Appliance placement | Flexible | vCenter and NSX appliances may live in the imported workload domain **or** the management domain; mixed placement is possible. This flexibility is not available for freshly created workload domains. |
| Entry version | Depends on components | The domain enters at the effective version of its earliest component; upgrade afterward (see [08-post-adoption-lifecycle-upgrade.md](./08-post-adoption-lifecycle-upgrade.md)). |

### Import risk: Distributed Firewall activation

Importing **activates NSX on the cluster's distributed port groups**, which
switches **on** the NSX Distributed Firewall (DFW) across every running
workload. Plan for a default-on DFW posture before importing — see
[05-nsx-coexistence.md](./05-nsx-coexistence.md) and
[07-security-and-identity.md](./07-security-and-identity.md).

## Remediation quick reference

| Not-supported case | Fix |
| --- | --- |
| Baselines for lifecycle | Convert to vLCM images. |
| Manual / partial DRS | Set DRS to fully automated. |
| VCHA in use | Remove VCHA (not supported). |
| Existing SDDC Manager extension | Remove the extension; the vCenter must not already be connected. |
| Standalone / single-host cluster | Ensure another qualifying cluster exists in the vCenter. |
| Subset of clusters wanted | Not possible; all clusters import together. |
| vCenter VM under a different vCenter | Relocate so it is not managed by a different vCenter. |
| Missing SSH / DNS / NTP | Enable SSH; fix forward+reverse DNS; configure NTP. |

## References

- [Supported and Not Supported Configurations to Converge](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/converging-your-existing-vsphere-infrastructure-to-a-vcf-or-vvf-platform-/supported-and-not-supported-configurations.html)
- [Converge a vCenter Instance, ESX Hosts, and Optionally vSAN and NSX](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/converging-your-existing-vsphere-infrastructure-to-a-vcf-or-vvf-platform-/supported-scenarios-to-converge-to-vcf/converge-your-existing-vcenter-instance-and-esx-hosts.html)
- [Import an Existing vCenter to Create a Workload Domain](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/building-your-private-cloud-infrastructure/working-with-workload-domains/import-an-existing-vcenter-to-create-a-workload-domain.html)
- Broadcom TechDocs, VMware Cloud Foundation 9.1
