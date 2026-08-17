# Operations — VCF 9.1 Brownfield Fleet

Day-2 operations and troubleshooting for a VMware Cloud Foundation 9.1 fleet
that was onboarded from an existing (brownfield) vSphere estate via the manual
**converge** or **import** gate and then expanded with this Terraform.

Use these documents once the initial adoption is complete and the fleet is in
production. For the one-time onboarding steps, see
[`../deployment/`](../deployment/README.md); for the underlying design
rationale, see [`../design/`](../design/README.md).

## Documents

| Document | Purpose |
| --- | --- |
| [Day-2 operations](./day-2-operations.md) | Ongoing lifecycle of an adopted/expanded fleet: adding brownfield hosts, adding clusters, drift and sync between vCenter and SDDC Manager, credential rotation, certificate management, backup/restore, and managing an adopted domain in place. |
| [Troubleshooting](./troubleshooting.md) | Phase-by-phase symptom/cause/resolution catalog spanning preflight, converge, import, host commission, workload-domain creation, edge/BGP, Supervisor activation, and Terraform-specific issues. |

Code lives in [`../../iac`](../../iac/README.md). The repository is pinned to
VCF 9.1 only.
