# Import Runbook — Add an Existing vCenter as a VI Workload Domain

Use this runbook when you **already have a VCF 9.0+ fleet** and want to add an
existing vCenter (with its vSphere/vSAN/NSX estate) as a **VI workload domain**.
Import is performed in the **VCF Operations UI** — it is a manual gate with no
Terraform resource. Once it completes, the Terraform stages adopt the imported
domain and, optionally, expand and upgrade the fleet.

> If you have **no VCF yet**, converge first to create your management domain —
> see [`converge-runbook.md`](converge-runbook.md).

Each step below is marked **[MANUAL]** (operator action in a UI) or
**[AUTOMATED]** (a Terraform stage). For the architecture and full ordered
pipeline, see [`architecture.md`](architecture.md).

## Before you begin

Complete [`prerequisites.md`](prerequisites.md) in full. The import-specific
gating items are:

- **An existing VCF fleet** reachable through **VCF Operations**, and the
  **target VCF instance must be 9.0 or later**.
- Source minimums: vCenter 8.0 Update 3a+, ESX 8.0 Update 3+, optional vSAN
  8.0 Update 3, optional NSX 4.2+.
- **SSH enabled on the source vCenter**; forward + reverse DNS; consistent NTP.
- If NSX is present, it must be a **3-node NSX Manager cluster**. The vCenter
  and NSX appliances may reside **either in the imported workload domain or in
  the management domain** — a mixed placement is allowed.

### Distributed Firewall activation — plan a maintenance window

Import **activates NSX on the cluster's distributed port groups**, which
switches **on** the Distributed Firewall (DFW) across your **running
workloads**. This is a significant change to production east-west traffic:

- Review the NSX DFW default rules before import so traffic is not
  unintentionally blocked once the firewall is enforcing.
- **Schedule a maintenance window** for the import.
- Communicate the change to application owners whose workloads run on the
  affected port groups.

### Version-at-import — enters at earliest component, upgrade after

An imported domain enters the fleet at the **effective version of its earliest
component**. For example, a source running **vSphere 8 / NSX 4** is onboarded as
a **VCF 5.x** workload domain — not 9.1. Plan to **upgrade the domain to 9.1
after import** (see Step 6). **Full VCF 9.1 features require every component to
be at 9.1.**

Validate readiness:

```bash
make preflight            # read-only DNS/NTP/tooling checks
```

## Procedure

### Step 1 — Confirm depot, binaries, and activation **[MANUAL]**

In **VCF Operations**, confirm the software depot / binaries and activation are
configured for the fleet so the imported domain can later be upgraded to the
VCF 9.1 BOM. This configuration is **always manual**.

### Step 2 — Launch the Import-a-vCenter wizard **[MANUAL gate]**

In the **VCF Operations UI**, go to **Inventory → Instance → Add Workload
Domain → Import a vCenter** and work through the wizard:

1. **Provide the source vCenter FQDN and credentials.** Accept / verify the SSL
   thumbprint (you can pre-collect it with
   [`../../iac/scripts/thumbprints.sh`](../../iac/scripts/thumbprints.sh)).
2. **Run the prechecks.** The wizard validates version minimums, DNS, NTP, SSH,
   DRS, and cluster configuration. Resolve any failures before continuing — all
   clusters of the source are imported together.
3. **Acknowledge the DFW-activation warning.** The wizard warns that NSX will be
   activated on the distributed port groups and the Distributed Firewall will be
   switched on across running workloads. Proceed only within your planned
   maintenance window.
4. **Choose the NSX option — bind or deploy:**
   - **Bind** to the source's existing NSX (must be a 3-node NSX Manager
     cluster), **or**
   - **Deploy** a new NSX for the imported domain.
   Decide where the vCenter and NSX appliances reside (imported WLD or
   management domain; mixed is allowed).
5. **Submit** the import.

This is the import manual gate — see the Broadcom reference at the bottom of
this page.

### Step 3 — Monitor the import task **[MANUAL]**

Track progress in **VCF Operations → Fleet Management → Tasks** until the
import task completes successfully. Do not start the adoption stage until the
task reports success and the new VI workload domain appears in the inventory.

