output "network_pool_ids" {
  value       = { for k, m in module.network_pool : k => m.id }
  description = "Map of network pool name to ID."
}
