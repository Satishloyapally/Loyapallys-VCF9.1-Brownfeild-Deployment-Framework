output "workload_domain_id" {
  value       = module.workload_domain.id
  description = "ID of the new VI workload domain."
}

output "workload_domain_name" {
  value       = module.workload_domain.name
  description = "Name of the new VI workload domain."
}
