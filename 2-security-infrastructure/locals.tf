locals {
  # Load environment-specific YAML configuration
  config = yamldecode(
    file("${path.root}/../environments/${var.environment}/security.yaml")
  )

  project_id = local.config.project_id
  region     = local.config.region

  # Common Key-Value Identification Tags / Labels
  common_tags = merge(
    {
      provisioned_by = "terraform"
      environment    = var.environment
      project        = "gcp-platform-foundation-terraform"
    },
    try(local.config.tags, {})
  )

  # Formatted Tag String for IAM Service Account descriptions
  tag_description = join(", ", [for k, v in local.common_tags : "${k}:${v}"])

  # Normalize and safeguard Service Accounts into a resilient map
  service_accounts = {
    for sa in try(local.config.security.service_accounts, []) :
    sa.name => {
      account_id   = "${sa.name}-${var.environment}"
      display_name = try(coalesce(sa.display_name, "${sa.name}-${var.environment}"), "${sa.name}-${var.environment}")
      description  = "${try(coalesce(sa.description, "Managed by Terraform"), "Managed by Terraform")} [${local.tag_description}]"
      project_roles = [
        for role in distinct(try(sa.roles, [])) :
        "${local.project_id}=>${role}"
      ]
    }
  }
}
