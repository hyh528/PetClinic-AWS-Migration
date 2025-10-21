variable "service_name" {
  description = "ECS 서비스의 이름 (예: customers-service)"
  type        = string
}

variable "image_uri" {
  description = "서비스에 사용할 Docker 이미지의 ECR URI"
  type        = string
}

variable "container_port" {
  description = "컨테이너가 리스닝하는 포트"
  type        = number
}

variable "vpc_id" {
  description = "서비스가 배포될 VPC의 ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "ECS Task를 배포할 Private Subnet ID 목록"
  type        = list(string)
}

variable "ecs_service_sg_id" {
  description = "ECS 서비스에 적용할 보안 그룹 ID"
  type        = string
}

# --- 추가된 변수 ---
variable "cluster_id" {
  description = "사용할 ECS 클러스터의 ID"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ECS Task 실행 역할의 ARN"
  type        = string
}

variable "task_role_arn" {                         
  description = "ECS Task에 할당할 IAM 역할의 ARN" 
  type        = string                             
  default     = null                               
}                                                  

variable "listener_arn" {
  description = "연결할 ALB 리스너의 ARN"
  type        = string
}

variable "listener_priority" {
  description = "ALB 리스너 규칙의 우선순위 (서비스마다 달라야 함)"
  type        = number
}

# --- 이하 CPU/Memory 등 나머지 변수는 이전과 동일 ---
variable "task_cpu" {
  description = "ECS Task에 할당할 CPU"
  type        = string
  default     = "256" # 0.25 vcpu
}

variable "task_memory" {
  description = "ECS Task에 할당할 메모리 (MiB)"
  type        = string
  default     = "512"
}

variable "aws_region" {
  description = "배포할 AWS 리전"
  type        = string
}

#cloudmap 연동
variable "cloudmap_service_arn" {
  description = "Cloud Map에 등록할 서비스의 ARN입니다."
  type        = string
  default     = null # 모든 서비스가 Cloud Map을 사용하지 않을 수도 있으므로 optional로 설정
}

# secret manager 연동
 variable "db_master_user_secret_arn" {                                                                
   description = "The ARN of the secret in Secrets Manager for the DB password"                     
   type        = string                                                                             
 }                                                                                                  
                                                                                                    
 variable "db_url_parameter_path" {                                                                 
   description = "The path in Parameter Store for the DB URL"                                       
   type        = string                                                                             
 }                                                                                                  
                                                                                                    
 variable "db_username_parameter_path" {                                                            
   description = "The path in Parameter Store for the DB username"                                  
   type        = string                                                                             
 }                                                                                                  