# -----------------------------------------------------------------------------
# 1. Link GitHub Repository (Cloud Build 2nd Gen)
# -----------------------------------------------------------------------------
resource "google_cloudbuildv2_repository" "github_repos" {
  for_each = local.cloudbuild_repositories

  project           = local.project_id
  location          = local.region
  name              = each.value.name
  parent_connection = each.value.parent_connection
  remote_uri        = each.value.remote_uri

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# 2. Dynamic Cloud Build Triggers (CI / CD / Tags)
# -----------------------------------------------------------------------------
resource "google_cloudbuild_trigger" "triggers" {
  for_each = local.cloudbuild_triggers

  name        = each.value.name
  location    = local.region
  project     = local.project_id
  description = try(each.value.description, null)
  disabled    = try(each.value.disabled, false)
  filename    = try(each.value.filename, null)

  service_account = google_service_account.cloudbuild_sa.id

  # Dynamic Repository Event Config (Supports both PR and Push events)
  dynamic "repository_event_config" {
    for_each = try(each.value.repository_key, null) != null ? [each.value.repository_key] : []
    content {
      repository = google_cloudbuildv2_repository.github_repos[repository_event_config.value].id

      # PR Dynamic Block
      dynamic "pull_request" {
        for_each = try(each.value.pull_request, null) != null ? [each.value.pull_request] : []
        content {
          branch          = try(pull_request.value.branch, null)
          comment_control = try(pull_request.value.comment_control, "COMMENTS_ENABLED_FOR_EXTERNAL_CONTRIBUTORS_ONLY")
          invert_regex    = try(pull_request.value.invert_regex, null)
        }
      }

      # Push / Branch / Tag Dynamic Block
      dynamic "push" {
        for_each = try(each.value.push, null) != null ? [each.value.push] : []
        content {
          branch       = try(push.value.branch, null)
          tag          = try(push.value.tag, null)
          invert_regex = try(push.value.invert_regex, null)
        }
      }
    }
  }

  # Automatically inject bucket names into substitutions alongside custom ones
  substitutions = merge(
    {
      _STATE_BUCKET = google_storage_bucket.buckets["state_bucket"].name
      _PLAN_BUCKET  = google_storage_bucket.buckets["plan_bucket"].name
    },
    try(each.value.substitutions, {})
  )

  include_build_logs = try(each.value.include_build_logs, "INCLUDE_BUILD_LOGS_WITH_STATUS")

  depends_on = [
    google_cloudbuildv2_repository.github_repos,
    google_service_account_iam_member.cloudbuild_impersonation
  ]
}
