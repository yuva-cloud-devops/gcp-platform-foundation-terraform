# Creates VPC, subnets, routes, and firewall rules
module "vpc" {
  # Only create if VPC configuration is provided
  count = try(var.network.vpc, null) != null ? 1 : 0

  source  = "terraform-google-modules/network/google"
  version = "~> 18.3"

  # Project Detials:
  project_id = var.project_id

  # VPC Configurations:
  network_name = var.network.vpc.network_name
  routing_mode = try(var.network.vpc.routing_mode, "GLOBAL")

  # Subnet Configurations:
  auto_create_subnetworks = try(var.network.vpc.auto_create_subnetworks, false)
  subnets                 = try(var.network.vpc.subnets, [])
  routes                  = try(var.network.vpc.routes, [])

  # Firewall Rules:
  ingress_rules = local.ingress_rules
  egress_rules  = local.egress_rules

  # Secondary CIDR & IGW Configurations:
  secondary_ranges                       = try(var.network.vpc.secondary_ranges, {})
  delete_default_internet_gateway_routes = try(var.network.vpc.delete_default_routes, false)
}
