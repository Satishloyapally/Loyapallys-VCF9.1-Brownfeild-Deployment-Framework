# =====================================================================
# Stage 60 -- NSX Edge cluster (fleet expansion)
# =====================================================================
# Deploys a Tier-0/Tier-1 NSX Edge cluster with eBGP/ECMP uplinks. This
# runs BEFORE the Supervisor (stage 70) because the Supervisor's
# ingress/egress ranges are advertised through the Tier-0. See
# docs/design/05-nsx-coexistence.md.
# =====================================================================

locals {
  ec = local.site.edge_cluster
}

module "edge_cluster" {
  source = "../../modules/edge-cluster"

  name              = local.ec.name
  mtu               = local.ec.mtu
  asn               = try(local.ec.asn, null)
  tier0_name        = try(local.ec.tier0_name, null)
  tier1_name        = try(local.ec.tier1_name, null)
  form_factor       = try(local.ec.form_factor, "MEDIUM")
  profile_type      = try(local.ec.profile_type, "DEFAULT")
  routing_type      = try(local.ec.routing_type, "EBGP")
  high_availability = try(local.ec.high_availability, "ACTIVE_ACTIVE")
  admin_password    = var.edge_admin_password
  audit_password    = var.edge_audit_password
  root_password     = var.edge_root_password

  edge_nodes = [
    for n in local.ec.edge_nodes : {
      name                 = n.name
      compute_cluster_name = try(n.compute_cluster_name, null)
      compute_cluster_id   = try(n.compute_cluster_id, null)
      management_ip        = n.management_ip
      management_gateway   = n.management_gateway
      management_portgroup = n.management_portgroup
      management_vlan_id   = n.management_vlan_id
      tep_gateway          = n.tep_gateway
      tep_vlan             = n.tep_vlan
      tep1_ip              = n.tep1_ip
      tep2_ip              = n.tep2_ip
      inter_rack_cluster   = try(n.inter_rack_cluster, false)
      uplinks = [
        for u in n.uplinks : {
          interface_ip      = u.interface_ip
          vlan              = u.vlan
          bgp_peer_ip       = u.bgp_peer_ip
          bgp_peer_asn      = u.bgp_peer_asn
          bgp_peer_password = var.bgp_peer_password
        }
      ]
    }
  ]
}
