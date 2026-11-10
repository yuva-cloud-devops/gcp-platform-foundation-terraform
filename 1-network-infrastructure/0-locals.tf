locals {

  # Load environment-specific YAML configuration
  config = yamldecode(
    file("${path.root}/../environments/${var.environment}/network.yaml")
  )

  # Common Key-Value Identification Tags / Labels
  common_tags = merge(
    {
      provisioned_by = "terraform"
      environment    = var.environment
      project        = "gcp-platform-foundation-terraform"
    },
    try(local.config.tags, {})
  )

  # Formatted Tag String for GCP Network Resources (VPC, Subnet, Firewall, Router descriptions)
  tag_description = join(", ", [for k, v in local.common_tags : "${k}:${v}"])

  # Subnets naming & tag description Configurations:
  subnets = [
    for subnet in try(local.config.network.vpc.subnets, []) :
    merge(
      subnet,
      {
        subnet_name = "${subnet.subnet_name}-${var.environment}"
        description = try(subnet.description, local.tag_description)
      }
    )
  ]

  # Firewall Configuration for inbound rules:
  ingress_rules = [
    for rule in try(local.config.network.vpc.firewall_rules.ingress, []) : {
      name          = "${rule.name}-${var.environment}"
      description   = try(rule.description, local.tag_description)
      source_ranges = rule.source_ranges
      target_tags   = try(rule.target_tags, null)
      allow = [
        {
          protocol = "tcp"
          ports    = rule.ports
        }
      ]
    }
  ]

  # Firewall Configuration for outbound rules:
  egress_rules = [
    for rule in try(local.config.network.vpc.firewall_rules.egress, []) : {
      name               = "${rule.name}-${var.environment}"
      description        = try(rule.description, local.tag_description)
      destination_ranges = rule.destination_ranges
      target_tags        = try(rule.target_tags, null)
      allow = [
        {
          protocol = "tcp"
          ports    = rule.ports
        }
      ]
    }
  ]

}
