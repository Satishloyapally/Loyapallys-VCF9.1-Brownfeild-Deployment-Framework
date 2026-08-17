variable "vsphere_user" {
  type        = string
  default     = "administrator@vsphere.local"
  description = "vCenter SSO user for the workload domain hosting the Supervisor."
}

variable "vsphere_password" {
  type      = string
  sensitive = true
  default   = ""
}

locals {
  site_file = fileexists("${path.module}/../../config/site.yaml") ? "${path.module}/../../config/site.yaml" : "${path.module}/../../config/site.example.yaml"
  site      = yamldecode(file(local.site_file))
}

provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = local.site.new_workload_domain.vcenter.fqdn
  allow_unverified_ssl = try(local.site.fleet.allow_unverified_tls, false)
}