### Step 4 — Register the domain / apply licenses **[MANUAL]**

Ensure the imported domain is **licensed and registered** in VCF Operations.
This step is **always manual**. Confirm `fleet.sddc_manager` in `site.yaml`
points at the managing SDDC Manager and that `TF_VAR_sddc_manager_password` is
set.

### Step 5 — Adopt the imported workload domain(s) **[AUTOMATED — stage 20]**

Add each imported domain's name under `adoption.imported_workload_domains` in
`site.yaml`:

```yaml
adoption:
  imported_workload_domains:
    - name: wld-brownfield-01
```

Then adopt them. Stage 20 looks each domain up read-only
(`data "vcf_domain"`) for every entry and makes no changes to the domains.

```bash
export TF_VAR_sddc_manager_password='********'
make plan  STAGE=20-import-workload-domain
make apply STAGE=20-import-workload-domain
```

Stage 20 publishes `imported_domain_ids` and `imported_domain_status` (maps
keyed by domain name). Confirm each domain's status is active.

Reference: [`../../iac/stages/20-import-workload-domain`](../../iac/stages/20-import-workload-domain).

### Step 6 — Upgrade the imported domain to VCF 9.1 **[MANUAL]**

Because the domain entered at the version of its earliest component (for
example VCF 5.x for a vSphere 8 / NSX 4 source), **upgrade it to VCF 9.1**
through the fleet lifecycle workflow in VCF Operations. Only after every
component reaches 9.1 are full VCF 9.1 features available. Lifecycle and
upgrade procedures are covered under [`../operations/`](../operations/).

### Step 7 — Optionally expand the fleet **[AUTOMATED — stages 30→70]**

Once the imported domain is adopted (and, ideally, upgraded), you can expand
the fleet exactly as in the converge path. Respect the ordering constraints —
**network pool before host commission**, **edge cluster before Supervisor**:

```bash
make apply STAGE=30-network-pools     # network pools (before hosts)
make apply STAGE=40-host-commission   # commission ESX hosts
make apply STAGE=50-workload-domain   # new VI workload domain
make apply STAGE=60-edge-cluster      # NSX Edge cluster (before Supervisor)
make apply STAGE=70-supervisor        # activate Supervisor
```

Provide the `TF_VAR_*` secrets each stage needs (see
[`prerequisites.md`](prerequisites.md)). Expansion sections in `site.yaml` are
optional and guarded with `try(...)`; skip any you do not need.

## Manual vs automated summary

| Step | Phase | Type | Stage / gate |
| --- | --- | --- | --- |
| 1 | Confirm depot / binaries / activation | [MANUAL] | VCF Operations |
| 2 | Import-a-vCenter wizard (credentials, prechecks, DFW warning, NSX bind/deploy) | [MANUAL gate] | VCF Operations UI |
| 3 | Monitor import (Fleet Management → Tasks) | [MANUAL] | VCF Operations |
| 4 | License + register domain | [MANUAL] | VCF Operations |
| 5 | Adopt imported workload domain(s) | [AUTOMATED] | `iac/stages/20-import-workload-domain` |
| 6 | Upgrade imported domain to 9.1 | [MANUAL] | VCF Operations lifecycle |
| 7 | Optionally expand (pools→Supervisor) | [AUTOMATED] | `iac/stages/30-network-pools` … `70-supervisor` |

## Related documentation

- Prerequisites and credentials matrix: [`prerequisites.md`](prerequisites.md)
- Architecture and pipeline: [`architecture.md`](architecture.md)
- Converge path (for the first management domain): [`converge-runbook.md`](converge-runbook.md)
- UI-only walkthrough: [`manual-deployment-guide.md`](manual-deployment-guide.md)
- Design and operations: [`../design/`](../design/), [`../operations/`](../operations/)

## References

- Broadcom TechDocs — [Import an Existing vCenter to Create a Workload Domain](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/building-your-private-cloud-infrastructure/working-with-workload-domains/import-an-existing-vcenter-to-create-a-workload-domain.html)
