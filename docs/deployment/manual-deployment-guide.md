# Manual Deployment Guide — VCF 9.1 Brownfield (UI-only)

This guide is a **console-only, click-by-click** walkthrough of the entire
VCF 9.1 brownfield sequence for administrators who prefer the user interface.
It uses **no Terraform**. Every phase ends with a short note naming the
Terraform stage that automates the same outcome, so you can adopt IaC later
without relearning the flow.

For the IaC-driven versions of the same paths, see
[`converge-runbook.md`](converge-runbook.md) and
[`import-runbook.md`](import-runbook.md). For prerequisites and the credentials
matrix, see [`prerequisites.md`](prerequisites.md).

> Choose your entry path first:
> - **No VCF yet?** Do Phases 1–3A (converge), then 4 onward.
> - **Existing VCF 9.0+ fleet?** Skip to Phase 3B (import), then 4 onward.

## Phase 1 — Deploy the VCF Installer appliance (converge path only)

1. Obtain the `VCF-Installer-9.1.0.0-*.ova` from the Broadcom depot.
2. In the vSphere Client of your existing environment, choose **Deploy OVF
   Template** and select the Installer OVA.
3. Set the appliance name, compute/storage placement, and the network
   properties: **FQDN, IP, subnet mask, gateway, DNS, and NTP** (matching your
   forward+reverse DNS records).
4. Power on the appliance and browse to `https://<installer-fqdn>`.

> **Automated equivalent:** [`../../iac/scripts/deploy-installer.sh`](../../iac/scripts/deploy-installer.sh)
> deploys the same OVA via `ovftool` (dry-run by default; add `--confirm`).

## Phase 2 — Configure depot, binaries, and activation code

1. In the VCF Installer UI (converge) or **VCF Operations** (import), open the
   depot / binaries configuration.
2. Point it at the online depot or an offline bundle providing the **VCF 9.1
   bill of materials**.
3. Enter the **activation code**.

> **This phase is always manual** — there is no Terraform equivalent. It is
> required regardless of whether you later automate the rest of the pipeline.

## Phase 3A — Converge wizard (no VCF yet)

1. In the VCF Installer UI, start **Converge to VCF**.
2. Enter the **source vCenter** FQDN and credentials; accept the SSL thumbprint.
3. Confirm the source complies: **DRS fully automated**, clusters managed by
   **vLCM images**, **no VCHA**, vCenter **not already attached to an SDDC
   Manager**, no unsupported standalone/single-host clusters, and **SSH enabled
   on vCenter**.
4. Select the **vCenter and ESX hosts** to converge (all clusters convert
   together).
5. **Optionally include vSAN and NSX**. If NSX is included, confirm it is a
   **3-node NSX Manager cluster**.
6. Run the wizard **validation / prechecks** and fix any flagged items.
7. **Submit** and monitor the task to completion.

The result is your **first VCF 9.1 management domain**, managed by SDDC Manager.

> **Automated equivalent (adoption):** [`../../iac/stages/10-converge`](../../iac/stages/10-converge)
> adopts the converged management domain read-only. The converge action itself
> is always manual.

## Phase 3B — Import wizard (existing VCF 9.0+ fleet)

1. In **VCF Operations**, go to **Inventory → Instance → Add Workload Domain →
   Import a vCenter**.
2. Enter the **source vCenter** FQDN and credentials; accept/verify the SSL
   thumbprint.
3. Run the **prechecks** and resolve any failures (versions, DNS, NTP, SSH,
   DRS, cluster config).
4. **Acknowledge the Distributed Firewall warning.** Import activates NSX on the
   distributed port groups and switches **on** the DFW across running
   workloads — proceed only inside a **planned maintenance window**.
5. Choose the **NSX option**: **bind** to the existing 3-node NSX Manager
   cluster, or **deploy** new NSX. Decide appliance placement (imported WLD or
   management domain; mixed allowed).
6. **Submit**, then monitor in **Fleet Management → Tasks** until it succeeds.

Note the imported domain enters at the **version of its earliest component**
(for example VCF 5.x for a vSphere 8 / NSX 4 source); **upgrade it to 9.1
afterward** via the fleet lifecycle workflow. Full 9.1 features require all
components at 9.1.

> **Automated equivalent (adoption):** [`../../iac/stages/20-import-workload-domain`](../../iac/stages/20-import-workload-domain)
> adopts each imported workload domain read-only. The import action itself is
> always manual.

## Phase 4 — Apply licenses and register the fleet

1. In **VCF Operations**, apply the VCF 9.1 **licenses**.
2. **Register the fleet** so it is fully managed.

> **This phase is always manual** — there is no Terraform equivalent.

## Phase 5 — Create a network pool (vSphere Client / SDDC Manager)

1. In SDDC Manager, open **Network Settings → Network Pools** and choose
   **Create Network Pool**.
2. Add the **vSAN** and **vMotion** networks: VLAN ID, MTU (for example 9000),
   subnet, mask, gateway, and the included IP range.
