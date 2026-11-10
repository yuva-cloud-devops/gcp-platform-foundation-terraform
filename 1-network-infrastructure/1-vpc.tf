# Creates VPC, subnets, routes, and firewall rules
module "vpc" {
  # Only create if VPC configuration is provided
  count = try(local.config.network.vpc, null) != null ? 1 : 0

  source  = "terraform-google-modules/network/google"
  version = "~> 18.3"

  # Project Detials:
  project_id = local.config.project_id

  # VPC Configurations:
  network_name = "${local.config.network.vpc.network_name}-${var.environment}"
  routing_mode = try(local.config.network.vpc.routing_mode, "GLOBAL")
  description  = local.tag_description

  # Subnet Configurations:
  auto_create_subnetworks = try(local.config.network.vpc.auto_create_subnetworks, false)
  subnets                 = local.subnets
  routes                  = try(local.config.network.vpc.routes, [])

  # Firewall Rules:
  ingress_rules = local.ingress_rules
  egress_rules  = local.egress_rules

  # Secondary CIDR & IGW Configurations:
  secondary_ranges                       = try(local.config.network.vpc.secondary_ranges, {})
  delete_default_internet_gateway_routes = try(local.config.network.vpc.delete_default_routes, false)
}
