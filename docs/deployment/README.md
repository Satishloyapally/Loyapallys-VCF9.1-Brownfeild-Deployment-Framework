# Deployment — Loyapally's VCF 9.1 Brownfield Deployment Framework

This directory documents how to onboard an **existing** (brownfield) VMware
Cloud Foundation 9.1 estate and then expand the resulting fleet with
Infrastructure as Code.

The framework follows an **adopt-then-expand** model. Brownfield onboarding
always begins with a **manual gate** in a VCF user interface — the
`vmware/vcf` Terraform provider has no converge or import resource. Once a
management domain or workload domain exists, the Terraform stages under
[`../../iac/stages`](../../iac/stages) **adopt** it (read-only
`data "vcf_domain"`) and then **expand** the fleet (network pools, hosts,
workload domains, edge clusters, and Supervisors).

There are two entry paths into VCF 9.1:

| Entry path | Where it runs | Use when |
| --- | --- | --- |
| **Converge** | VCF Installer UI | You have **no** VCF yet and want to turn an existing standalone vSphere environment into your **first** VCF 9.1 management domain. |
| **Import** | VCF Operations UI (Inventory → Instance → Add Workload Domain → Import a vCenter) | You already have a VCF 9.0+ fleet and want to add an existing vCenter as a VI workload domain. |

## The adopt-then-expand sequence at a glance

The table below maps the end-to-end sequence to the Broadcom phase and to the
Terraform stage that automates it. Steps marked **manual gate** are always
performed by an operator in a UI and have no Terraform equivalent.

| Step | Broadcom phase | This repo's stage / gate |
| --- | --- | --- |
| 1 | Deploy the VCF Installer appliance (converge path only) | [`../../iac/scripts/deploy-installer.sh`](../../iac/scripts/deploy-installer.sh) (deploy helper) |
| 2 | Configure depot / binaries / activation code | **manual gate** (VCF Installer or VCF Operations UI) |
| 3a | **Converge** existing vSphere → first VCF 9.1 management domain | **manual gate** (VCF Installer UI) |
| 3b | **Import** existing vCenter → VI workload domain | **manual gate** (VCF Operations UI) |
| 4 | Apply licenses and register the fleet in VCF Operations | **manual gate** (VCF Operations UI) |
| 5 | Adopt the converged management domain | [`../../iac/stages/10-converge`](../../iac/stages/10-converge) |
| 6 | Adopt imported vCenter workload domain(s) | [`../../iac/stages/20-import-workload-domain`](../../iac/stages/20-import-workload-domain) |
| 7 | Create network pool(s) | [`../../iac/stages/30-network-pools`](../../iac/stages/30-network-pools) |
| 8 | Commission ESX hosts | [`../../iac/stages/40-host-commission`](../../iac/stages/40-host-commission) |
| 9 | Create a new VI workload domain | [`../../iac/stages/50-workload-domain`](../../iac/stages/50-workload-domain) |
| 10 | Deploy an NSX Edge cluster | [`../../iac/stages/60-edge-cluster`](../../iac/stages/60-edge-cluster) |
| 11 | Activate a vSphere Supervisor | [`../../iac/stages/70-supervisor`](../../iac/stages/70-supervisor) |

Two ordering constraints are enforced by the stage numbering and must be
respected: a **network pool must exist before hosts are commissioned**
(stage 30 before stage 40), and an **edge cluster must exist before a
Supervisor is activated** (stage 60 before stage 70).

Steps 2 and 4 are always manual even when the rest of the pipeline is
automated: the depot/binaries/activation configuration and the license +
fleet registration are performed only in the VCF Installer / VCF Operations
UI.

## Documents in this set

| Document | Purpose |
| --- | --- |
| [`prerequisites.md`](prerequisites.md) | Pre-deployment checklist: version minimums, DNS, NTP, SSH, the credentials matrix (`TF_VAR_*`), network/VLAN plan, vLCM, DRS, and preflight. Read this first. |
| [`architecture.md`](architecture.md) | The adopt-then-expand architecture, the full ordered pipeline with both manual gates and both always-manual steps, a pipeline diagram, and how isolated per-stage state flows between stages. |
| [`converge-runbook.md`](converge-runbook.md) | End-to-end **converge** path: deploy the Installer, depot/binaries/activation, the converge wizard, adopt via stage 10, then expand (stages 30→70). |
| [`import-runbook.md`](import-runbook.md) | End-to-end **import** path: the VCF Operations Import-a-vCenter wizard (including the Distributed Firewall activation warning), adopt via stage 20, then optionally expand and upgrade. |
| [`manual-deployment-guide.md`](manual-deployment-guide.md) | UI-only, click-by-click walkthrough of the whole VCF 9.1 brownfield sequence for administrators who prefer the console, with pointers to the Terraform stage that automates each phase. |

## Related documentation

- Design decisions and topology: [`../design/`](../design/)
- Day-2 operations, upgrades, and lifecycle: [`../operations/`](../operations/)
- IaC reference (stages, modules, `site.yaml` schema): [`../../iac/README.md`](../../iac/README.md)

## Scope and pinning

This framework targets **VCF 9.1 only**. Providers are pinned to
`vmware/vcf 0.18.1`, `vmware/vsphere 2.16.1`, and `vmware/nsxt 3.12.0`. The
single source of truth for every stage is
[`../../iac/config/site.example.yaml`](../../iac/config/site.example.yaml);
copy it to `site.yaml` (git-ignored) and supply all secrets through
`TF_VAR_*` environment variables.

## References

- Broadcom TechDocs — [Converging your existing vSphere infrastructure to a VCF or VVF platform](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/converging-your-existing-vsphere-infrastructure-to-a-vcf-or-vvf-platform-.html)
- Broadcom TechDocs — [Import an Existing vCenter to Create a Workload Domain](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/building-your-private-cloud-infrastructure/working-with-workload-domains/import-an-existing-vcenter-to-create-a-workload-domain.html)
