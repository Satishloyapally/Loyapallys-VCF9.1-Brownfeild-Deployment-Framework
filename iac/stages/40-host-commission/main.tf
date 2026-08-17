# =====================================================================
# Stage 40 -- Commission ESX hosts (fleet expansion)
# =====================================================================
# Commissions ESX hosts into SDDC Manager inventory so they can back a new
# workload domain (stage 50) or an additional cluster. Hosts are
# commissioned into a network pool created in stage 30.
#
# NOTE: hosts added to a BROWNFIELD (imported) cluster are added in
# vCenter first and then reconciled via VCF import-sync, not commissioned
# here. See docs/operations/day-2-operations.md.
# =====================================================================

module "hosts" {
  source = "../../modules/host-commission"

  hosts = [
    for h in try(local.site.hosts_to_commission, []) : {
      fqdn              = h.fqdn
      username          = h.username
      password          = var.host_password
      storage_type      = h.storage_type
      network_pool_name = h.network_pool_name
    }
  ]
}
