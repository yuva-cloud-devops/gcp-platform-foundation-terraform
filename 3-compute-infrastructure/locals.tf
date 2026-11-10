# ------------------------------------------------------------------------------
# Local Values & Dynamic YAML Normalization
# ------------------------------------------------------------------------------
locals {
  # Load environment-specific YAML configuration
  config = yamldecode(
    file("${path.root}/../environments/${var.environment}/compute.yaml")
  )

  project_id   = local.config.project_id
  region       = local.config.region
  state_bucket = try(local.config.state_bucket, "gcp-remote-backend-tfstate-management-bucket")

  # Common Key-Value Identification Tags / Labels
  common_tags = merge(
    {
      provisioned_by = "terraform"
      environment    = var.environment
      project        = "gcp-platform-foundation-terraform"
    },
    try(local.config.tags, {})
  )

  # Upstream outputs from 1-network and 2-security
  remote_subnets   = try(data.terraform_remote_state.network.outputs.subnets, {})
  remote_sa_emails = try(data.terraform_remote_state.security.outputs.service_account_emails, {})

  # Shared Instance Template block from YAML
  common_tpl = try(local.config.compute.instance_template, {})

  # Normalize and safeguard all MIG definitions into a resilient map
  migs = {
    for mig in try(local.config.compute.migs, []) :
    mig.name => {
      mig_name = "${mig.name}-${var.environment}"
      hostname = "${mig.name}-${var.environment}"
      region   = try(mig.region, local.region)
      labels   = merge(local.common_tags, try(mig.labels, {}))

      # 1. Instance Template settings (Inherits from shared compute.instance_template)
      template = {
        name_prefix          = "${try(local.common_tpl.name_prefix, "mig-tpl")}-${mig.name}-${var.environment}"
        machine_type         = try(local.common_tpl.machine_type, "e2-medium")
        disk_size_gb         = tostring(try(local.common_tpl.disk_size_gb, 10))
        disk_type            = try(local.common_tpl.disk_type, "pd-balanced")
        auto_delete          = tostring(try(local.common_tpl.auto_delete, true))
        source_image         = try(local.common_tpl.source_image, "")
        source_image_family  = try(local.common_tpl.source_image_family, "mig-test-app")
        source_image_project = try(local.common_tpl.source_image_project, local.project_id)
        nic_type             = try(local.common_tpl.nic_type, "GVNIC")
        startup_script       = try(local.common_tpl.startup_script, "")
        tags                 = distinct(try(local.common_tpl.tags, []))
        metadata             = try(local.common_tpl.metadata, {})
        enable_shielded_vm   = try(local.common_tpl.enable_shielded_vm, true)
        shielded_instance_config = {
          enable_secure_boot          = try(local.common_tpl.shielded_instance_config.enable_secure_boot, true)
          enable_vtpm                 = try(local.common_tpl.shielded_instance_config.enable_vtpm, true)
          enable_integrity_monitoring = try(local.common_tpl.shielded_instance_config.enable_integrity_monitoring, true)
        }

        # Resolve regional subnet self_link from 1-network remote state
        subnetwork = try(
          local.remote_subnets["${try(mig.region, local.region)}/${mig.subnet_name}-${var.environment}"].self_link,
          "${mig.subnet_name}-${var.environment}"
        )

        # Resolve Service Account email from 2-security remote state
        service_account = {
          email  = try(local.remote_sa_emails[local.common_tpl.service_account_name], local.common_tpl.service_account_email, null)
          scopes = try(local.common_tpl.scopes, ["cloud-platform"])
        }
      }

      # 2. Named Ports for Load Balancer attachment
      named_ports = [
        for np in try(mig.named_ports, []) : {
          name = np.name
          port = tonumber(np.port)
        }
      ]

      # 3. Autoscaling settings (target_size must be null when autoscaling is enabled)
      autoscaling_enabled = tostring(try(mig.autoscaling.enabled, false))
      target_size         = try(mig.autoscaling.enabled, false) ? null : try(mig.target_size, 2)
      min_replicas        = try(mig.autoscaling.min_replicas, 2)
      max_replicas        = try(mig.autoscaling.max_replicas, 5)
      cooldown_period     = try(mig.autoscaling.cooldown_period, 60)
      autoscaling_cpu = try(mig.autoscaling.cpu_target, null) != null ? [
        {
          target            = tonumber(mig.autoscaling.cpu_target)
          predictive_method = try(mig.autoscaling.predictive_method, "NONE")
        }
      ] : []

      # 4. Auto-healing Health Check (all 13 fields required by v13.2.4 submodule)
      health_check = {
        type                = try(mig.health_check.type, "http")
        initial_delay_sec   = try(mig.health_check.initial_delay_sec, 30)
        check_interval_sec  = try(mig.health_check.check_interval_sec, 10)
        healthy_threshold   = try(mig.health_check.healthy_threshold, 2)
        timeout_sec         = try(mig.health_check.timeout_sec, 5)
        unhealthy_threshold = try(mig.health_check.unhealthy_threshold, 3)
        response            = try(mig.health_check.response, "")
        proxy_header        = try(mig.health_check.proxy_header, "NONE")
        port                = try(mig.health_check.port, 8080)
        request             = try(mig.health_check.request, "")
        request_path        = try(mig.health_check.request_path, "/")
        host                = try(mig.health_check.host, "")
        enable_logging      = try(mig.health_check.enable_logging, true)
      }

      # 5. Rolling Update Policy
      update_policy = try(mig.update_policy, null) != null ? [
        {
          type                           = try(mig.update_policy.type, "PROACTIVE")
          minimal_action                 = try(mig.update_policy.minimal_action, "REPLACE")
          replacement_method             = try(mig.update_policy.replacement_method, "SUBSTITUTE")
          max_surge_fixed                = try(mig.update_policy.max_surge_fixed, 3)
          max_surge_percent              = try(mig.update_policy.max_surge_percent, null)
          max_unavailable_fixed          = try(mig.update_policy.max_unavailable_fixed, 0)
          max_unavailable_percent        = try(mig.update_policy.max_unavailable_percent, null)
          min_ready_sec                  = try(mig.update_policy.min_ready_sec, 30)
          instance_redistribution_type   = try(mig.update_policy.instance_redistribution_type, "PROACTIVE")
          most_disruptive_allowed_action = try(mig.update_policy.most_disruptive_allowed_action, null)
        }
      ] : []
    }
  }
}
