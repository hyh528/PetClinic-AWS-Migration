variable "name" {
  description = "The name for the Application Load Balancer."
  type        = string
}

variable "internal" {
  description = "Whether the load balancer is internal."
  type        = bool
  default     = false
}

variable "load_balancer_type" {
  description = "The type of load balancer."
  type        = string
  default     = "application"
}

variable "security_groups" {
  description = "A list of security group IDs to associate with the load balancer."
  type        = list(string)
}

variable "subnets" {
  description = "A list of subnet IDs to attach to the load balancer."
  type        = list(string)
}

variable "tags" {
  description = "A map of tags to assign to the load balancer."
  type        = map(string)
  default     = {}
}

variable "listener_port" {
  description = "The port for the default listener."
  type        = number
  default     = 80
}

variable "listener_protocol" {
  description = "The protocol for the default listener."
  type        = string
  default     = "HTTP"
}