# Troubleshooting — VCF 9.1 Brownfield Onboarding & Expansion

A phase-by-phase catalog of symptoms, likely causes, and resolutions for
onboarding an existing vSphere estate into VMware Cloud Foundation 9.1 and
expanding the fleet with the Terraform in [`../../iac`](../../iac/README.md).

Work through the phases in the order you executed them: preflight → converge or
import → network pools → host commission → workload domain → edge cluster →
Supervisor, plus a Terraform-specific section at the end.

Named Broadcom Knowledge Base articles are referenced by title where relevant;
consult Broadcom TechDocs, VMware Cloud Foundation 9.1 for the current text.

Authoritative references:

- [Converging overview](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/converging-your-existing-vsphere-infrastructure-to-a-vcf-or-vvf-platform-.html)
- [Supported and Not Supported Configurations to Converge](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/converging-your-existing-vsphere-infrastructure-to-a-vcf-or-vvf-platform-/supported-and-not-supported-configurations.html)
- [Import an Existing vCenter to Create a Workload Domain](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/building-your-private-cloud-infrastructure/working-with-workload-domains/import-an-existing-vcenter-to-create-a-workload-domain.html)

---

## 1. Preflight (DNS / NTP / tooling)

Run `../../iac/scripts/preflight.sh` (or `make preflight`) before any gate.

| Symptom | Likely cause | Resolution |
| --- | --- | --- |
| Forward/reverse DNS lookups fail for vCenter, ESX, NSX, or SDDC Manager | Missing or inconsistent A/PTR records | Create matching forward and reverse records for every management FQDN before proceeding; re-run preflight. |
| Preflight reports NTP unreachable or clock skew | NTP servers unreachable or hosts pointed at different sources | Point all components at the `infra.ntp_servers` sources in `site.yaml`; confirm time is synchronized within tolerance across vCenter/ESX/NSX. |
| `terraform` or required CLI missing | Toolchain not installed on the runner | Install Terraform >= 1.7 (CI pins 1.9.8) and required tooling; re-run preflight. |
| Endpoint unreachable / TLS handshake failure | Firewall/routing blocks the management network, or untrusted certificate | Open required paths; for labs set `fleet.allow_unverified_tls: true`, otherwise install a valid trust chain. |
| Hostname/FQDN mismatch warnings | System hostname differs from DNS record | Align system hostnames with DNS before converge/import. |

---

## 2. Converge prechecks (VCF Installer UI)

Converge turns an existing standalone vSphere into your **first** VCF 9.1
management domain. See the
[converging overview](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/converging-your-existing-vsphere-infrastructure-to-a-vcf-or-vvf-platform-.html)
and
[supported configurations](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/converging-your-existing-vsphere-infrastructure-to-a-vcf-or-vvf-platform-/supported-and-not-supported-configurations.html).

| Symptom | Likely cause | Resolution |
| --- | --- | --- |
| Precheck fails: existing SDDC Manager extension detected | A prior/stale SDDC Manager extension is registered in vCenter | Remove the existing extension before retrying — see Broadcom KB **"Existing SDDC Manager extension detected"**. Converge/import is blocked until it is removed. |
| Precheck blocks on attached baselines / update manager remediation | vSphere Lifecycle Manager baselines or legacy VUM baselines attached | Remove unsupported baselines and move clusters to a supported lifecycle model per the supported-configurations page. |
| Precheck fails on vCenter High Availability (VCHA) | VCHA is enabled and is not a supported converge configuration | Disable VCHA before converge; re-enable equivalent protection afterward if required. |
| Precheck warns on partial or disabled DRS | DRS not fully automated / not enabled on the cluster | Enable and fully automate DRS as required by the supported converge configuration. |
| Version precheck fails | Component below minimum (vCenter < 8.0 U3a, ESX < 8.0 U3) | Bring components to minimum (vCenter 8.0 Update 3a+, ESX 8.0 Update 3+; optional vSAN 8.0 U3, optional NSX 4.2+) before converge. |
| Converged domain reports an unexpected version | Domain enters at the earliest-component version | Expected — upgrade the management domain to VCF 9.1 afterward (see [`../design/08-post-adoption-lifecycle-upgrade.md`](../design/08-post-adoption-lifecycle-upgrade.md)). |

---

## 3. Import prechecks (VCF Operations UI)

Import adds an existing vCenter to an **existing** fleet as a VI workload
domain via **Add Workload Domain → Import a vCenter**. See
[Import an Existing vCenter to Create a Workload Domain](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/building-your-private-cloud-infrastructure/working-with-workload-domains/import-an-existing-vcenter-to-create-a-workload-domain.html).

