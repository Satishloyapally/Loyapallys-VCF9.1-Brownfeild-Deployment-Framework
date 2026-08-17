variable "sddc_manager_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "SDDC Manager password (prefer TF_VAR_sddc_manager_password env var)."
}

locals {
  site_file = fileexists("${path.module}/../../config/site.yaml") ? "${path.module}/../../config/site.yaml" : "${path.module}/../../config/site.example.yaml"
  site      = yamldecode(file(local.site_file))
}

provider "vcf" {
  sddc_manager_host     = local.site.fleet.sddc_manager.host
  sddc_manager_username = local.site.fleet.sddc_manager.username
  sddc_manager_password = var.sddc_manager_password
  allow_unverified_tls  = try(local.site.fleet.allow_unverified_tls, false)
}
