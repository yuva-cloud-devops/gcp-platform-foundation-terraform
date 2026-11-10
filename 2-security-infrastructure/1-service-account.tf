# Creates Service Accounts and binds least-privilege IAM roles
module "service_accounts" {
  for_each = local.service_accounts

  source  = "terraform-google-modules/service-accounts/google"
  version = "~> 5.1.0"

  # Project Details:
  project_id = local.project_id

  # Service Account Identity:
  prefix       = ""
  names        = [each.value.account_id]
  display_name = each.value.display_name
  description  = each.value.description

  # IAM Role Bindings ("project_id=>role"):
  project_roles = each.value.project_roles
}
