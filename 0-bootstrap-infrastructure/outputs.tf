output "terraform_state_bucket" {
  description = "GCS bucket for remote Terraform state"
  value       = google_storage_bucket.buckets["state_bucket"].name
}

output "terraform_plans_bucket" {
  description = "GCS bucket for binary plan review files"
  value       = google_storage_bucket.buckets["plan_bucket"].name
}

output "cloudbuild_service_account_email" {
  description = "Cloud Build executor service account email"
  value       = google_service_account.cloudbuild_sa.email
}
