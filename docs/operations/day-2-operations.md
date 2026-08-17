# Day-2 Operations — Adopted & Expanded VCF 9.1 Fleet

This guide covers ongoing operations for a VMware Cloud Foundation 9.1 fleet
that was onboarded from a brownfield vSphere estate through the manual
**converge** or **import** gate and then expanded with the Terraform in
[`../../iac`](../../iac/README.md).

The single most important day-2 distinction for a brownfield fleet is how you
add hosts to an **imported** cluster: it is *not* the greenfield
host-commission flow. That difference is covered first.

> Secrets are always supplied through `TF_VAR_*` environment variables.
> `site.yaml` and `*.tfvars` are git-ignored — never commit credentials.

---

## 1. Adding hosts to a brownfield / imported cluster

An imported cluster is one that entered the fleet through the VCF Operations
**Add Workload Domain → Import a vCenter** flow. Its lifecycle is anchored on
the pre-existing vCenter, so host expansion is **vCenter-first, then
reconciled into VCF** — the opposite ordering from a greenfield cluster.

### Brownfield / imported cluster (vCenter-first + import-sync)

1. Add the ESX host to the cluster **in vCenter first** (add host to the
   existing vSphere cluster; let vSAN/DRS/HA converge as they normally would).
2. Confirm the host is healthy in vCenter (no alarms, vSAN disk groups
   claimed, networking on the correct distributed switch/port groups).
3. Reconcile the change into VCF with an **import-sync** from SDDC Manager so
   inventory, licensing, and lifecycle management pick up the new host. This is
   the same reconciliation mechanism used by the original import.
4. Verify the host now appears under the workload domain in SDDC Manager and
   that the domain reports a consistent state.

Because import activated NSX on the distributed port groups (which turned on
the Distributed Firewall), confirm the new host inherits the expected DFW
posture and that no workloads on it are unexpectedly blocked.

### Greenfield cluster (contrast — stage 40 host-commission)

For clusters this framework built (a new VI workload domain created in stage
50, or additional clusters via the [`cluster`](../../iac/modules/cluster)
module), hosts are added through the **greenfield host-commission** path:

1. Ensure a network pool exists (stage
   [`30-network-pools`](../../iac/stages/30-network-pools)) — **network pool
   before host commission**.
2. Declare the host under `hosts_to_commission[]` in `site.yaml`.
3. Commission it through stage
   [`40-host-commission`](../../iac/stages/40-host-commission)
   (`vcf_host`), then place it into the target cluster.

| Aspect | Brownfield / imported cluster | Greenfield cluster (stage 40) |
| --- | --- | --- |
| Entry point | vCenter (add host directly) | SDDC Manager host commission (`vcf_host`) |
| Reconciliation | VCF **import-sync** picks up the vCenter change | Terraform commissions the host into VCF directly |
| Ordering | Host in vCenter → sync to VCF | Network pool → commission → assign to cluster |
| Terraform stage | Not stage 40; managed in vCenter then synced | [`40-host-commission`](../../iac/stages/40-host-commission) |

**Rule of thumb:** if the cluster originated from an import, add hosts in
vCenter and import-sync; if the cluster was created by this framework,
commission hosts through stage 40.

---

## 2. Adding a cluster

Additional clusters in an existing workload domain are managed with the
[`cluster`](../../iac/modules/cluster) module (`vcf_cluster`).

1. Ensure the target hosts are available to VCF — commissioned via stage
   [`40-host-commission`](../../iac/stages/40-host-commission) for a
   greenfield domain, or present in vCenter and import-synced for a brownfield
   domain (see section 1).
2. Add the cluster definition to `site.yaml` and run the relevant stage:
   ```bash
   make plan  STAGE=50-workload-domain
   make apply STAGE=50-workload-domain
   ```
3. Validate cluster health (vSAN, DRS/HA, distributed switch uplinks) in both
   vCenter and SDDC Manager before scheduling workloads.

Keep network pools sized ahead of cluster growth — the **network pool must
exist before hosts are committed** to the new cluster.

---

## 3. Configuration drift and sync between vCenter and SDDC Manager

In a brownfield fleet, vCenter and SDDC Manager can diverge because changes may
be made directly in vCenter (host adds, port group edits, storage changes)
while VCF expects to be the system of record.

- Treat **SDDC Manager import-sync** as the reconciliation tool whenever a
  brownfield/imported domain is changed outside of VCF (see section 1).
- Prefer making inventory changes through Terraform for domains and clusters
  this framework created, so state stays authoritative.
- Periodically compare inventory: hosts, clusters, and datastores visible in
  vCenter should match what SDDC Manager reports for the domain.
