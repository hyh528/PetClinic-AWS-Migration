module "api_gateway" {                                        
  source = "../../../modules/api-gateway"                     
                                                              
  project_name = "petclinic"                                  
  environment  = "dev"                                        
                                                              
  # alb.tf에서 생성된 ALB의 DNS 이름을 전달하여 연결합니다.   
  alb_dns_name = aws_lb.main.dns_name                         
}