module "cloudmap" {
  # 모듈 경로
  source = "../../../modules/cloudmap"

  namespace_name =  "petclinic.test"

  # 사용할 VPC
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  #Cloudmap에 등록할 마이크로 서비스 목록
  service_name_map = {
    "customers-service" = "customer service"
    "vets-service"      = "vets-service"
    "visits-service"    = "visits-service"
    "admin-server"      = "admin-server" 
  }
} #Cloud Map 모듈