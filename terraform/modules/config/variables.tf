# /terraform/modules/config/variables.tf

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "db_username" {
  description = "Database admin username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database admin password"
  type        = string
  sensitive   = true
}

variable "db_endpoint" {
  description = "Database endpoint URL"
  type        = string
  default     = "database-placeholder.endpoint.amazonaws.com" # Will be replaced by actual DB module output
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "petclinic"
}
