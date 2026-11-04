# variable "project_id" {
#   description = "GCP Project Detials"
#   type        = string
# }

# variable "region" {
#   description = "GCP region name"
#   type        = string
# }


# # Networking Infrastructure Parameters:
# variable "network" {
#   description = "Network configuration"

#   type = object({

#     # VPC Parameters: (VPC, Subnets, Firewall, Secondary CIDR for GKE, IGW)
#     vpc = optional(object({
#       network_name            = string
#       routing_mode            = optional(string, "GLOBAL")
#       auto_create_subnetworks = optional(bool, false)
#       delete_default_routes   = optional(bool, false)


#       # Subnets detials
#       subnets = optional(list(any), [])
#       routes  = optional(list(any), [])


#       # Secondary CIDR for GKE (Optional)
#       secondary_ranges = optional(map(list(object({
#         range_name    = string
#         ip_cidr_range = string
#       }))), {})


#       # Firewall Rules
#       firewall_rules = optional(object({
#         # Inbound Rules:
#         ingress = optional(list(object({
#           name          = string       # Firewall rule name
#           source_ranges = list(string) # Source CIDRs
#           ports         = list(string) # Allowed ports
#           target_tags   = optional(list(string), [])
#         })), [])
#         # Outbound Rules:
#         egress = optional(list(object({
#           name               = string       # Firewall rule name
#           destination_ranges = list(string) # Destination CIDRs
#           ports              = list(string) # Allowed ports
#           target_tags        = optional(list(string), [])
#         })), [])
#       }))

#     }))

#     # Cloud Router Parameters: (VPC, BGP)
#     router = optional(list(object({
#       name   = string
#       region = string
#       bgp = object({
#         asn               = string                      # Unique router identifier
#         advertise_mode    = optional(string, "DEFAULT") # Route advertisement strategy
#         advertised_groups = optional(list(string), [])  # Advertise subnet routes
#         advertised_ip_ranges = optional(list(object({
#           range = string                        # Custom network prefix
#         description = optional(string) })), []) # Advertised range description
#       keepalive_interval = optional(number) })  # BGP heartbeat interval
#     })), [])

#     # Cloud NAT Parameters: (Subnet Scope, PORTS, Mapping)
#     nat = optional(list(object({
#       name                                = string
#       region                              = string
#       router_name                         = string                                            # Associated router
#       source_subnetwork_ip_ranges_to_nat  = optional(string, "ALL_SUBNETWORKS_ALL_IP_RANGES") # NAT subnet scope
#       min_ports_per_vm                    = optional(number, 64)                              # Minimum NAT ports
#       max_ports_per_vm                    = optional(number, 2048)                            # Maximum NAT ports
#       enable_endpoint_independent_mapping = optional(bool, true)                              # Reuse NAT mappings
#     })), [])
#   })
# }




##################################################
# Environment Configuration
##################################################

variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition = contains(
      ["dev", "sit", "uat", "prod"],
      var.environment
    )

    error_message = "Environment must be dev, sit, uat, or prod."
  }
}
