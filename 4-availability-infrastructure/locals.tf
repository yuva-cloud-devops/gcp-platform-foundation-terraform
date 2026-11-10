# ------------------------------------------------------------------------------
# Local Values & Dynamic YAML Normalization
# ------------------------------------------------------------------------------
locals {
  # Load environment-specific YAML configuration
  config = yamldecode(
    file("${path.root}/../environments/${var.environment}/availability.yaml")
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

  # Upstream MIG Instance Group URLs from 3-compute-infrastructure
  remote_mig_groups = try(data.terraform_remote_state.compute.outputs.mig_instance_groups, {})

  # Raw Load Balancer YAML block
  lb_raw = try(local.config.availability.load_balancer, {})

  # Resolve which MIGs to attach (uses explicit list from YAML, or defaults to all MIGs from Layer 3)
  target_mig_keys = length(try(local.lb_raw.backend.target_migs, [])) > 0 ? local.lb_raw.backend.target_migs : keys(local.remote_mig_groups)

  # Build backend groups list for Mumbai & Singapore MIGs
  backend_groups = [
    for mig_key in local.target_mig_keys : {
      group                        = local.remote_mig_groups[mig_key]
      description                  = "Regional MIG Backend: ${mig_key}-${var.environment}"
      balancing_mode               = try(local.lb_raw.backend.balancing_mode, "UTILIZATION")
      max_utilization              = try(local.lb_raw.backend.balancing_mode, "UTILIZATION") == "UTILIZATION" ? try(local.lb_raw.backend.max_utilization, 0.8) : null
      capacity_scaler              = try(local.lb_raw.backend.capacity_scaler, 1.0)
      max_rate                     = try(local.lb_raw.backend.max_rate, null)
      max_rate_per_instance        = try(local.lb_raw.backend.balancing_mode, "UTILIZATION") == "RATE" ? try(local.lb_raw.backend.max_rate_per_instance, 10) : null
      max_rate_per_endpoint        = null
      max_connections              = null
      max_connections_per_instance = null
      max_connections_per_endpoint = null
    }
    if contains(keys(local.remote_mig_groups), mig_key)
  ]

  # Normalized Load Balancer Configuration
  lb = {
    name                  = "${try(local.lb_raw.name, "glb-web")}-${var.environment}"
    load_balancing_scheme = try(local.lb_raw.load_balancing_scheme, "EXTERNAL_MANAGED")
    create_address        = try(local.lb_raw.create_address, true)
    http_forward          = try(local.lb_raw.http_forward, true)
    ssl                   = try(local.lb_raw.ssl, false)
    https_redirect        = try(local.lb_raw.https_redirect, false)
    labels                = merge(local.common_tags, try(local.lb_raw.labels, {}))

    backend = {
      description                     = try(local.lb_raw.backend.description, "Global HTTP Backend Service for ${var.environment}")
      protocol                        = try(local.lb_raw.backend.protocol, "HTTP")
      port                            = tonumber(try(local.lb_raw.backend.port, 8080))
      port_name                       = try(local.lb_raw.backend.port_name, "http")
      timeout_sec                     = tonumber(try(local.lb_raw.backend.timeout_sec, 30))
      enable_cdn                      = try(local.lb_raw.backend.enable_cdn, false)
      connection_draining_timeout_sec = tonumber(try(local.lb_raw.backend.connection_draining_timeout_sec, 30))
      session_affinity                = try(local.lb_raw.backend.session_affinity, "NONE")
      locality_lb_policy              = try(local.lb_raw.backend.locality_lb_policy, "ROUND_ROBIN")
      affinity_cookie_ttl_sec         = try(local.lb_raw.backend.affinity_cookie_ttl_sec, null)
      compression_mode                = try(local.lb_raw.backend.compression_mode, "DISABLED")
      security_policy                 = try(local.lb_raw.backend.security_policy, null)
      edge_security_policy            = try(local.lb_raw.backend.edge_security_policy, null)
      custom_request_headers          = try(local.lb_raw.backend.custom_request_headers, [])
      custom_response_headers         = try(local.lb_raw.backend.custom_response_headers, [])

      health_check = {
        request_path        = try(local.lb_raw.backend.health_check.request_path, "/")
        port                = tonumber(try(local.lb_raw.backend.health_check.port, 8080))
        check_interval_sec  = tonumber(try(local.lb_raw.backend.health_check.check_interval_sec, 10))
        timeout_sec         = tonumber(try(local.lb_raw.backend.health_check.timeout_sec, 5))
        healthy_threshold   = tonumber(try(local.lb_raw.backend.health_check.healthy_threshold, 2))
        unhealthy_threshold = tonumber(try(local.lb_raw.backend.health_check.unhealthy_threshold, 3))
        host                = try(local.lb_raw.backend.health_check.host, null)
        logging             = try(local.lb_raw.backend.health_check.logging, true)
      }

      log_config = {
        enable      = try(local.lb_raw.backend.log_config.enable, true)
        sample_rate = tonumber(try(local.lb_raw.backend.log_config.sample_rate, 1.0))
      }

      iap_config = {
        enable               = try(local.lb_raw.backend.iap_config.enable, false)
        oauth2_client_id     = try(local.lb_raw.backend.iap_config.oauth2_client_id, null)
        oauth2_client_secret = try(local.lb_raw.backend.iap_config.oauth2_client_secret, null)
      }

      groups = local.backend_groups
    }
  }
}
