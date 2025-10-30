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

output "ecs_service_names" {
  description = "A map of ECS service names, keyed by service identifier"
  value = {
    for k, m in module.ecs : k => m.service_name
  }
}

output "alb_target_group_arn_suffixes" {
  description = "A map of ALB target group ARN suffixes, keyed by service identifier"
  value = {
    for k, m in module.ecs : k => m.target_group_arn_suffix
  }
}

#모니터링
output "api_gateway_name" {
  description = "The name of the API Gateway"
  value       = module.api_gateway.name
}

 output "alb_arn_suffix" {                                                                                        
  description = "The ARN suffix of the main Application Load Balancer (e.g., app/my-alb/1234567890abcdef)"       
  value       = aws_lb.main.arn_suffix                                                                           
}

output "alb_target_group_ids" {
  description = "A map of ALB target group IDs, keyed by service identifier"
  value = {
    for k, m in module.ecs : k => m.target_group_id
  }
}
                                                                
output "alb_target_group_arns" {                                              
  description = "A map of ALB target group ARNs, keyed by service identifier" 
  value = {                                                                   
    for k, m in module.ecs : k => m.target_group_arn                          
  }                                                                           
}                                                                             