# Creates Regional Managed Instance Groups (MIG) with Autoscaling & Auto-Healing
module "mig" {
  for_each = local.migs

  source  = "terraform-google-modules/vm/google//modules/mig"
  version = "~> 13.2.4"

  # Project & Identity
  project_id = local.project_id
  region     = each.value.region
  mig_name   = each.value.mig_name
  hostname   = each.value.hostname

  # Link to Instance Template (self_link_unique ensures clean rolling updates)
  instance_template = module.instance_template[each.key].self_link_unique

  # Named Ports for Load Balancer Backend Service
  named_ports = each.value.named_ports

  # Capacity & Autoscaling
  target_size         = each.value.target_size
  autoscaling_enabled = each.value.autoscaling_enabled
  min_replicas        = each.value.min_replicas
  max_replicas        = each.value.max_replicas
  cooldown_period     = each.value.cooldown_period
  autoscaling_cpu     = each.value.autoscaling_cpu

  # Auto-Healing Health Check
  health_check      = each.value.health_check
  health_check_name = "${each.value.mig_name}-hc"

  # Rolling Update Policy
  update_policy = each.value.update_policy
}