3. Save the pool.

> A network pool must exist **before** you commission hosts.
> **Automated equivalent:** [`../../iac/stages/30-network-pools`](../../iac/stages/30-network-pools).

## Phase 6 — Commission ESX hosts

1. In SDDC Manager, open **Hosts → Commission Hosts**.
2. For each host, enter its **FQDN**, **root** credentials, **storage type**
   (for example vSAN), and the **network pool** created in Phase 5; accept the
   host thumbprint.
3. Run the commission validation and submit.

> **Automated equivalent:** [`../../iac/stages/40-host-commission`](../../iac/stages/40-host-commission).

## Phase 7 — Create / verify a workload domain

1. In SDDC Manager, choose **Workload Domains → + Workload Domain → VI**.
2. Provide the **vCenter** (FQDN, IP, datacenter), **NSX** (3-node manager
   cluster, VIP), **SSO**, and **cluster** details, selecting the commissioned
   hosts.
3. Configure the **vDS and port groups** (management, vMotion, vSAN) and the
   vSAN datastore (**vSAN ESA** is the default in VCF 9.1).
4. Run validation, submit, and verify the domain becomes active.

> For an **imported** domain, this domain already exists — verify it in the
> inventory instead of creating a new one.
> **Automated equivalent:** [`../../iac/stages/50-workload-domain`](../../iac/stages/50-workload-domain).

## Phase 8 — Create an NSX Edge cluster (Tier-0 A/A, BGP)

1. In SDDC Manager, open the target workload domain and choose **Add Edge
   Cluster**.
2. Define the edge nodes (form factor, management IP/VLAN, **TEP** addressing).
3. Configure **Tier-0** as **Active/Active** with **eBGP** uplinks: uplink
   VLANs/IPs, local ASN, and BGP peer IP/ASN (and peer password).
4. Add a **Tier-1** gateway attached to the Tier-0.
5. Run validation and submit; confirm BGP peers establish.

> An edge cluster must exist **before** you activate a Supervisor.
> **Automated equivalent:** [`../../iac/stages/60-edge-cluster`](../../iac/stages/60-edge-cluster).

## Phase 9 — Activate a vSphere Supervisor

1. In the vSphere Client, open **Workload Management** and start **Enable
   Supervisor** on the target cluster.
2. Select the **storage policy**, the **NSX Edge cluster** from Phase 8, and the
   **content library**.
3. Configure networking: **management network** range, and the
   **ingress / egress / pod / service CIDRs**.
4. Create the initial **namespace** and enable the Supervisor.

> **Automated equivalent:** [`../../iac/stages/70-supervisor`](../../iac/stages/70-supervisor).

## Manual vs automated — when to use which

Both approaches drive the **same** VCF 9.1 outcome. The two brownfield entry
gates (converge / import) and the depot/activation and license/register steps
are **always manual** either way; only the adopt-and-expand phases have a
Terraform equivalent.

**Prefer the UI (this guide) when:**

- Performing the one-time converge or import gate, which has no Terraform
  resource in any case.
- Onboarding a single site interactively, or when an operator wants to watch
  each precheck and task in real time.
- Learning the workflow before codifying it.

**Prefer the Terraform stages when:**

- Repeating fleet **expansion** (network pools, hosts, workload domains, edge
  clusters, Supervisors) across sites or over time.
- You want **reviewable, version-controlled** change with plan/apply,
  formatting, and validation gates (`make fmt-check`, `make validate`, `make
  plan`, `make apply`).
- You want the fleet described by a **single source of truth**
  ([`../../iac/config/site.example.yaml`](../../iac/config/site.example.yaml))
  with secrets confined to `TF_VAR_*` environment variables and **isolated
  per-stage state**.

A common pattern is to run the manual gates and the always-manual
depot/license steps in the UI, then adopt (stage 10 or 20) and expand
(stages 30→70) with Terraform.

## Related documentation

- Prerequisites and credentials matrix: [`prerequisites.md`](prerequisites.md)
- Architecture and pipeline: [`architecture.md`](architecture.md)
- IaC runbooks: [`converge-runbook.md`](converge-runbook.md), [`import-runbook.md`](import-runbook.md)
- Design and operations: [`../design/`](../design/), [`../operations/`](../operations/)

## References

- Broadcom TechDocs — [Converging your existing vSphere infrastructure to a VCF or VVF platform](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/converging-your-existing-vsphere-infrastructure-to-a-vcf-or-vvf-platform-.html)
- Broadcom TechDocs — [Converge a vCenter Instance, ESX Hosts, and Optionally vSAN and NSX](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/converging-your-existing-vsphere-infrastructure-to-a-vcf-or-vvf-platform-/supported-scenarios-to-converge-to-vcf/converge-your-existing-vcenter-instance-and-esx-hosts.html)
- Broadcom TechDocs — [Import an Existing vCenter to Create a Workload Domain](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/building-your-private-cloud-infrastructure/working-with-workload-domains/import-an-existing-vcenter-to-create-a-workload-domain.html)
