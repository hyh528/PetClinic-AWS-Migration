output "arn" {
  description = "The ARN of the load balancer."
  value       = aws_lb.main.arn
}

output "arn_suffix" {
  description = "The ARN suffix of the load balancer."
  value       = aws_lb.main.arn_suffix
}

output "dns_name" {
  description = "The DNS name of the load balancer."
  value       = aws_lb.main.dns_name
}

output "listener_arn" {
  description = "The ARN of the HTTP listener."
  value       = aws_lb_listener.http.arn
}

output "id" {
  description = "The ID of the load balancer."
  value       = aws_lb.main.id
}

output "zone_id" {
  description = "The canonical hosted zone ID of the load balancer."
  value       = aws_lb.main.zone_id
}