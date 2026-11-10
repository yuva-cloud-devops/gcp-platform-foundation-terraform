terraform {

  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # ----------------------------------------------------------------------------
  # Remote Backend (GCS)
  # Dynamic configuration injected by Cloud Build via -backend-config
  # ----------------------------------------------------------------------------
  backend "gcs" {}
}


provider "google" {
  project        = local.config.project_id
  region         = local.config.region
  default_labels = local.common_tags
}

# ------------------------------------------------------------------------------
# Remote State Data Sources (Upstream Layer Outputs)
# ------------------------------------------------------------------------------
data "terraform_remote_state" "network" {
  backend = "gcs"
  config = {
    bucket = local.state_bucket
    prefix = "${var.environment}/network"
  }
}

data "terraform_remote_state" "security" {
  backend = "gcs"
  config = {
    bucket = local.state_bucket
    prefix = "${var.environment}/security"
  }
}
