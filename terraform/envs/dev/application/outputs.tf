output "api_gateway_invoke_url" {                           
  description = "The invoke URL for the API Gateway stage"  
  value       = module.api_gateway.invoke_url               
}

output "alb_dns_name" {
  description = "The DNS name of the main Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecr_repository_urls" {
  description = "A map of ECR repository names to their URLs"
  value       = module.ecr.repository_urls
}

output "cloudmap_namespace" {
  description = "The name of the Cloud Map private DNS namespace"
  value       = module.cloudmap.namespace_name
}