module "nat" {
  for_each = {
    for nat in try(var.network.nat, []) :
    nat.name => nat
  }

  source  = "terraform-google-modules/cloud-nat/google"
  version = "~> 7.1.0"

  # Basic Configurations:
  project_id = var.project_id
  region     = each.value.region

  # CLoud Router & VPC Configurations:
  router = module.cloud_router[each.value.router_name].router.name
  name   = each.value.name

  # NAT Configurations:
  source_subnetwork_ip_ranges_to_nat  = each.value.source_subnetwork_ip_ranges_to_nat  # NAT subnet scope
  min_ports_per_vm                    = each.value.min_ports_per_vm                    # Minimum NAT ports
  max_ports_per_vm                    = each.value.max_ports_per_vm                    # Maximum NAT ports
  enable_endpoint_independent_mapping = each.value.enable_endpoint_independent_mapping # Reuse NAT mappings
}
