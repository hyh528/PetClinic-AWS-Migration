variable "project_name" {
  description = "The name of the project, used for naming resources."
  type        = string
  default     = "petclinic"
}

variable "team_members" {
  description = "A list of team member names to create IAM users for."
  type        = list(string)
  default     = []
}

variable "db_secret_arn" {
  description = "The ARN of the database secret in Secrets Manager."
  type        = string
  default     = null
}