| Symptom | Likely cause | Resolution |
| --- | --- | --- |
| Precheck fails on common datastore across the cluster | Hosts in the target cluster do not all share a common datastore | Ensure every host in the cluster has the required common datastore — see Broadcom KB **"Workload domain import cluster common datastore check"**; remediate storage presentation and retry. |
| Precheck fails: existing SDDC Manager extension detected | Stale SDDC Manager extension registered in the source vCenter | Remove it before importing — see Broadcom KB **"Existing SDDC Manager extension detected"**. |
| After import, workloads unexpectedly lose connectivity / are filtered | Import activated NSX on the distributed port groups, which **turned on the Distributed Firewall (DFW)** across workloads | Plan a maintenance window; after import, review and adjust DFW rules so intended traffic is allowed. Verify DFW posture before returning to production. |
| Import rejects NSX topology | NSX Manager is not a 3-node cluster | If NSX is present it must be a **3-node Manager cluster**; deploy/expand to three nodes before import. |
| Import target rejects the fleet | Target VCF instance below 9.0 | Import requires a target VCF instance at 9.0+; upgrade the receiving fleet first. |
| Imported domain reports VCF 5.x | Domain enters at earliest-component version (vSphere 8 / NSX 4) | Expected — upgrade the imported workload domain to VCF 9.1 afterward (see [`../design/08-post-adoption-lifecycle-upgrade.md`](../design/08-post-adoption-lifecycle-upgrade.md)). |
| Version precheck fails | Component below minimum | Meet minimums (vCenter 8.0 U3a+, ESX 8.0 U3+, optional vSAN 8.0 U3, optional NSX 4.2+) before import. |

---

## 4. Host commission (stage 40)

