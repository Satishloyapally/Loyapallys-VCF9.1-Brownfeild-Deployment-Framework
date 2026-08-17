# 05 — NSX Coexistence

This document covers the NSX design considerations for brownfield onboarding
into **VMware Cloud Foundation 9.1** and for the edge/Supervisor expansion that
follows.

## NSX Manager cluster requirement

If NSX is present, it must be a **3-node NSX Manager cluster**. This is the only
supported NSX setup for VCF workload domains, and it applies whether the
managers live in the imported workload domain or the management domain (see the
placement flexibility in [04-domain-mapping.md](./04-domain-mapping.md)).
Minimum NSX version for converge and import is **4.2 or later**.

## Existing NSX on converge

When you converge a standalone estate that already runs NSX, the existing NSX is
**trusted and registered** into the new management domain rather than
redeployed. The 3-node manager cluster requirement still holds. After the gate,
NSX inventory is visible to the adopted domain.

## DFW activation on import (the DPG surprise)

Importing an existing vCenter **activates NSX on the cluster's distributed port
groups**. As a direct consequence, the **NSX Distributed Firewall (DFW)**
switches **on** across every running workload on those clusters.

Design implications:

- Treat DFW as **default-on** immediately after import. Without an explicit
  allow policy, east-west traffic is subject to the default DFW rule set.
- Prepare DFW policy (or a permissive baseline you intend to tighten) **before**
  importing, and validate application connectivity right after.
- Communicate the change to workload and security owners; this is a
  fleet-visible security posture change, not just an inventory change.

See [07-security-and-identity.md](./07-security-and-identity.md) for the
security-side treatment of default-on DFW.

## Tier-0 / Tier-1 and dynamic routing

North-south connectivity for workload domains rides an NSX **edge cluster** that
hosts the **Tier-0** and **Tier-1** gateways:

- **Tier-0** peers with the physical fabric using **eBGP** and uses **ECMP** for
  multi-path north-south forwarding.
- **Tier-1** provides the per-tenant/segment routing that connects down to
  workload segments and up to the Tier-0.

The expansion edge cluster is defined in the `edge_cluster` block of
[`iac/config/site.example.yaml`](../../iac/config/site.example.yaml) and built
by [`../../iac/stages/60-edge-cluster`](../../iac/stages/60-edge-cluster) via
the [`edge-cluster`](../../iac/modules/edge-cluster) module. Key design inputs:

| Setting | Example value | Purpose |
| --- | --- | --- |
| `routing_type` | `EBGP` | Tier-0 dynamic routing to the fabric |
| `high_availability` | `ACTIVE_ACTIVE` | ECMP-capable Tier-0 |
| `asn` | `65001` | Local BGP ASN |
| `edge_nodes[].uplinks[].bgp_peer_asn` | `65000` | Upstream peer ASN |
| `mtu` | `9000` | Jumbo frames for overlay/TEP |
| `tep_vlan` / `tep1_ip` / `tep2_ip` | `1636` / `172.16.36.x` | Edge TEP addressing |

## Edge-before-Supervisor ordering

An **edge cluster must be deployed before a Supervisor**, because Supervisor
ingress and egress ride the **Tier-0** gateway. The stage numbering enforces
this: [`60-edge-cluster`](../../iac/stages/60-edge-cluster) runs before
[`70-supervisor`](../../iac/stages/70-supervisor). The Supervisor's
`edge_cluster_id`, `ingress_cidr`, and `egress_cidr` (in the `supervisor` block)
depend on the Tier-0 being in place.

Likewise, a **network pool is created before hosts are commissioned**
([`30-network-pools`](../../iac/stages/30-network-pools) before
[`40-host-commission`](../../iac/stages/40-host-commission)), so host TEP/vSAN/
vMotion addressing exists when a cluster is formed.

## References

- [Import an Existing vCenter to Create a Workload Domain](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/building-your-private-cloud-infrastructure/working-with-workload-domains/import-an-existing-vcenter-to-create-a-workload-domain.html)
- Broadcom TechDocs, VMware Cloud Foundation 9.1
