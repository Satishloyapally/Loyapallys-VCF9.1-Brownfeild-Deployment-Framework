variable "name" {
  type        = string
  description = "Workload domain name."
}

variable "organization" {
  type        = string
  default     = null
  description = "Optional organization name for the domain."
}

variable "vcenter" {
  description = "vCenter appliance configuration for the new workload domain."
  type = object({
    name            = string
    fqdn            = string
    ip_address      = string
    subnet_mask     = string
    gateway         = string
    datacenter_name = string
    root_password   = string
    vm_size         = optional(string)
    storage_size    = optional(string)
  })
}

variable "nsx" {
  description = "NSX Manager cluster configuration for the new workload domain."
  type = object({
    vip_fqdn       = string
    vip            = string
    form_factor    = optional(string, "medium")
    admin_password = string
    audit_password = optional(string)
    managers = list(object({
      name        = string
      fqdn        = string
      ip_address  = string
      subnet_mask = string
      gateway     = string
    }))
  })
}

variable "sso" {
  description = "SSO domain settings."
  type = object({
    domain_name     = string
    domain_password = string
  })
}

variable "cluster" {
  description = "First cluster for the workload domain (vSAN ESA by default in VCF 9.1)."
  type = object({
    name                      = string
    evc_mode                  = optional(string, "")
    geneve_vlan_id            = optional(number)
    high_availability_enabled = optional(bool, true)
    cluster_image_id          = optional(string)
    hosts = list(object({
      id             = string
      host_name      = optional(string)
      ip_address     = optional(string)
      username       = optional(string)
      password       = optional(string)
      serial_number  = optional(string)
      ssh_thumbprint = optional(string)
    }))
    vds = list(object({
      name           = string
      is_used_by_nsx = optional(bool, false)
      portgroups = list(object({
        name           = string
        transport_type = string
        active_uplinks = optional(list(string))
      }))
    }))
    vsan = object({
      datastore_name                = string
      esa_enabled                   = optional(bool, true)
      failures_to_tolerate          = optional(number, 1)
      dedup_and_compression_enabled = optional(bool, false)
    })
  })
}
