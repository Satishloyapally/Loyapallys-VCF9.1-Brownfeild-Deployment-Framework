# 07 — Security and Identity

This document covers the identity, certificate, credential, and firewall
posture design for brownfield onboarding into **VMware Cloud Foundation 9.1**.

## SSO and identity

The converged management domain and each imported/expanded workload domain use
the vSphere **SSO** domain for platform identity. In
[`iac/config/site.example.yaml`](../../iac/config/site.example.yaml) the SSO
domain is declared per workload domain:

```yaml
new_workload_domain:
  sso:
    domain_name: vsphere.local
    # domain_password -> env TF_VAR_sso_domain_password
```

Design points:

- Keep a consistent SSO domain across the fleet where the topology allows it, so
  fleet-wide operations and VCF Operations reporting behave predictably.
- The SSO administrator (`administrator@vsphere.local`) is used by the adopt and
  expand stages via `fleet.sddc_manager.username`.
- Federate to an external identity provider through VCF Operations as a day-2
  step; that is outside the default scope of these stages.

## Certificate trust during converge and import

Both gates require the source vCenter (and NSX, if present) certificates to be
trusted:

- **Production**: establish trust so the gate and the IaC stages validate TLS.
  Keep `fleet.allow_unverified_tls: false`.
- **Lab only**: `fleet.allow_unverified_tls: true` relaxes verification for
  self-signed certificates. Do not use this in production.

Certificate management (rotation, CA-signed replacement) is a day-2 operation
through VCF Operations / SDDC Manager after adoption.

## Credential handling via `TF_VAR_*`

**No secret is ever written to `site.yaml`.** Every credential is supplied
through a `TF_VAR_*` environment variable. The variables referenced by the
stages are:

| Environment variable | Used for |
| --- | --- |
| `TF_VAR_sddc_manager_password` | SDDC Manager (adopt/expand stages) |
| `TF_VAR_installer_password` | VCF Installer (converge gate) |
| `TF_VAR_host_password` | ESX `root` at host commission |
| `TF_VAR_vcenter_root_password` | New workload-domain vCenter root |
| `TF_VAR_nsx_admin_password` / `TF_VAR_nsx_audit_password` | NSX manager admin/audit |
| `TF_VAR_sso_domain_password` | SSO domain password |
| `TF_VAR_edge_*_password` | Edge node admin/audit/root |
| `TF_VAR_bgp_peer_password` | BGP peer authentication |

`site.yaml` holds only non-secret references (hostnames, usernames, network
addressing). This keeps the single source of truth safe to commit as
`site.example.yaml` and to share as a redacted `site.yaml`.

## FIPS

VCF 9.1 supports operating the platform under **FIPS**-validated cryptography.
If the target environment mandates FIPS, confirm the mode is set consistently
across the management and workload domains, and that any external integrations
(identity providers, certificate authorities) are compatible. FIPS mode is a
platform-level setting managed outside these IaC stages.

## Distributed Firewall default-on after import

Importing an existing vCenter **activates NSX on the cluster's distributed port
groups**, which switches **on** the NSX Distributed Firewall (DFW) across every
running workload. Security implications:

- Immediately after import, east-west traffic is governed by the DFW default
  rule set. Absent an explicit allow policy, previously unfiltered traffic may
  be blocked.
- Prepare DFW policy before import; validate application connectivity right
  after; then tighten toward least privilege.
- Record the change with security owners — it is a fleet-visible posture change.

The networking-side treatment of this behavior is in
[05-nsx-coexistence.md](./05-nsx-coexistence.md); the risk is also listed in
[03-supported-scenario-matrix.md](./03-supported-scenario-matrix.md).

## References

- [Import an Existing vCenter to Create a Workload Domain](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/building-your-private-cloud-infrastructure/working-with-workload-domains/import-an-existing-vcenter-to-create-a-workload-domain.html)
- Broadcom TechDocs, VMware Cloud Foundation 9.1
