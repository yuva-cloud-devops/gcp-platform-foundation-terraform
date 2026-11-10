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
