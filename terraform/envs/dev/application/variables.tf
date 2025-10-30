variable "aws_profile" {
  description = "인증용 AWS 프로필"
  type        = string
}

variable "aws_region" {
  description = "리소스용 AWS 리전"
  type        = string
}
variable "network_state_profile" {
  description = "네트워크 상태 파일 접근용 AWS 프로필"
  type        = string
}

variable "security_state_profile" {
  description = "보안 상태 파일 접근용 AWS 프로필"
  type        = string
}

variable "database_state_profile" {
  description = "DB 상태 파일 접근용 AWS 프로필"
  type        = string
}

                                                                         
variable "tf_lock_table_name" {                                          
  description = "Terraform 상태 잠금에 사용될 DynamoDB 테이블 이름"      
  type        = string                                                   
  default     = "petclinic-tf-locks-jungsu-kopo"                         
}                                                                        
                                                                         
variable "encrypt_state" {                                               
  description = "Terraform 상태 파일을 암호화할지 여부"                  
  type        = bool                                                     
  default     = true                                                     
}                                                   