Applies to the **greenfield** host-commission flow
([`40-host-commission`](../../iac/stages/40-host-commission), `vcf_host`). For
**brownfield/imported** clusters, add the host in vCenter first and reconcile
with import-sync — see
[Day-2 → Adding hosts](./day-2-operations.md#1-adding-hosts-to-a-brownfield--imported-cluster).

| Symptom | Likely cause | Resolution |
| --- | --- | --- |
| Commission fails: no network pool | Ordering violated — pool must exist first | Create the pool in stage [`30-network-pools`](../../iac/stages/30-network-pools) before commissioning: **network pool before host commission**. |
| Host validation fails on thumbprint/SSL | Thumbprint not collected or changed | Re-run `../../iac/scripts/thumbprints.sh` and confirm SSL/SSH thumbprints match. |
| Authentication to ESX fails | Wrong or unset ESX root credential | Set `TF_VAR_host_password` correctly for the host being commissioned. |
| Host fails vSAN/storage checks | `storage_type` in `hosts_to_commission[]` does not match the host | Correct the host's storage type/pool in `site.yaml` to match the physical configuration. |
| Host added to imported cluster via stage 40 does not reconcile | Using the greenfield path on a brownfield cluster | Do not use stage 40 for imported clusters; add the host in vCenter and import-sync instead. |

---

## 5. Workload domain creation (stage 50)

Applies to creating a new VI workload domain
([`50-workload-domain`](../../iac/stages/50-workload-domain), `vcf_domain`).

| Symptom | Likely cause | Resolution |
| --- | --- | --- |
| Domain creation fails: insufficient hosts | Not enough commissioned hosts in the correct pool | Commission the required hosts (stage 40) and confirm they are free before creating the domain. |
| NSX deployment fails during domain creation | NSX inputs incomplete or credentials unset | Provide complete NSX spec in `new_workload_domain`; set `TF_VAR_nsx_admin_password` / `TF_VAR_nsx_audit_password`. |
| vCenter deployment fails | vCenter root or SSO credential unset/incorrect | Set `TF_VAR_vcenter_root_password` and `TF_VAR_sso_domain_password`; verify DNS records for the new vCenter exist. |
| Domain creation blocks on network pool | Pool missing or too small | Ensure the network pool exists and has capacity (stage 30) before creating the domain. |
| Datastore/common-storage errors | Cluster hosts lack a shared datastore | Present a common datastore to all cluster hosts (see the import common-datastore check for the analogous requirement). |

---

## 6. Edge cluster / BGP (stage 60)

Applies to NSX Edge cluster deployment
([`60-edge-cluster`](../../iac/stages/60-edge-cluster)). Deploy the **edge
before the Supervisor**.

| Symptom | Likely cause | Resolution |
| --- | --- | --- |
| No BGP session established | Wrong peer IP/ASN, or BGP password mismatch | Verify Tier-0 uplink IPs, local/peer ASN, and set `TF_VAR_bgp_peer_password`; confirm the physical router peer configuration. |
| BGP flaps or never reaches Established | MTU mismatch on the uplink/TEP path | Ensure end-to-end jumbo-frame MTU is consistent across uplinks and the TEP network; correct the physical switch MTU. |
| Edge overlay/tunnels down | TEP addressing or VLAN misconfiguration | Verify TEP IP pool, VLAN, and gateway match the physical fabric; confirm TEP-to-TEP reachability. |
| Edge node deployment fails | Edge credentials unset | Set `TF_VAR_edge_admin_password`, `TF_VAR_edge_audit_password`, and `TF_VAR_edge_root_password`. |
| Uplinks up but no route advertisement | Route redistribution / prefix filtering | Check Tier-0 route redistribution and any prefix lists on the peer; correct filtering. |

---

## 7. Supervisor activation (stage 70)

Applies to vSphere Supervisor (IaaS/Tanzu) activation
([`70-supervisor`](../../iac/stages/70-supervisor), `vsphere_supervisor`).

| Symptom | Likely cause | Resolution |
| --- | --- | --- |
| Activation fails on management IPs | Management network range too small or overlapping | Provide a correctly sized, non-overlapping management IP range/CIDR in the `supervisor` section of `site.yaml`. |
| Activation fails: no content library | Required subscribed/local content library missing | Create and associate the content library the Supervisor expects before activating. |
| Activation fails on storage policy | Referenced storage policy missing or not applied to the cluster | Create the storage policy and ensure it maps to the cluster's datastore(s). |
| Supervisor needs an edge but none present | Edge cluster not deployed | Deploy stage 60 first — **edge before Supervisor**. |
| vCenter authentication fails | Supervisor vCenter credential unset | Set `TF_VAR_vsphere_password`. |
| Workload/management network DNS/NTP errors | `infra` DNS/NTP not reachable from the Supervisor networks | Ensure the `infra` DNS and NTP sources are reachable from the Supervisor management and workload networks. |

---

## 8. Terraform-specific {#terraform-specific}

Applies across all stages using providers `vmware/vcf 0.18.1`,
`vmware/vsphere 2.16.1`, and `vmware/nsxt 3.12.0`.

| Symptom | Likely cause | Resolution |
| --- | --- | --- |
| Provider authentication to SDDC Manager fails | `TF_VAR_sddc_manager_password` unset/incorrect, or wrong SDDC Manager host/user | Export `TF_VAR_sddc_manager_password`; verify `fleet.sddc_manager` host/username in `site.yaml`. Secrets come only from `TF_VAR_*`. |
| TLS/certificate error contacting SDDC Manager, vCenter, or NSX | Untrusted certificate | Install a valid trust chain; for labs only, set `fleet.allow_unverified_tls: true`. |
| Adopt data source (`data "vcf_domain"`) returns nothing | Domain name mismatch, or the manual converge/import gate has not completed | Confirm the manual gate finished and the domain exists in SDDC Manager; set `adoption.management_domain_name` / `adoption.imported_workload_domains[]` to the exact domain name. |
| Plan shows unexpected changes (state drift) | Out-of-band change in vCenter/SDDC Manager (common in brownfield) | Reconcile with import-sync where applicable, then re-plan; align `site.yaml` to reality or `terraform refresh`/targeted import so state matches. See [Day-2 → Drift and sync](./day-2-operations.md#3-configuration-drift-and-sync-between-vcenter-and-sddc-manager). |
| `terraform validate` passes but apply fails on a dependency | Stages run out of order | Run stages in order; the manual gates precede stages 10/20, then 30 → 40 → 50 → 60 → 70. |
| Provider version mismatch / lock errors | `.terraform.lock.hcl` out of sync | Regenerate locks with `make lock`; the framework is pinned to `vmware/vcf 0.18.1`, `vmware/vsphere 2.16.1`, `vmware/nsxt 3.12.0`. |
| State conflicts between stages | Shared state across stages | Each stage keeps isolated state — do not point multiple stages at the same backend/state. |

---

For onboarding procedures see [`../deployment/`](../deployment/README.md); for
design rationale see [`../design/`](../design/README.md); for day-2 procedures
see [`./day-2-operations.md`](./day-2-operations.md).
