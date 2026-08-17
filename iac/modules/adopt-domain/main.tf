# Adopts an EXISTING VCF domain that was produced by a manual brownfield
# gate (converge -> management domain, or import -> workload domain).
#
# This is a READ-ONLY data lookup: it never proposes to create or destroy
# the domain, so it is always safe to run against a live fleet. Later
# stages consume the exported IDs. If you want to manage the domain object
# in place, import it into a dedicated `vcf_domain` resource in its own
# configuration (see docs/operations/day-2-operations.md).

variable "domain_name" {
  type        = string
  description = "Name of the existing (converged/imported) VCF domain to adopt."
}

data "vcf_domain" "adopted" {
  name = var.domain_name
}

output "id" {
  value       = data.vcf_domain.adopted.id
  description = "Domain ID of the adopted domain."
}

output "type" {
  value       = data.vcf_domain.adopted.type
  description = "Domain type (MANAGEMENT or VI)."
}

output "status" {
  value       = data.vcf_domain.adopted.status
  description = "Domain activation status reported by SDDC Manager."
}

output "vcenter_configuration" {
  value       = data.vcf_domain.adopted.vcenter_configuration
  description = "vCenter details of the adopted domain."
}

output "nsx_configuration" {
  value       = data.vcf_domain.adopted.nsx_configuration
  description = "NSX details of the adopted domain (if NSX is present)."
}

output "clusters" {
  value       = data.vcf_domain.adopted.cluster
  description = "Clusters that belong to the adopted domain."
}
