# Map of logical SA name => email (e.g., "sa-mig-workload" => "sa-mig-workload-dev@...")
output "service_account_emails" {
  description = "Map of service account logical names to their emails"
  value = {
    for name, sa in module.service_accounts :
    name => sa.email
  }
}

# Map of logical SA name => IAM member format ("serviceAccount:...")
output "service_account_iam_emails" {
  description = "Map of service account logical names to their IAM-formatted emails"
  value = {
    for name, sa in module.service_accounts :
    name => sa.iam_email
  }
}
