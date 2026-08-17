# 02 — Readiness and Prerequisites

Both brownfield gates — **converge** (VCF Installer UI) and **import** (VCF
Operations UI) — require the existing estate to be in a known-good state before
you start. This document lists the readiness checks and how they map to
`site.yaml` and the preflight script. Run
[`../../iac/scripts/preflight.sh`](../../iac/scripts/preflight.sh) to validate
the automatable items before opening either UI.

## Minimum versions

| Component | Minimum version | Applies to |
| --- | --- | --- |
| VMware vCenter | 8.0 Update 3a or later | Converge, Import |
| VMware ESX | 8.0 Update 3 or later | Converge, Import |
| vSAN (optional) | 8.0 Update 3 | Converge, Import |
| NSX (optional) | 4.2 or later | Converge, Import |
| Target VCF instance | 9.0 or later | Import only |

## Name resolution and time

| Requirement | Detail | `site.yaml` key |
| --- | --- | --- |
| Forward DNS | Every appliance and ESX host FQDN resolves to its IP. | `infra.dns_domain`, `infra.dns_servers` |
| Reverse DNS | Every IP resolves back to the matching FQDN (PTR records). | `infra.dns_servers` |
| NTP | All hosts and appliances share a common, reachable time source; clocks in sync. | `infra.ntp_servers` |

Forward **and** reverse DNS are mandatory; mismatched PTR records are a common
cause of gate failures. `preflight.sh` performs the round-trip lookups.

## Access and connectivity

| Requirement | Detail |
| --- | --- |
| SSH on source vCenter | SSH must be **enabled** on the source vCenter so the gate can operate on the appliance. |
| Management reachability | The VCF Installer / VCF Operations appliance must reach vCenter, ESX hosts, and NSX (if present) over the required ports. |
| VLAN / network readiness | Management, vMotion, vSAN, host TEP, and edge/uplink VLANs are trunked and routable as designed (see the `network_pools` and `edge_cluster` blocks). |

Network pool VLANs for expansion are defined under `network_pools` (consumed by
[`30-network-pools`](../../iac/stages/30-network-pools)); edge and TEP VLANs
under `edge_cluster` (consumed by
[`60-edge-cluster`](../../iac/stages/60-edge-cluster)).

## Certificates and credentials

| Requirement | Detail |
| --- | --- |
| Certificate trust | vCenter (and NSX, if present) certificates must be trusted by the gate. In labs only, `fleet.allow_unverified_tls: true` relaxes verification. |
| Credentials | vCenter, ESX (`root`), NSX admin/audit, and SSO credentials are available for the gate. |
| Secret handling | For the IaC stages, **all** secrets are supplied through `TF_VAR_*` environment variables and never written to `site.yaml`. |

Never store passwords in `site.yaml`; see
[07-security-and-identity.md](./07-security-and-identity.md) for the full list
of `TF_VAR_*` variables.

## Lifecycle and cluster configuration

These items block a **converge** and must be remediated first. Full
supported/not-supported detail is in
[03-supported-scenario-matrix.md](./03-supported-scenario-matrix.md).

| Requirement | Why | Remediation |
| --- | --- | --- |
| vSphere Lifecycle Manager images | Clusters using baselines cannot be converged. vSAN ESA (the 9.1 default) requires vLCM images. | Convert clusters from baselines to vLCM images. |
| DRS fully automated | Manual or partially automated DRS is not supported for converge. | Set cluster DRS to **fully automated**. |
| No existing SDDC Manager extension | A vCenter already connected to an SDDC Manager cannot be converged. | Ensure no SDDC Manager extension is registered on the source vCenter. |
| No VCHA | Clusters using vCenter High Availability are not supported. | Remove VCHA before converging. |

## Preflight checklist

The following are validated by
[`../../iac/scripts/preflight.sh`](../../iac/scripts/preflight.sh):

- [ ] vCenter and ESX at minimum versions.
- [ ] Forward and reverse DNS resolve for all FQDNs/IPs.
- [ ] NTP reachable and clocks synchronized.
- [ ] SSH enabled on the source vCenter.
- [ ] Certificate trust established (or `allow_unverified_tls` set for labs).
- [ ] Clusters on vLCM images (not baselines).
- [ ] DRS set to fully automated.
- [ ] No SDDC Manager extension present (converge).
- [ ] Required VLANs trunked and routable.
- [ ] Target VCF instance at 9.0 or later (import).

## References

- [Converge a vCenter Instance, ESX Hosts, and Optionally vSAN and NSX](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/converging-your-existing-vsphere-infrastructure-to-a-vcf-or-vvf-platform-/supported-scenarios-to-converge-to-vcf/converge-your-existing-vcenter-instance-and-esx-hosts.html)
- [Supported and Not Supported Configurations to Converge](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/converging-your-existing-vsphere-infrastructure-to-a-vcf-or-vvf-platform-/supported-and-not-supported-configurations.html)
- Broadcom TechDocs, VMware Cloud Foundation 9.1
