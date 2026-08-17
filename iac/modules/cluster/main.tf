# Adds an additional cluster to an EXISTING (adopted, converged, or
# imported) workload domain. Requires at least two hosts already
# commissioned into SDDC Manager inventory.

variable "domain_id" {
  type        = string
  description = "ID of the domain to add the cluster to (from adopt-domain)."
}

variable "name" {
  type        = string
  description = "Cluster name."
}

variable "evc_mode" {
  type    = string
  default = ""
}

variable "high_availability_enabled" {
  type    = bool
  default = true
}

variable "cluster_image_id" {
  type    = string
  default = null
}

variable "hosts" {
  description = "Hosts (minimum 2) to place in the cluster."
  type = list(object({
    id             = string
    host_name      = optional(string)
    ip_address     = optional(string)
    username       = optional(string)
    password       = optional(string)
    serial_number  = optional(string)
    ssh_thumbprint = optional(string)
  }))
}

variable "vds" {
  description = "Distributed switches for the cluster."
  type = list(object({
    name           = string
    is_used_by_nsx = optional(bool, false)
    portgroups = list(object({
      name           = string
      transport_type = string
      active_uplinks = optional(list(string))
    }))
  }))
}

variable "vsan" {
  description = "vSAN ESA datastore settings."
  type = object({
    datastore_name                = string
    esa_enabled                   = optional(bool, true)
    failures_to_tolerate          = optional(number, 1)
    dedup_and_compression_enabled = optional(bool, false)
  })
}

resource "vcf_cluster" "this" {
  domain_id                 = var.domain_id
  name                      = var.name
  evc_mode                  = var.evc_mode
  high_availability_enabled = var.high_availability_enabled
  cluster_image_id          = var.cluster_image_id

  dynamic "host" {
    for_each = var.hosts
    content {
      id             = host.value.id
      host_name      = host.value.host_name
      ip_address     = host.value.ip_address
      username       = host.value.username
      password       = host.value.password
      serial_number  = host.value.serial_number
      ssh_thumbprint = host.value.ssh_thumbprint
    }
  }

  dynamic "vds" {
    for_each = var.vds
    content {
      name           = vds.value.name
      is_used_by_nsx = vds.value.is_used_by_nsx

      dynamic "portgroup" {
        for_each = vds.value.portgroups
        content {
          name           = portgroup.value.name
          transport_type = portgroup.value.transport_type
          active_uplinks = portgroup.value.active_uplinks
        }
      }
    }
  }

  vsan_datastore {
    datastore_name                = var.vsan.datastore_name
    esa_enabled                   = var.vsan.esa_enabled
    failures_to_tolerate          = var.vsan.failures_to_tolerate
    dedup_and_compression_enabled = var.vsan.dedup_and_compression_enabled
  }
}

output "id" {
  value       = vcf_cluster.this.id
  description = "Cluster ID."
}
