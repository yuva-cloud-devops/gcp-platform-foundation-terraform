locals {
  # Firewall Configuration for inbound rules:
  ingress_rules = [
    for rule in try(var.network.vpc.firewall_rules.ingress, []) : {
      name          = rule.name
      source_ranges = rule.source_ranges
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
    for rule in try(var.network.vpc.firewall_rules.egress, []) : {
      name               = rule.name
      destination_ranges = rule.destination_ranges
      allow = [
        {
          protocol = "tcp"
          ports    = rule.ports
        }
      ]
    }
  ]

}
