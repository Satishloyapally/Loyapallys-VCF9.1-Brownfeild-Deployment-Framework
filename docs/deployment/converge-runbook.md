# Converge Runbook — First VCF 9.1 Management Domain

Use this runbook when you have **no VCF yet** and want to turn an existing
standalone vSphere environment into your **first** VCF 9.1 management domain.
Convergence is performed in the **VCF Installer UI** — it is a manual gate with
no Terraform resource. Once it completes, the Terraform stages adopt the
resulting management domain and expand the fleet.

> If you already have a VCF 9.0+ fleet and want to add an existing vCenter,
> use [`import-runbook.md`](import-runbook.md) instead.

Each step below is marked **[MANUAL]** (operator action in a UI or a helper
script) or **[AUTOMATED]** (a Terraform stage). For the architecture and the
full ordered pipeline, see [`architecture.md`](architecture.md).

## Before you begin

Complete [`prerequisites.md`](prerequisites.md) in full. The converge-specific
gating items are:

- vCenter 8.0 Update 3a+, ESX 8.0 Update 3+, optional vSAN 8.0 Update 3,
  optional NSX 4.2+.
- **SSH enabled on the source vCenter**; forward + reverse DNS; consistent NTP.
- **DRS fully automated** on all clusters.
- Clusters managed by **vSphere Lifecycle Manager images** (convert
  baseline-managed clusters first).
- **All clusters convert together** (no partial converge), **no VCHA**, the
  vCenter is **not already attached to an SDDC Manager**, and there are **no
  unsupported standalone/single-host clusters** (unless a qualifying cluster
  also exists).
- If NSX is present, it must be a **3-node NSX Manager cluster**.

Validate readiness:

```bash
make preflight            # read-only DNS/NTP/tooling checks
```

## Procedure

### Step 1 — Deploy the VCF Installer appliance **[MANUAL]**

The VCF Installer is the entry point for the converge gate. Deploy its OVA with
the helper script, which performs a **dry run by default** and prints the exact
`ovftool` command it would execute; add `--confirm` to actually deploy.

```bash
iac/scripts/deploy-installer.sh \
  --ova   /path/to/VCF-Installer-9.1.0.0-*.ova \
  --target "vi://administrator@vsphere.local@vcenter.example.com/DC/host/Cluster" \
  --fqdn  vcf-installer.vcf.example.com \
  --ip    10.0.0.50 --mask 255.255.255.0 --gw 10.0.0.1 \
  --dns   10.0.0.10  --ntp 10.0.0.10
# review the printed command, then re-run with --confirm to deploy
```

When deployment finishes, open `https://vcf-installer.vcf.example.com` to
continue in the Installer UI. Record the Installer host/username under
`fleet.installer` in `site.yaml` and set `TF_VAR_installer_password`.

Reference: [`../../iac/scripts/deploy-installer.sh`](../../iac/scripts/deploy-installer.sh).

### Step 2 — Configure depot, binaries, and activation code **[MANUAL]**

In the VCF Installer UI, configure the software depot / binaries and enter the
**activation code**. This step is **always manual** and has no Terraform
equivalent. Ensure the depot provides the VCF 9.1 bill of materials so the
converged domain lands on the 9.1 BOM.

### Step 3 — Run the Converge wizard **[MANUAL]**

In the VCF Installer UI, start **Converge to VCF** and work through the wizard:

1. **Provide source vCenter details** and credentials; accept the SSL
   thumbprint. Use [`../../iac/scripts/thumbprints.sh`](../../iac/scripts/thumbprints.sh)
   to pre-collect thumbprints if you want to verify them:
   ```bash
   iac/scripts/thumbprints.sh vcenter.example.com
   ```
2. **Converge the vCenter instance and ESX hosts.** All clusters are converted
   together.
3. **Optionally include vSAN and NSX** if present in the source. If NSX is
   included, confirm it is a 3-node NSX Manager cluster.
4. **Run the wizard's validation / prechecks** and resolve any flagged items
   (DRS automation level, vLCM image management, DNS, NTP, SSH). Do not proceed
   until validation passes.
5. **Submit** and monitor the converge task to completion in the Installer UI.

The result is your first VCF 9.1 **management domain**, now managed by an SDDC
Manager. This is the converge manual gate — see the Broadcom reference at the
bottom of this page.

### Step 4 — Apply licenses and register the fleet **[MANUAL]**

In **VCF Operations**, apply the VCF 9.1 licenses and **register the fleet**.
This step is **always manual**. Record the SDDC Manager host/username under
`fleet.sddc_manager` in `site.yaml` and set `TF_VAR_sddc_manager_password`.

### Step 5 — Adopt the management domain **[AUTOMATED — stage 10]**

With the fleet registered, adopt the converged management domain so its ID is
available to downstream stages. Stage 10 reads
`adoption.management_domain_name` from `site.yaml` and looks the domain up
read-only (`data "vcf_domain"`) — it makes no changes to the domain.

```bash
export TF_VAR_sddc_manager_password='********'
make plan  STAGE=10-converge
make apply STAGE=10-converge
```

Stage 10 publishes `management_domain_id`, `management_domain_status`, and
`management_vcenter`. Confirm `management_domain_status` reports the domain as
active.

