# Creates a NEW VI workload domain in the adopted VCF fleet. Used for
# greenfield-style expansion after the brownfield management domain
# (converge) and any imported vCenters are online.

resource "vcf_domain" "this" {
  name     = var.name
  org_name = var.organization

  vcenter_configuration {
    name            = var.vcenter.name
    fqdn            = var.vcenter.fqdn
    ip_address      = var.vcenter.ip_address
    subnet_mask     = var.vcenter.subnet_mask
    gateway         = var.vcenter.gateway
    datacenter_name = var.vcenter.datacenter_name
    root_password   = var.vcenter.root_password
    vm_size         = var.vcenter.vm_size
    storage_size    = var.vcenter.storage_size
  }

  nsx_configuration {
    vip_fqdn                   = var.nsx.vip_fqdn
    vip                        = var.nsx.vip
    form_factor                = var.nsx.form_factor
    nsx_manager_admin_password = var.nsx.admin_password
    nsx_manager_audit_password = var.nsx.audit_password

    dynamic "nsx_manager_node" {
      for_each = var.nsx.managers
      content {
        name        = nsx_manager_node.value.name
        fqdn        = nsx_manager_node.value.fqdn
        ip_address  = nsx_manager_node.value.ip_address
        subnet_mask = nsx_manager_node.value.subnet_mask
        gateway     = nsx_manager_node.value.gateway
      }
    }
  }

  sso {
    domain_name     = var.sso.domain_name
    domain_password = var.sso.domain_password
  }

  cluster {
    name                      = var.cluster.name
    evc_mode                  = var.cluster.evc_mode
    geneve_vlan_id            = var.cluster.geneve_vlan_id
    high_availability_enabled = var.cluster.high_availability_enabled
    cluster_image_id          = var.cluster.cluster_image_id

    dynamic "host" {
      for_each = var.cluster.hosts
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
      for_each = var.cluster.vds
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
      datastore_name                = var.cluster.vsan.datastore_name
      esa_enabled                   = var.cluster.vsan.esa_enabled
      failures_to_tolerate          = var.cluster.vsan.failures_to_tolerate
      dedup_and_compression_enabled = var.cluster.vsan.dedup_and_compression_enabled
    }
  }
}

output "id" {
  value       = vcf_domain.this.id
  description = "New workload domain ID."
}

output "name" {
  value       = vcf_domain.this.name
  description = "New workload domain name."
}
