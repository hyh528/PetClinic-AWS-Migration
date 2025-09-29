variable "project_name" {
  description = "The project name prefix for resources in the dev environment."
  type        = string
  default     = "petclinic"
}

variable "group_name" {
  description = "The name for the IAM group."
  type        = string
  default     = "petclinic-team"
}

variable "team_members" {
  description = "List of team member names for the dev environment."
  type        = list(string)
  default = [
    "yeonghyeon",
    "seokgyeom",
    "junje",
    "hwigwon"
  ]
}
