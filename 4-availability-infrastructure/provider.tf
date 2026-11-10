terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
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
  project        = local.project_id
  region         = local.region
  default_labels = local.common_tags
}

provider "google-beta" {
  project        = local.project_id
  region         = local.region
  default_labels = local.common_tags
}


# ------------------------------------------------------------------------------
# Remote State Data Sources (Upstream Layer Outputs)
# ------------------------------------------------------------------------------

# 1. Network Layer Remote State (VPC & Subnets)
data "terraform_remote_state" "network" {
  backend = "gcs"
  config = {
    bucket = local.state_bucket
    prefix = "${var.environment}/network"
  }
}

# 2. Compute Layer Remote State (Multi-Region MIG Instance Groups)
data "terraform_remote_state" "compute" {
  backend = "gcs"
  config = {
    bucket = local.state_bucket
    prefix = "${var.environment}/compute"
  }
}
