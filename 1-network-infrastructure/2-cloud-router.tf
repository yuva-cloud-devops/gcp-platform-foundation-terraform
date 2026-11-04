module "cloud_router" {
  for_each = {
    for router in try(local.config.network.router, []) :
    router.name => router
  }

  source  = "terraform-google-modules/cloud-router/google"
  version = "~> 9.1"

  # Basic Configurations
  name       = "${each.value.name}-${var.environment}"
  region     = each.value.region
  project_id = local.config.project_id

  # VPC Configurations
  network = module.vpc[0].network_name

  # Border Gateway Protocol Configurations
  bgp = each.value.bgp
}
