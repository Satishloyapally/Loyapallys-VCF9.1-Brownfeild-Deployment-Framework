# =====================================================================
# Stage 30 -- Network pools (fleet expansion)
# =====================================================================
# Creates network pools (vSAN, vMotion, ...) that ESX hosts are
# commissioned into. A host is always commissioned INTO a pool, so this
# stage runs BEFORE stage 40 (host commissioning). See
# docs/deployment/architecture.md.
# =====================================================================

module "network_pool" {
  source   = "../../modules/network-pool"
  for_each = { for p in try(local.site.network_pools, []) : p.name => p }

  name = each.value.name
  networks = [
    for n in each.value.networks : {
      type    = n.type
      vlan_id = n.vlan_id
      mtu     = try(n.mtu, 9000)
      subnet  = n.subnet
      mask    = n.mask
      gateway = n.gateway
      ip_pool = {
        start = n.ip_pool.start
        end   = n.ip_pool.end
      }
    }
  ]
}
