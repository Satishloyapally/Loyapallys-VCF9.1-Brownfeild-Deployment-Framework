# Commissions ESX hosts into SDDC Manager inventory so they can be
# consumed by a workload domain or added to an existing cluster.

variable "hosts" {
  description = "ESX hosts to commission."
  type = list(object({
    fqdn              = string
    username          = string
    password          = string
    storage_type      = string
    network_pool_name = string
  }))
}

resource "vcf_host" "this" {
  for_each = { for h in var.hosts : h.fqdn => h }

  fqdn              = each.value.fqdn
  username          = each.value.username
  password          = each.value.password
  storage_type      = each.value.storage_type
  network_pool_name = each.value.network_pool_name
}

output "host_ids" {
  value       = { for k, h in vcf_host.this : k => h.id }
  description = "Map of host FQDN to commissioned host ID."
}
