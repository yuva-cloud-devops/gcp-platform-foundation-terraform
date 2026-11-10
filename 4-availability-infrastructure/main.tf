# ------------------------------------------------------------------------------
# Global External Application Load Balancer (HTTP/S)
# Connects Multi-Region MIG Backends (Mumbai & Singapore)
# ------------------------------------------------------------------------------
module "load_balancer" {
  source  = "terraform-google-modules/lb-http/google"
  version = "~> 12.0"

  project               = local.project_id
  name                  = local.lb.name
  load_balancing_scheme = local.lb.load_balancing_scheme
  labels                = local.lb.labels

  # External Static IP & Protocol Forwarding
  create_address = local.lb.create_address
  http_forward   = local.lb.http_forward
  ssl            = local.lb.ssl
  https_redirect = local.lb.https_redirect

  # Disable auto-firewall rules (already managed in 1-network-infrastructure)
  firewall_networks = []

  # Global Backend Service Configuration
  backends = {
    default = local.lb.backend
  }
}
