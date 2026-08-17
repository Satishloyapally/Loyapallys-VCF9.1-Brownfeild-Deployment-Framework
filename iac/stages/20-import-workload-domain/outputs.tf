output "imported_domain_ids" {
  value       = { for k, m in module.imported_workload_domain : k => m.id }
  description = "Map of imported workload domain name to domain ID."
}

output "imported_domain_status" {
  value       = { for k, m in module.imported_workload_domain : k => m.status }
  description = "Map of imported workload domain name to activation status."
}
