output "commissioned_host_ids" {
  value       = module.hosts.host_ids
  description = "Map of host FQDN to commissioned host ID."
}
