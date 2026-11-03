# VPC Outputs:
output "network_name" {
  description = "VPC network name"
  value = try(
    module.vpc[0].network_name,
    null
  )
}

output "network_id" {
  description = "VPC network ID"
  value = try(
    module.vpc[0].network_id,
    null
  )
}

output "network_self_link" {
  description = "VPC self link"
  value = try(
    module.vpc[0].network_self_link,
    null
  )
}


# Subnet Outputs:
output "subnets" {
  description = "Subnet details"
  value = try(
    module.vpc[0].subnets,
    {}
  )
}

output "subnet_names" {
  description = "Subnet names"
  value = try(
    module.vpc[0].subnets_names,
    []
  )
}

output "subnet_ids" {
  description = "Subnet IDs"
  value = try(
    module.vpc[0].subnets_ids,
    []
  )
}

output "subnet_self_links" {
  description = "Subnet self links"
  value = try(
    module.vpc[0].subnets_self_links,
    []
  )
}

output "subnet_cidrs" {
  description = "Subnet CIDRs"
  value = try(
    module.vpc[0].subnets_ips,
    []
  )
}


# Cloud Router Outputs:
output "router_names" {
  description = "Cloud Router names"
  value = {
    for name, router in module.cloud_router :
    name => router.router.name
  }
}

output "router_self_links" {
  description = "Cloud Router self links"
  value = {
    for name, router in module.cloud_router :
    name => router.router.self_link
  }
}


# Cloud NAT Outputs
output "nat_names" {
  description = "Cloud NAT names"
  value = {
    for name, nat in module.nat :
    name => nat.name
  }
}


# Secondary Ranges
output "secondary_ranges" {
  description = "Subnet secondary ranges"
  value = try(
    module.vpc[0].subnets_secondary_ranges,
    {}
  )
}


# Routes
output "route_names" {
  description = "VPC route names"
  value = try(
    module.vpc[0].route_names,
    []
  )
}
