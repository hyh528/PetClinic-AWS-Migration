variable "teams_webhook_url" {
  description = "The Microsoft Teams webhook URL to send notifications to."
  type        = string
  sensitive   = true
}

variable "sns_topic_arn" {
  description = "The ARN of the SNS topic to subscribe to."
  type        = string
}
