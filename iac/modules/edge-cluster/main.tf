# Deploys an NSX Edge cluster (Tier-0 + Tier-1) with eBGP/ECMP uplinks in
# a workload domain. The edge cluster is deployed BEFORE a Supervisor,
# because Supervisor ingress/egress rides the Tier-0.

variable "name" {
  type        = string
  description = "Edge cluster name."
}

variable "mtu" {
  type        = number
  description = "Edge overlay/uplink MTU (>= 1600; 9000 recommended)."
}

variable "asn" {
  type        = number
  default     = null
  description = "Local BGP ASN for the Tier-0."
}

variable "tier0_name" {
  type    = string
  default = null
}

variable "tier1_name" {
  type    = string
  default = null
}

variable "form_factor" {
  type        = string
  default     = "MEDIUM"
  description = "Edge node form factor (SMALL, MEDIUM, LARGE, XLARGE)."
}

variable "profile_type" {
  type    = string
  default = "DEFAULT"
}

variable "routing_type" {
  type    = string
  default = "EBGP"
}

variable "high_availability" {
  type    = string
  default = "ACTIVE_ACTIVE"
}

variable "admin_password" { type = string }
variable "audit_password" { type = string }
variable "root_password" { type = string }

variable "edge_nodes" {
  description = "Edge transport nodes."
  type = list(object({
    name                 = string
    compute_cluster_name = optional(string)
    compute_cluster_id   = optional(string)
    management_ip        = string
    management_gateway   = string
    management_portgroup = string
    management_vlan_id   = number
    tep_gateway          = string
    tep_vlan             = number
    tep1_ip              = string
    tep2_ip              = string
    inter_rack_cluster   = optional(bool, false)
    uplinks = list(object({
      interface_ip      = string
      vlan              = number
      bgp_peer_ip       = string
      bgp_peer_asn      = number
      bgp_peer_password = string
    }))
  }))
}

resource "vcf_edge_cluster" "this" {
  name              = var.name
  mtu               = var.mtu
  asn               = var.asn
  tier0_name        = var.tier0_name
  tier1_name        = var.tier1_name
  form_factor       = var.form_factor
  profile_type      = var.profile_type
  routing_type      = var.routing_type
  high_availability = var.high_availability
  admin_password    = var.admin_password
  audit_password    = var.audit_password
  root_password     = var.root_password

  dynamic "edge_node" {
    for_each = var.edge_nodes
    content {
      name                 = edge_node.value.name
      compute_cluster_name = edge_node.value.compute_cluster_name
      compute_cluster_id   = edge_node.value.compute_cluster_id
      admin_password       = var.admin_password
      audit_password       = var.audit_password
      root_password        = var.root_password
      management_ip        = edge_node.value.management_ip
      management_gateway   = edge_node.value.management_gateway
      tep_gateway          = edge_node.value.tep_gateway
      tep_vlan             = edge_node.value.tep_vlan
      tep1_ip              = edge_node.value.tep1_ip
      tep2_ip              = edge_node.value.tep2_ip
      inter_rack_cluster   = edge_node.value.inter_rack_cluster

      management_network {
        portgroup_name = edge_node.value.management_portgroup
        vlan_id        = edge_node.value.management_vlan_id
      }

      dynamic "uplink" {
        for_each = edge_node.value.uplinks
        content {
          interface_ip = uplink.value.interface_ip
          vlan         = uplink.value.vlan

          bgp_peer {
            ip       = uplink.value.bgp_peer_ip
            asn      = uplink.value.bgp_peer_asn
            password = uplink.value.bgp_peer_password
          }
        }
      }
    }
  }
}

output "id" {
  value       = vcf_edge_cluster.this.id
  description = "Edge cluster ID."
}
