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

