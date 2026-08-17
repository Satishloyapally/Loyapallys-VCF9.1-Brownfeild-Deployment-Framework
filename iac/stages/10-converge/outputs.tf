output "management_domain_id" {
  value       = module.management_domain.id
  description = "ID of the converged/adopted management domain."
}

output "management_domain_status" {
  value       = module.management_domain.status
  description = "Activation status of the management domain."
}

output "management_vcenter" {
  value       = module.management_domain.vcenter_configuration
  description = "vCenter details of the management domain."
}
