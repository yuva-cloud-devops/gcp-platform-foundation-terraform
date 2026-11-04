terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = local.project_id
  region  = local.region
}

# -----------------------------------------------------------------------------
# 1. Dynamic API Enablement
# -----------------------------------------------------------------------------
resource "google_project_service" "apis" {
  for_each = local.apis

  project            = local.project_id
  service            = each.key
  disable_on_destroy = false
}

# -----------------------------------------------------------------------------
# 2. GCS Storage Buckets (State & Plan Review)
# -----------------------------------------------------------------------------
resource "google_storage_bucket" "buckets" {
  for_each = local.buckets

  name                        = each.value.name
  location                    = local.gcs_location
  project                     = local.project_id
  force_destroy               = try(each.value.force_destroy, false)
  uniform_bucket_level_access = try(each.value.uniform_bucket_level_access, true)

  dynamic "versioning" {
    for_each = try(each.value.versioning, false) ? [true] : []
    content {
      enabled = true
    }
  }

  dynamic "lifecycle_rule" {
    for_each = try(each.value.lifecycle_days, null) != null ? [each.value.lifecycle_days] : []
    content {
      action {
        type = "Delete"
      }
      condition {
        age = lifecycle_rule.value
      }
    }
  }

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# 3. Cloud Build Service Account
# -----------------------------------------------------------------------------
resource "google_service_account" "cloudbuild_sa" {
  account_id   = local.sa_name
  display_name = local.sa_disp
  description  = local.sa_desc
  project      = local.project_id

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# 4. Dynamic IAM Roles Assignment
# -----------------------------------------------------------------------------
resource "google_project_iam_member" "cloudbuild_sa_roles" {
  for_each = local.sa_roles

  project = local.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

# -----------------------------------------------------------------------------
# 5. Cloud Build Impersonation Binding
# -----------------------------------------------------------------------------
data "google_project" "current" {
  project_id = local.project_id
}

resource "google_service_account_iam_member" "cloudbuild_impersonation" {
  service_account_id = google_service_account.cloudbuild_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${data.google_project.current.number}@cloudbuild.gserviceaccount.com"

  depends_on = [google_project_service.apis]
}
