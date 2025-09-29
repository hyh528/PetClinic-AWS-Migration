variable "project_name" {
  description = "A prefix for all created resources."
  type        = string
}

variable "group_name" {
  description = "The name of the IAM group."
  type        = string
}

variable "team_members" {
  description = "A list of team member names to create IAM users for."
  type        = list(string)
  default     = []
}