- After any out-of-band change, run a read-only Terraform plan on the relevant
  stage to detect state drift (see
  [Troubleshooting → Terraform-specific](./troubleshooting.md#terraform-specific)).

---

## 4. Credential rotation

Credentials for the fleet (SDDC Manager, ESX root, vCenter, NSX, SSO, edge
nodes, BGP peers) are rotated through VCF's credential management and reflected
into this framework through environment variables — never in `site.yaml`.

1. Rotate the credential through SDDC Manager / VCF credential management so
   VCF's own store is updated first.
2. Update the matching `TF_VAR_*` environment variable in your shell/CI secret
   store:

   | `TF_VAR_*` | Scope |
   | --- | --- |
   | `TF_VAR_sddc_manager_password` | SDDC Manager (all adopt/expand stages) |
   | `TF_VAR_host_password` | ESX root (stage 40) |
   | `TF_VAR_vcenter_root_password` | new vCenter root (stage 50) |
   | `TF_VAR_nsx_admin_password` / `TF_VAR_nsx_audit_password` | NSX (stage 50) |
   | `TF_VAR_sso_domain_password` | SSO (stage 50) |
   | `TF_VAR_edge_admin_password` / `TF_VAR_edge_audit_password` / `TF_VAR_edge_root_password` | edge nodes (stage 60) |
   | `TF_VAR_bgp_peer_password` | BGP peers (stage 60) |
   | `TF_VAR_vsphere_password` | Supervisor vCenter (stage 70) |

3. Re-run a plan on the affected stage to confirm the provider authenticates
   with the new credential.

See [`../../iac/config/README.md`](../../iac/config/README.md) for the full
secret mapping.

---

## 5. Certificate management

Certificates for the fleet are managed through VCF/SDDC Manager, not through
Terraform.

- Rotate or replace certificates for vCenter, NSX Manager, and SDDC Manager
  through VCF certificate management.
- If you run providers against self-signed/lab endpoints, `fleet.allow_unverified_tls`
  in `site.yaml` may be set to `true`; keep it `false` in production and ensure
  a valid trust chain instead.
- If the framework collected thumbprints during onboarding
  (`../../iac/scripts/thumbprints.sh`), re-collect after a certificate change
  so any thumbprint-pinned operations continue to succeed.
- After rotation, verify the `vcf`, `vsphere`, and `nsxt` providers still
  authenticate (a read-only plan is sufficient).

---

## 6. Backup and restore of SDDC Manager & VCF Operations

Protect the VCF control plane so the fleet can be recovered independently of
the workloads it manages.

- Configure and verify scheduled backups of **SDDC Manager** and **VCF
  Operations** through their native backup configuration (file-based backup to
  an external SFTP target).
- Store backups off the management domain and validate that a restore point
  exists after any major change (converge, import, upgrade, credential/cert
  rotation).
- Test restore procedures periodically so recovery is proven, not assumed.
- Keep this framework's `site.yaml` (and its `TF_VAR_*` secret inventory) in
  your own secure backup, since they describe the fleet topology used to
  reconstruct the IaC state.

Follow the backup and restore procedures for VCF 9.1 in Broadcom TechDocs,
VMware Cloud Foundation 9.1.

---

## 7. Upgrade and lifecycle

An imported domain enters the fleet at its **earliest-component version** (for
example, vSphere 8 / NSX 4 lands as a VCF 5.x workload domain) and must be
upgraded to VCF 9.1 afterward. Because this framework is pinned to VCF 9.1,
plan the post-adoption upgrade before relying on 9.1-only capabilities.

The full upgrade and post-adoption lifecycle procedure lives in the design set:
[`../design/08-post-adoption-lifecycle-upgrade.md`](../design/08-post-adoption-lifecycle-upgrade.md).

---

## 8. Managing an adopted domain in place

Both converge and import are **manual gates** — the `vmware/vcf` provider has
no converge/import resource. This framework therefore **adopts** the resulting
domain read-only rather than creating it:

- The converged **management domain** is adopted in stage
  [`10-converge`](../../iac/stages/10-converge).
- Imported **VI workload domains** are adopted in stage
  [`20-import-workload-domain`](../../iac/stages/20-import-workload-domain).

Both use the [`adopt-domain`](../../iac/modules/adopt-domain) module, which
wraps a read-only `data "vcf_domain"` lookup. To manage an adopted domain in
place:

1. Add the domain name to `site.yaml` (`adoption.management_domain_name` for
   the converged management domain, or `adoption.imported_workload_domains[]`
   for imported workload domains).
2. Run the adopting stage so the `data "vcf_domain"` source resolves the domain
   into its own isolated state:
   ```bash
   make plan  STAGE=20-import-workload-domain
   make apply STAGE=20-import-workload-domain
   ```
3. Downstream expansion stages (network pools, hosts, clusters, edge clusters,
   Supervisors) then reference the adopted domain by its resolved identifiers.

Because adoption is read-only, this framework never destroys or re-creates a
converged/imported domain — it only expands around it. If the `data "vcf_domain"`
lookup returns nothing, see
[Troubleshooting → Terraform-specific](./troubleshooting.md#terraform-specific).
