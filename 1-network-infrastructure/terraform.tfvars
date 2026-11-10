# project_id = "yuvaraj-internal-project"
# region     = "asia-south1"



# # Networking infrastructure Values:
# network = {

#   vpc = {

#     # VPC Configuration
#     network_name = "platform-foundation-vpc"

#     # Subnet Configuration
#     subnets = [
#       {
#         subnet_name           = "private-app-mumbai"
#         subnet_ip             = "10.20.1.0/24"
#         subnet_region         = "asia-south1"
#         subnet_private_access = "true"
#       },
#       {
#         subnet_name           = "private-app-singapore"
#         subnet_ip             = "10.30.1.0/24"
#         subnet_region         = "asia-southeast1"
#         subnet_private_access = "true"
#       }
#     ]

#     # Firewall Rules
#     firewall_rules = {
#       ingress = [
#         {
#           name          = "allow-management"
#           source_ranges = ["10.0.0.0/8"]
#           ports         = ["22"]
#         },
#         {
#           name          = "allow-web"
#           source_ranges = ["0.0.0.0/0"]
#           ports         = ["80", "443"]
#         }
#       ]
#       egress = [
#         {
#           name               = "allow-internet"
#           destination_ranges = ["0.0.0.0/0"]
#           ports              = ["80", "443"]
#         }
#       ]
#     }
#   }


#   # Cloud Routers
#   router = [
#     {
#       name   = "router-mumbai"
#       region = "asia-south1"
#       bgp = {
#         asn = "65001"
#       }
#     },
#     {
#       name   = "router-singapore"
#       region = "asia-southeast1"
#       bgp = {
#         asn = "65002"
#       }
#     }
#   ]


#   # Cloud NATs
#   nat = [
#     {
#       name        = "nat-mumbai"
#       region      = "asia-south1"
#       router_name = "router-mumbai"
#     },
#     {
#       name        = "nat-singapore"
#       region      = "asia-southeast1"
#       router_name = "router-02"
#     }
#   ]
# }



# environment = "dev"
# terraform init -backend-config="backend.hcl" -reconfigure
# terraform plan -var="environment=dev"
# terraform apply -var="environment=dev"
# terraform destroy -var="environment=dev"
