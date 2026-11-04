locals {
  # Decode the bootstrap.yaml configuration
  config = yamldecode(file(var.config_path))

  # Extract values
  project_id   = local.config.project_id
  region       = local.config.region
  gcs_location = local.config.gcs_location
  apis         = toset(local.config.apis)

  # Storage Buckets Map
  buckets = local.config.buckets

  sa_name  = local.config.service_account.name
  sa_desc  = lookup(local.config.service_account, "description", "Cloud Build SA")
  sa_disp  = lookup(local.config.service_account, "display_name", local.sa_name)
  sa_roles = toset(local.config.service_account.roles)


  # Cloud Build Repositories & Triggers Map
  cloudbuild_repositories = try(local.config.cloudbuild.repositories, {})
  cloudbuild_triggers     = try(local.config.cloudbuild.triggers, {})
}
