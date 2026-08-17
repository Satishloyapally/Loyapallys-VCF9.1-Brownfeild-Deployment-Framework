# =====================================================================
# Stage 10 -- Converge (adopt the management domain)
# =====================================================================
# BROWNFIELD GATE (manual, in the VCF Installer):
#   Convergence turns your existing standalone vSphere environment into
#   your FIRST VCF 9.1 management domain. It is performed in the VCF
#   Installer UI (Converge to VCF), NOT by Terraform -- the vmware/vcf
#   provider has no converge resource. See docs/deployment/converge-runbook.md.
#
# This stage runs AFTER convergence completes and simply ADOPTS the
# resulting management domain (read-only) so downstream stages can
# reference its ID. See docs/deployment/converge-runbook.md.
# =====================================================================

module "management_domain" {
  source      = "../../modules/adopt-domain"
  domain_name = local.site.adoption.management_domain_name
}