Reference: [`../../iac/stages/10-converge`](../../iac/stages/10-converge).

### Step 6 — Create network pool(s) **[AUTOMATED — stage 30]**

A network pool must exist **before** hosts are commissioned. Populate
`network_pools` in `site.yaml` (vSAN and vMotion VLANs, subnets, and IP
ranges), then:

```bash
make plan  STAGE=30-network-pools
make apply STAGE=30-network-pools
```

Publishes `network_pool_ids`.
Reference: [`../../iac/stages/30-network-pools`](../../iac/stages/30-network-pools).

### Step 7 — Commission ESX hosts **[AUTOMATED — stage 40]**

Populate `hosts_to_commission` in `site.yaml` (each host references a
`network_pool_name` from the previous step). Provide ESX credentials via
`TF_VAR_host_password`.

```bash
export TF_VAR_host_password='********'
make plan  STAGE=40-host-commission
make apply STAGE=40-host-commission
```

Reference: [`../../iac/stages/40-host-commission`](../../iac/stages/40-host-commission).

### Step 8 — Create a new VI workload domain **[AUTOMATED — stage 50]**

Populate `new_workload_domain` in `site.yaml` (vCenter, NSX, SSO, and cluster
spec; vSAN ESA is the default storage in VCF 9.1). Provide the relevant
`TF_VAR_*` secrets.

```bash
export TF_VAR_vcenter_root_password='********'
export TF_VAR_nsx_admin_password='********'
export TF_VAR_nsx_audit_password='********'
export TF_VAR_sso_domain_password='********'
make plan  STAGE=50-workload-domain
make apply STAGE=50-workload-domain
```

Reference: [`../../iac/stages/50-workload-domain`](../../iac/stages/50-workload-domain).

### Step 9 — Deploy an NSX Edge cluster **[AUTOMATED — stage 60]**

An edge cluster must exist **before** a Supervisor is activated. Populate
`edge_cluster` in `site.yaml` (Tier-0/Tier-1, ACTIVE_ACTIVE, eBGP uplinks).
Provide edge and BGP secrets.

```bash
export TF_VAR_edge_admin_password='********'
export TF_VAR_edge_audit_password='********'
export TF_VAR_edge_root_password='********'
export TF_VAR_bgp_peer_password='********'
make plan  STAGE=60-edge-cluster
make apply STAGE=60-edge-cluster
```

Publishes `edge_cluster_id`.
Reference: [`../../iac/stages/60-edge-cluster`](../../iac/stages/60-edge-cluster).

### Step 10 — Activate a vSphere Supervisor **[AUTOMATED — stage 70]**

Populate `supervisor` in `site.yaml` (cluster, storage policy, management
network, ingress/egress/pod/service CIDRs, namespace). Provide the vCenter
secret.

```bash
export TF_VAR_vsphere_password='********'
make plan  STAGE=70-supervisor
make apply STAGE=70-supervisor
```

Publishes `supervisor_id`.
Reference: [`../../iac/stages/70-supervisor`](../../iac/stages/70-supervisor).

## Manual vs automated summary

| Step | Phase | Type | Stage / gate |
| --- | --- | --- | --- |
| 1 | Deploy VCF Installer | [MANUAL] | `iac/scripts/deploy-installer.sh` |
| 2 | Depot / binaries / activation | [MANUAL] | VCF Installer UI |
| 3 | Converge wizard (vCenter+ESX, optional vSAN/NSX) | [MANUAL gate] | VCF Installer UI |
| 4 | License + register fleet | [MANUAL] | VCF Operations |
| 5 | Adopt management domain | [AUTOMATED] | `iac/stages/10-converge` |
| 6 | Create network pool(s) | [AUTOMATED] | `iac/stages/30-network-pools` |
| 7 | Commission ESX hosts | [AUTOMATED] | `iac/stages/40-host-commission` |
| 8 | New VI workload domain | [AUTOMATED] | `iac/stages/50-workload-domain` |
| 9 | NSX Edge cluster | [AUTOMATED] | `iac/stages/60-edge-cluster` |
| 10 | Activate Supervisor | [AUTOMATED] | `iac/stages/70-supervisor` |

## Related documentation

- Prerequisites and credentials matrix: [`prerequisites.md`](prerequisites.md)
- Architecture and pipeline: [`architecture.md`](architecture.md)
- UI-only walkthrough: [`manual-deployment-guide.md`](manual-deployment-guide.md)
- Design and operations: [`../design/`](../design/), [`../operations/`](../operations/)

## References

- Broadcom TechDocs — [Converging your existing vSphere infrastructure to a VCF or VVF platform](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/converging-your-existing-vsphere-infrastructure-to-a-vcf-or-vvf-platform-.html)
- Broadcom TechDocs — [Supported and Not Supported Configurations to Converge](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/converging-your-existing-vsphere-infrastructure-to-a-vcf-or-vvf-platform-/supported-and-not-supported-configurations.html)
- Broadcom TechDocs — [Converge a vCenter Instance, ESX Hosts, and Optionally vSAN and NSX](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/converging-your-existing-vsphere-infrastructure-to-a-vcf-or-vvf-platform-/supported-scenarios-to-converge-to-vcf/converge-your-existing-vcenter-instance-and-esx-hosts.html)
