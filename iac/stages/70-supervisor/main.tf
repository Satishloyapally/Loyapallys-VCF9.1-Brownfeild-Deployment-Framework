# =====================================================================
# Stage 70 -- vSphere Supervisor (fleet expansion)
# =====================================================================
# Activates a vSphere Supervisor (vSphere IaaS / Tanzu) on a workload
# cluster. Runs LAST, after the NSX Edge cluster, because Supervisor
# ingress/egress rides the Tier-0. See docs/design/06-supervisor.md-style
# guidance in docs/deployment/architecture.md.
# =====================================================================

locals {
  sv = local.site.supervisor
}

module "supervisor" {
  source = "../../modules/supervisor"

  cluster_id         = local.sv.cluster_id
  storage_policy     = local.sv.storage_policy
  content_library_id = local.sv.content_library_id
  edge_cluster_id    = local.sv.edge_cluster_id
  dvs_uuid           = local.sv.dvs_uuid
  sizing_hint        = try(local.sv.sizing_hint, "SMALL")

  dns_servers    = local.site.infra.dns_servers
  ntp_servers    = local.site.infra.ntp_servers
  search_domains = [local.site.infra.dns_domain]

  management_network = {
    network          = local.sv.management_network.network
    starting_address = local.sv.management_network.starting_address
    subnet_mask      = local.sv.management_network.subnet_mask
    gateway          = local.sv.management_network.gateway
    address_count    = local.sv.management_network.address_count
  }

  ingress_cidr = {
    address = local.sv.ingress_cidr.address
    prefix  = local.sv.ingress_cidr.prefix
  }

  egress_cidr = {
    address = local.sv.egress_cidr.address
    prefix  = local.sv.egress_cidr.prefix
  }

  pod_cidr = {
    address = local.sv.pod_cidr.address
    prefix  = local.sv.pod_cidr.prefix
  }

  service_cidr = {
    address = local.sv.service_cidr.address
    prefix  = local.sv.service_cidr.prefix
  }

  namespace_name = try(local.sv.namespace.name, null)
}
