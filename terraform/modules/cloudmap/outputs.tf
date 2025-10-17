  output "namespace_id" {
    description = "The ID of the private DNS namespace."
    value       = aws_service_discovery_private_dns_namespace.this.id
  }

  output "namespace_arn" {
    description = "The ARN of the private DNS namespace."
    value       = aws_service_discovery_private_dns_namespace.this.arn
  }

  output "service_ids" {
    description = "A map of service names to their IDs."
    value       = { for k, v in aws_service_discovery_service.this : k => v.id }
  }

  output "service_arns" {
    description = "A map of service names to their ARNs."
    value       = { for k, v in aws_service_discovery_service.this : k => v.arn }
  }