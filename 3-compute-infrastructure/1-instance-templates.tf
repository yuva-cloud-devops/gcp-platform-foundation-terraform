# Creates Compute Engine Instance Templates dynamically from compute.yaml
module "instance_template" {
  for_each = local.migs

  source  = "terraform-google-modules/vm/google//modules/instance_template"
  version = "~> 13.2.4"

  # Project & Location
  project_id  = local.project_id
  region      = each.value.region
  name_prefix = each.value.template.name_prefix

  # Machine & Packer Golden Image Configuration
  machine_type         = each.value.template.machine_type
  disk_size_gb         = each.value.template.disk_size_gb
  disk_type            = each.value.template.disk_type
  auto_delete          = each.value.template.auto_delete
  source_image         = each.value.template.source_image
  source_image_family  = each.value.template.source_image_family
  source_image_project = each.value.template.source_image_project

  # Network Attachment (Private Subnet from 1-network-infrastructure + GVNIC)
  subnetwork = each.value.template.subnetwork
  nic_type   = each.value.template.nic_type
  tags       = each.value.template.tags

  # Security & IAM (Uses existing SA from 2-security-infrastructure)
  create_service_account   = false
  service_account          = each.value.template.service_account
  enable_shielded_vm       = each.value.template.enable_shielded_vm
  shielded_instance_config = each.value.template.shielded_instance_config

  # Metadata, Labels & Optional Startup Script
  startup_script = each.value.template.startup_script
  metadata       = each.value.template.metadata
  labels         = each.value.labels
  disk_labels    = each.value.labels
}
