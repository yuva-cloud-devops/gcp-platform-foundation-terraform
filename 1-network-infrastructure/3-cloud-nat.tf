module "nat" {
  for_each = {
    for nat in try(local.config.network.nat, []) :
    nat.name => nat
  }

  source  = "terraform-google-modules/cloud-nat/google"
  version = "~> 7.1.0"

  # Basic Configurations:
  project_id = local.config.project_id
  region     = each.value.region

  # CLoud Router & VPC Configurations:
  router = module.cloud_router[each.value.router_name].router.name
  name   = "${each.value.name}-${var.environment}"

  # NAT Configurations:
  source_subnetwork_ip_ranges_to_nat  = try(each.value.source_subnetwork_ip_ranges_to_nat, "ALL_SUBNETWORKS_ALL_IP_RANGES") # NAT subnet scope
  min_ports_per_vm                    = try(each.value.min_ports_per_vm, 64)                                                # Minimum NAT ports
  max_ports_per_vm                    = try(each.value.max_ports_per_vm, 2048)                                              # Maximum NAT ports
  enable_endpoint_independent_mapping = try(each.value.enable_endpoint_independent_mapping, true)                           # Reuse NAT mappings
}
