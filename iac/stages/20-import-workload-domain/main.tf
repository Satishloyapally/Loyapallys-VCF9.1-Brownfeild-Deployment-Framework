# =====================================================================
# Stage 20 -- Import (adopt imported vCenter workload domains)
# =====================================================================
# BROWNFIELD GATE (manual, in VCF Operations):
#   Importing an existing vCenter is done from VCF Operations
#   (Inventory -> Instance -> Add Workload Domain -> Import a vCenter),
#   NOT from the VCF Installer and NOT via Terraform. Import registers the
#   existing vSphere/vSAN/NSX estate as a VI workload domain and activates
#   NSX on the distributed port groups (enabling the Distributed Firewall).
#   See docs/deployment/import-runbook.md.
#
# The imported domain enters at the effective version of its EARLIEST
# component (e.g. vSphere 8 / NSX 4 -> a VCF 5.x domain), then is upgraded.
#
# This stage runs AFTER import completes and ADOPTS each imported domain
# (read-only) so downstream stages can reference their IDs.
# =====================================================================

module "imported_workload_domain" {
  source   = "../../modules/adopt-domain"
  for_each = { for d in try(local.site.adoption.imported_workload_domains, []) : d.name => d }

  domain_name = each.value.name
}
