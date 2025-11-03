# 배포할 서비스별 목록 및 고유 설정, 파라미터 스토어 경로 이름 정의
locals {
  service_definitions = {
    "admin-server"      = { priority = 100, path_name = "admin" }
    "customers-service" = { priority = 110, path_name = "customers" }
    "vets-service"      = { priority = 120, path_name = "vets" }
    "visits-service"    = { priority = 130, path_name = "visits" }
  }
}

# 2. for_each를 사용해 각 서비스의 포트 번호를 Parameter Store에서 가져옵니다.
#    새로 추가한 path_name을 사용해 경로를 동적으로 구성합니다.
data "aws_ssm_parameter" "service_ports" {
  for_each = local.service_definitions
  name     = "/petclinic/dev/${each.value.path_name}/server.port"
}

# 3. 위 정보들을 조합하여 ecs_services 맵을 동적으로 생성합니다.
locals {
  ecs_services = {
    for name, config in local.service_definitions : name => {
      # 데이터 소스는 원래 서비스 이름(map의 key)으로 참조합니다.
      container_port = tonumber(data.aws_ssm_parameter.service_ports[name].value)
      #container_port = 8080
      image_uri      = "${module.ecr.repository_urls[name]}:latest"
      priority       = config.priority
    }
  }
}

# for_each를 사용하여 서비스별로 ecs 모듈 호출
module "ecs" {
  for_each = local.ecs_services
  source   = "../../../modules/ecs"
  
  # --- DB 접근 정보 전달 ---                                                                               
  db_master_user_secret_arn   = data.terraform_remote_state.database.outputs.db_master_user_secret_arn
  db_url_parameter_arn    = data.terraform_remote_state.database.outputs.db_url_parameter_arn
  db_username_parameter_arn = data.terraform_remote_state.database.outputs.db_username_parameter_arn

  # --- 공유 리소스 값 전달 ---
  aws_region                  = var.aws_region
  vpc_id                      = data.terraform_remote_state.network.outputs.vpc_id
  private_subnet_ids          = values(data.terraform_remote_state.network.outputs.private_app_subnet_ids)
  ecs_service_sg_id           = data.terraform_remote_state.security.outputs.app_security_group_id
  cluster_id                  = aws_ecs_cluster.main.id
  ecs_task_execution_role_arn = data.aws_iam_role.ecs_task_execution_role.arn
  listener_arn                = aws_lb_listener.http.arn
  task_role_arn               = data.terraform_remote_state.security.outputs.ecs_task_role_arn   
  context_path                = local.service_definitions[each.key].path_name

  secrets_variables = {
    "SPRING_DATASOURCE_PASSWORD" = "${data.terraform_remote_state.database.outputs.db_master_user_secret_arn}:password::",
    "SPRING_DATASOURCE_URL"      = data.terraform_remote_state.database.outputs.db_url_parameter_arn,
    "SPRING_DATASOURCE_USERNAME" = data.terraform_remote_state.database.outputs.db_username_parameter_arn 
  } // 동적 참조 방식
/* 
  #alb healthcheck 때문에 수정함
  secrets_variables = each.key == "admin-server" ? {} : {
    "SPRING_DATASOURCE_PASSWORD" = "${data.terraform_remote_state.database.outputs.db_master_user_secret_arn}:password::",
    "SPRING_DATASOURCE_URL"      = data.terraform_remote_state.database.outputs.db_url_parameter_arn,
    "SPRING_DATASOURCE_USERNAME" = data.terraform_remote_state.database.outputs.db_username_parameter_arn 
  } // 동적 참조 방식

   secrets_variables = {
    "SPRING_DATASOURCE_PASSWORD" = "arn:aws:secretsmanager:ap-northeast-2:897722691159:secret:rds!cluster-0edf3242-4cb9-4b90-9896-52cc5068a5fb-XmjB9d:password::",
    "SPRING_DATASOURCE_URL"      = "/petclinic/common/database.url"
    "SPRING_DATASOURCE_USERNAME" = "/petclinic/common/database.username"
  } //하드 코딩 방식
*/
  environment_variables = {
   "SPRING_PROFILES_ACTIVE" = "mysql,aws",
  }

  # --- 서비스별 값 전달 ---
  service_name      = each.key
  image_uri         = each.value.image_uri
  container_port    = each.value.container_port
  listener_priority = each.value.priority

  # 각 서비스의 이름(each.key)에 해당하는 Cloud Map 서비스의 ARN을 전달
  cloudmap_service_arn = module.cloudmap.service_arns[each.key]

}