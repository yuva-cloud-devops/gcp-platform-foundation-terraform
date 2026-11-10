# ------------------------------------------------------------------------------
# 1. Global Load Balancer Core Outputs
# ------------------------------------------------------------------------------
output "load_balancer_name" {
  description = "The deployed name of the Global External Application Load Balancer"
  value       = local.lb.name
}

output "external_ip" {
  description = "The public Global Static IPv4 address assigned to the Load Balancer"
  value       = module.load_balancer.external_ip
}

output "load_balancer_url" {
  description = "The public HTTP URL to access the application globally"
  value       = "http://${module.load_balancer.external_ip}"
}

output "http_proxy" {
  description = "The Target HTTP Proxy self-link created by the Load Balancer"
  value       = module.load_balancer.http_proxy
}

output "url_map" {
  description = "The URL Map self-link routing requests to the backend service"
  value       = module.load_balancer.url_map
}

output "backend_service_self_link" {
  description = "The Global Backend Service self-link attached to the Regional MIGs"
  value       = nonsensitive(try(module.load_balancer.backend_services["default"].self_link, null))
}

output "attached_mig_backends" {
  description = "List of Regional MIG instance group URLs attached as backends"
  value       = [for g in local.lb.backend.groups : g.group]
}

# ------------------------------------------------------------------------------
# 2. Live Verification & Failover Testing Commands
# ------------------------------------------------------------------------------
output "test_load_balancer_curl" {
  description = "Run this command to test live traffic routing through the Global Load Balancer"
  value       = "curl -i http://${module.load_balancer.external_ip}"
}

output "test_backend_health_gcloud" {
  description = "Run this gcloud command to verify backend health status across Mumbai and Singapore MIGs"
  value       = "gcloud compute backend-services get-health ${local.lb.name}-backend-default --global --project=${local.project_id}"
}
