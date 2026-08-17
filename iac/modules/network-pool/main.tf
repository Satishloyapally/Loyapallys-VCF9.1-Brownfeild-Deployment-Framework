# Creates a VCF network pool used when commissioning ESX hosts into a
# workload domain. Network pools carry the vSAN and vMotion (and any
# additional) VLAN/subnet/IP-range definitions.

variable "name" {
  type        = string
  description = "Network pool name."
}

variable "networks" {
  description = "List of networks (vSAN, vMotion, etc.) in this pool."
  type = list(object({
    type    = string
    vlan_id = number
    mtu     = optional(number, 9000)
    subnet  = string
    mask    = string
    gateway = string
    ip_pool = object({
      start = string
      end   = string
    })
  }))
}

resource "vcf_network_pool" "this" {
  name = var.name

  dynamic "network" {
    for_each = var.networks
    content {
      type    = network.value.type
      vlan_id = network.value.vlan_id
      mtu     = network.value.mtu
      subnet  = network.value.subnet
      mask    = network.value.mask
      gateway = network.value.gateway

      ip_pools {
        start = network.value.ip_pool.start
        end   = network.value.ip_pool.end
      }
    }
  }
}

output "id" {
  value       = vcf_network_pool.this.id
  description = "Network pool ID."
}

output "name" {
  value       = vcf_network_pool.this.name
  description = "Network pool name."
}
