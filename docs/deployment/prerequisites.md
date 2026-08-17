# Prerequisites — VCF 9.1 Brownfield Deployment

Complete every item in this checklist **before** you start a converge or
import gate or run any Terraform stage. Both brownfield entry paths share the
same version, DNS, NTP, and SSH requirements; import adds a requirement on the
target fleet version.

Run the read-only preflight helper at any time to validate tooling, DNS, and
NTP without making changes:

```bash
make preflight            # wraps iac/scripts/preflight.sh
```

The preflight script verifies that `terraform` is on `PATH`, checks that each
non-example FQDN in `site.yaml` has both a forward (A) and reverse (PTR)
record, and probes NTP reachability on udp/123. It never modifies anything.

## 1. Version minimums

These minimums apply to both the converge and import gates. Verify the running
build of each component before proceeding.

| Component | Minimum version | Notes |
| --- | --- | --- |
| vCenter Server | 8.0 Update 3a or later | Source vCenter for converge/import. |
| ESX | 8.0 Update 3 or later | All hosts in the participating cluster(s). |
| vSAN | 8.0 Update 3 (optional) | Only if the source uses vSAN. |
| NSX | 4.2 or later (optional) | Only if the source has NSX; see NSX topology below. |
| Target VCF instance (import only) | 9.0 or later | The existing fleet you import **into**. |

Version awareness for import: an imported domain enters the fleet at the
**effective version of its earliest component**. For example, a source running
vSphere 8 / NSX 4 is onboarded as a **VCF 5.x** workload domain. Upgrade it to
9.1 afterward. **Full VCF 9.1 features require every component to be at 9.1.**
See [`import-runbook.md`](import-runbook.md) for the upgrade-after-import
sequence.

## 2. NSX topology (if NSX is present)

- NSX Manager must be deployed as a **3-node NSX Manager cluster**. A single
  NSX Manager is not supported.
- For **import**, the vCenter and NSX appliances may reside either in the
  imported workload domain or in the management domain — a mixed placement is
  allowed.
- Import **activates NSX on the cluster's distributed port groups**, which
  switches **on** the Distributed Firewall (DFW) across running workloads. This
  is a significant change to production traffic; plan a **maintenance window**
  and review DFW default rules before import. See
  [`import-runbook.md`](import-runbook.md).

## 3. DNS, NTP, and SSH

- **Forward and reverse DNS** must resolve for every appliance and ESX host
  (vCenter, NSX managers, SDDC Manager, VCF Installer, and each ESX FQDN). VCF
  requires both A and PTR records.
- **NTP** must be reachable and consistent across all appliances and hosts
  (udp/123). Clock skew breaks certificate and SSO operations.
- **SSH must be enabled on the source vCenter** for the converge/import
  workflow.

Populate the DNS domain, DNS servers, and NTP servers in the `infra` section
of [`../../iac/config/site.example.yaml`](../../iac/config/site.example.yaml):

```yaml
infra:
  dns_domain: vcf.example.com
  dns_servers:
    - 10.0.0.10
    - 10.0.0.11
  ntp_servers:
    - 10.0.0.10
```

## 4. Source cluster configuration (converge)

Convergence has explicit supported and not-supported configurations. Confirm
the source environment complies before starting the converge wizard:

- **DRS must be set to fully automated.** Manual or partially-automated DRS is
  not supported — change it first.
- Clusters must be **managed by vSphere Lifecycle Manager (vLCM) images**.
  Baseline-managed clusters are not supported; convert them to vLCM images
  first.
- **All clusters are converged together** — partial import of a subset of
  clusters is not supported for converge.
- **vCenter High Availability (VCHA)** is not supported for converge; remove it
  first.
- A vCenter that is **already attached to an SDDC Manager** cannot be
  converged.
- **Standalone / single-host clusters** are not supported unless a qualifying
  cluster also exists in the environment.

See the Broadcom reference for the authoritative list of supported and
not-supported configurations, linked at the bottom of this page.

## 5. Network and VLAN plan

Plan the VLANs and subnets that the expansion stages will consume. These map
directly to the `network_pools`, `new_workload_domain`, and `edge_cluster`
sections of `site.yaml`.

| Traffic type | Used by | `site.yaml` location |
| --- | --- | --- |
| vSAN | Host commissioning / vSAN datastore | `network_pools[].networks[type=VSAN]` |
| vMotion | Host commissioning | `network_pools[].networks[type=VMOTION]` |
| Management | vCenter/NSX/edge management interfaces | `new_workload_domain`, `edge_cluster.edge_nodes[]` |
| Geneve / Host TEP | NSX overlay transport | `new_workload_domain.cluster.geneve_vlan_id`, `edge_cluster.edge_nodes[].tep_*` |
| Edge uplink / BGP | Tier-0 north-south routing | `edge_cluster.edge_nodes[].uplinks[]` |

