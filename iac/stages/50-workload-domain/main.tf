# =====================================================================
# Stage 50 -- New VI workload domain (fleet expansion)
# =====================================================================
# Creates a brand-new VI workload domain in the adopted fleet using hosts
# commissioned in stage 40. This is the greenfield-style expansion path
# that complements the brownfield converge/import gates. vSAN ESA is the
# VCF 9.1 default storage. See docs/deployment/architecture.md.
# =====================================================================

locals {
  wld = local.site.new_workload_domain
}

module "workload_domain" {
  source = "../../modules/workload-domain"

  name         = local.wld.name
  organization = try(local.wld.organization, null)

  vcenter = {
    name            = local.wld.vcenter.name
    fqdn            = local.wld.vcenter.fqdn
    ip_address      = local.wld.vcenter.ip_address
    subnet_mask     = local.wld.vcenter.subnet_mask
    gateway         = local.wld.vcenter.gateway
    datacenter_name = local.wld.vcenter.datacenter_name
    root_password   = var.vcenter_root_password
    vm_size         = try(local.wld.vcenter.vm_size, null)
    storage_size    = try(local.wld.vcenter.storage_size, null)
  }

  nsx = {
    vip_fqdn       = local.wld.nsx.vip_fqdn
    vip            = local.wld.nsx.vip
    form_factor    = try(local.wld.nsx.form_factor, "medium")
    admin_password = var.nsx_admin_password
    audit_password = var.nsx_audit_password
    managers = [
      for m in local.wld.nsx.managers : {
        name        = m.name
        fqdn        = m.fqdn
        ip_address  = m.ip_address
        subnet_mask = m.subnet_mask
        gateway     = m.gateway
      }
    ]
  }

  sso = {
    domain_name     = local.wld.sso.domain_name
    domain_password = var.sso_domain_password
  }

  cluster = {
    name                      = local.wld.cluster.name
    evc_mode                  = try(local.wld.cluster.evc_mode, "")
    geneve_vlan_id            = try(local.wld.cluster.geneve_vlan_id, null)
    high_availability_enabled = try(local.wld.cluster.high_availability_enabled, true)
    cluster_image_id          = try(local.wld.cluster.cluster_image_id, null)
    hosts = [
      for h in local.wld.cluster.hosts : {
        id = h.id
      }
    ]
    vds = [
      for v in local.wld.cluster.vds : {
        name           = v.name
        is_used_by_nsx = try(v.is_used_by_nsx, false)
        portgroups = [
          for pg in v.portgroups : {
            name           = pg.name
            transport_type = pg.transport_type
          }
        ]
      }
    ]
    vsan = {
      datastore_name                = local.wld.cluster.vsan.datastore_name
      esa_enabled                   = try(local.wld.cluster.vsan.esa_enabled, true)
      failures_to_tolerate          = try(local.wld.cluster.vsan.failures_to_tolerate, 1)
      dedup_and_compression_enabled = try(local.wld.cluster.vsan.dedup_and_compression_enabled, false)
    }
  }
}
