# ------------------------------------------------------------------------------
# 1. Instance Template Outputs
# ------------------------------------------------------------------------------
output "instance_template_names" {
  description = "Map of MIG logical names to their created Instance Template names"
  value = {
    for name, tpl in module.instance_template :
    name => tpl.name
  }
}

output "instance_template_self_links" {
  description = "Map of MIG logical names to their instance template unique self-links"
  value = {
    for name, tpl in module.instance_template :
    name => tpl.self_link_unique
  }
}

# ------------------------------------------------------------------------------
# 2. Managed Instance Group (MIG) Core Outputs (For Load Balancer in Layer 4)
# ------------------------------------------------------------------------------
output "mig_names" {
  description = "Map of MIG logical names to their deployed GCP MIG names"
  value = {
    for name, mig in module.mig :
    name => mig.instance_group_manager.name
  }
}

output "mig_regions" {
  description = "Map of MIG logical names to their deployed GCP regions"
  value = {
    for name, mig in module.mig :
    name => mig.instance_group_manager.region
  }
}

output "mig_instance_groups" {
  description = "Map of MIG logical names to their instance_group URLs (for Load Balancer backend)"
  value = {
    for name, mig in module.mig :
    name => mig.instance_group
  }
}

output "mig_self_links" {
  description = "Map of MIG logical names to their MIG self-links"
  value = {
    for name, mig in module.mig :
    name => mig.self_link
  }
}

output "mig_health_check_self_links" {
  description = "Map of MIG logical names to their auto-healing health check self-links"
  value = {
    for name, mig in module.mig :
    name => mig.health_check_self_links
  }
}

# ------------------------------------------------------------------------------
# 3. Live Verification & Private IP Testing Commands
# ------------------------------------------------------------------------------
output "test_list_mig_private_ips" {
  description = "Run these gcloud commands to view the live VMs and Private IPs in each Regional MIG"
  value = {
    for name, mig in module.mig :
    name => "gcloud compute instance-groups managed list-instances ${mig.instance_group_manager.name} --region=${mig.instance_group_manager.region} --project=${local.project_id}"
  }
}

output "test_vm_private_ips_command" {
  description = "Command to list all spawned MIG VM names, zones, and Private IPs across Mumbai and Singapore"
  value       = "gcloud compute instances list --filter=\"name~'mig-web-'\" --format=\"table(name, zone, networkInterfaces[0].networkIP:label=PRIVATE_IP, status)\" --project=${local.project_id}"
}

output "test_app_via_iap_command" {
  description = "Template command to test the Golang app on port 8080 inside any private MIG VM using IAP SSH"
  value       = "gcloud compute ssh <VM_NAME> --zone=<ZONE> --tunnel-through-iap --project=${local.project_id} --command=\"curl -i http://localhost:8080\""
}