Set a consistent MTU end-to-end (the example uses `9000` for vSAN, vMotion,
and edge transport). Ensure the Tier-0 uplink VLANs and BGP peer IPs/ASNs are
provisioned on the upstream physical routers before running stage 60.

## 6. Credentials matrix (`TF_VAR_*`)

**Never put passwords in `site.yaml`.** All secrets are supplied through
`TF_VAR_*` environment variables. The mapping below is authoritative; it
mirrors [`../../iac/config/README.md`](../../iac/config/README.md).

| Environment variable | Credential | Consumed by |
| --- | --- | --- |
| `TF_VAR_installer_password` | VCF Installer admin | Converge gate / stage 10 endpoints |
| `TF_VAR_sddc_manager_password` | SDDC Manager (`administrator@vsphere.local`) | All adopt/expand stages |
| `TF_VAR_host_password` | ESX `root` | Stage 40 (host commission) |
| `TF_VAR_vcenter_root_password` | New vCenter `root` | Stage 50 (workload domain) |
| `TF_VAR_nsx_admin_password` | NSX admin | Stage 50 |
| `TF_VAR_nsx_audit_password` | NSX audit | Stage 50 |
| `TF_VAR_sso_domain_password` | SSO domain | Stage 50 |
| `TF_VAR_edge_admin_password` | Edge node admin | Stage 60 (edge cluster) |
| `TF_VAR_edge_audit_password` | Edge node audit | Stage 60 |
| `TF_VAR_edge_root_password` | Edge node root | Stage 60 |
| `TF_VAR_bgp_peer_password` | BGP peer | Stage 60 |
| `TF_VAR_vsphere_password` | Supervisor vCenter | Stage 70 (Supervisor) |

Export the variables in your shell before running the relevant stage:

```bash
export TF_VAR_sddc_manager_password='********'
export TF_VAR_host_password='********'
# ...only the variables the stages you run actually need.
```

## 7. Fleet endpoints and adoption targets

After the manual converge gate completes, record the fleet endpoints and the
names of the domains to adopt in `site.yaml`:

```yaml
fleet:
  sddc_manager:
    host: sddc-manager.vcf.example.com
    username: administrator@vsphere.local
  installer:
    host: vcf-installer.vcf.example.com
    username: admin@local
  allow_unverified_tls: false        # true only for labs with self-signed certs

adoption:
  management_domain_name: mgmt-domain
  imported_workload_domains:
    - name: wld-brownfield-01
```

Stage 10 adopts `adoption.management_domain_name`; stage 20 adopts every entry
under `adoption.imported_workload_domains`.

## 8. Tooling

- **Terraform** >= 1.7 (CI pins 1.9.8).
- **VMware OVF Tool (`ovftool`)** — required only if you deploy the VCF
  Installer OVA with `--confirm` via
  [`../../iac/scripts/deploy-installer.sh`](../../iac/scripts/deploy-installer.sh).
- **`openssl` / `ssh-keyscan`** — used by
  [`../../iac/scripts/thumbprints.sh`](../../iac/scripts/thumbprints.sh) to
  collect SSL/SSH thumbprints when trusting certificates or commissioning
  hosts.
- **`dig` / `nc`** — used by the preflight script for DNS and NTP checks.

## 9. Create your site definition and validate

```bash
make site                 # copies site.example.yaml -> site.yaml (git-ignored)
$EDITOR iac/config/site.yaml
make preflight            # read-only DNS/NTP/tooling checks
make fmt-check            # Terraform formatting (matches CI)
make validate             # terraform init + validate for every stage
```

Once preflight passes and `site.yaml` is complete, proceed to the runbook for
your entry path: [`converge-runbook.md`](converge-runbook.md) if you have no
VCF yet, or [`import-runbook.md`](import-runbook.md) if you are adding a
vCenter to an existing fleet.

## References

- Broadcom TechDocs — [Supported and Not Supported Configurations to Converge](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/converging-your-existing-vsphere-infrastructure-to-a-vcf-or-vvf-platform-/supported-and-not-supported-configurations.html)
- Broadcom TechDocs — [Import an Existing vCenter to Create a Workload Domain](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/building-your-private-cloud-infrastructure/working-with-workload-domains/import-an-existing-vcenter-to-create-a-workload-domain.html)
- See also the design and operations sets: [`../design/`](../design/), [`../operations/`](../operations/).
