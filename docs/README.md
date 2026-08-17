# Documentation — Loyapally's VCF 9.1 Brownfield Deployment Framework

This documentation covers onboarding an existing (brownfield) vSphere estate
into VMware Cloud Foundation 9.1 through the manual **converge** or **import**
gate, then expanding the resulting fleet with Terraform. It is organized into
three areas — read them in the order Design → Deployment → Operations, or jump
straight to the entry-point that matches your task.

## The three areas

| Area | Location | When to use it |
| --- | --- | --- |
| **Design** | [`./design/`](./design/README.md) | Understand the methodology and trade-offs *before* you act: converge vs. import vs. upgrade, readiness and prerequisites, supported scenarios, domain mapping, NSX coexistence, storage, security/identity, and post-adoption lifecycle. |
| **Deployment** | [`./deployment/`](./deployment/README.md) | Perform the one-time onboarding: prerequisites, architecture, the converge runbook, the import runbook, and the manual deployment guide that leads into the Terraform stages. |
| **Operations** | [`./operations/`](./operations/README.md) | Run the fleet day-2: adding brownfield hosts, adding clusters, drift/sync, credential rotation, certificate management, backup/restore, upgrades, and troubleshooting. |

## Top entry-point documents

| Start here | Document |
| --- | --- |
| Methodology & approach | [`./design/00-methodology.md`](./design/00-methodology.md) |
| Choosing converge vs. import vs. upgrade | [`./design/01-converge-vs-import-vs-upgrade.md`](./design/01-converge-vs-import-vs-upgrade.md) |
| Readiness & prerequisites | [`./design/02-readiness-and-prerequisites.md`](./design/02-readiness-and-prerequisites.md) |
| Deployment prerequisites | [`./deployment/prerequisites.md`](./deployment/prerequisites.md) |
| Converge runbook | [`./deployment/converge-runbook.md`](./deployment/converge-runbook.md) |
| Import runbook | [`./deployment/import-runbook.md`](./deployment/import-runbook.md) |
| Day-2 operations | [`./operations/day-2-operations.md`](./operations/day-2-operations.md) |
| Troubleshooting | [`./operations/troubleshooting.md`](./operations/troubleshooting.md) |

## Code

The Terraform lives in [`../iac`](../iac/README.md) — stages, modules, scripts,
and the `config/site.yaml` single source of truth. The framework is pinned to
VCF 9.1 only. See the [root README](../README.md) for a repository overview and
quick start.
