# Activates a vSphere Supervisor (vSphere IaaS / Tanzu) on a workload
# cluster. Deployed AFTER the NSX Edge cluster because the Supervisor
# ingress/egress ranges are advertised through the Tier-0.

variable "cluster_id" {
  type        = string
  description = "Managed object ID of the target vSphere cluster."
}

variable "storage_policy" {
  type        = string
  description = "Storage policy for control-plane VMs."
}

variable "content_library_id" {
  type        = string
  description = "Subscribed content library ID for Tanzu Kubernetes releases."
}

variable "edge_cluster_id" {
  type        = string
  description = "NSX Edge cluster ID that carries Supervisor ingress/egress."
}

variable "dvs_uuid" {
  type        = string
  description = "UUID of the distributed switch used by the Supervisor."
}

variable "sizing_hint" {
  type        = string
  default     = "SMALL"
  description = "Control-plane sizing (TINY, SMALL, MEDIUM, LARGE)."
}

variable "dns_servers" {
  type = list(string)
}

variable "ntp_servers" {
  type = list(string)
}

variable "search_domains" {
  type = list(string)
}

variable "management_network" {
  type = object({
    network          = string
    starting_address = string
    subnet_mask      = string
    gateway          = string
    address_count    = number
  })
}

variable "ingress_cidr" {
  type = object({
    address = string
    prefix  = number
  })
}

variable "egress_cidr" {
  type = object({
    address = string
    prefix  = number
  })
}

variable "pod_cidr" {
  type = object({
    address = string
    prefix  = number
  })
}

variable "service_cidr" {
  type = object({
    address = string
    prefix  = number
  })
}

variable "namespace_name" {
  type    = string
  default = null
}

resource "vsphere_supervisor" "this" {
  cluster         = var.cluster_id
  storage_policy  = var.storage_policy
  content_library = var.content_library_id
  edge_cluster    = var.edge_cluster_id
  dvs_uuid        = var.dvs_uuid
  sizing_hint     = var.sizing_hint

  main_dns       = var.dns_servers
  worker_dns     = var.dns_servers
  main_ntp       = var.ntp_servers
  worker_ntp     = var.ntp_servers
  search_domains = var.search_domains

  management_network {
    network          = var.management_network.network
    starting_address = var.management_network.starting_address
    subnet_mask      = var.management_network.subnet_mask
    gateway          = var.management_network.gateway
    address_count    = var.management_network.address_count
  }

  ingress_cidr {
    address = var.ingress_cidr.address
    prefix  = var.ingress_cidr.prefix
  }

  egress_cidr {
    address = var.egress_cidr.address
    prefix  = var.egress_cidr.prefix
  }

  pod_cidr {
    address = var.pod_cidr.address
    prefix  = var.pod_cidr.prefix
  }

  service_cidr {
    address = var.service_cidr.address
    prefix  = var.service_cidr.prefix
  }

  dynamic "namespace" {
    for_each = var.namespace_name == null ? [] : [var.namespace_name]
    content {
      name = namespace.value
    }
  }
}

output "id" {
  value       = vsphere_supervisor.this.id
  description = "Supervisor ID."
}
