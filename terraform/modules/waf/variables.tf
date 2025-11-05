variable "name_prefix" {
  description = "A prefix for naming resources."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., dev, prod)."
  type        = string
}

variable "scope" {
  description = "The scope of the Web ACL. Valid values are CLOUDFRONT or REGIONAL."
  type        = string
  default     = "REGIONAL" # API Gateway is REGIONAL
}

variable "api_gateway_arn" {
  description = "The ARN of the API Gateway to associate with the WAF Web ACL."
  type        = string
}

variable "enable_rate_limiting" {
  description = "Flag to enable or disable the rate-based rule."
  type        = bool
  default     = true
}

variable "rate_limit_threshold" {
  description = "The maximum number of requests allowed from a single IP address in a 5-minute period."
  type        = number
  default     = 2000
}