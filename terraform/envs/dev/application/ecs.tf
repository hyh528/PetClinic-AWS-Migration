# 배포할 서비스 목록을 map으로 정의
locals {
  ecs_services = {
    "customers-service" = {
      container_port = 8080
      image_uri      = "${module.ecr.repository_urls["customers-service"]}:latest"
      priority       = 100 # 리스너 규칙 우선순위 (겹치면 안 됨)
    },
    "vets-service" = {
      container_port = 8080
      image_uri      = "${module.ecr.repository_urls["vets-service"]}:latest"
      priority       = 110
    },
    "visits-service" = {
      container_port = 8080
      image_uri      = "${module.ecr.repository_urls["visits-service"]}:latest"
      priority       = 120
    }
  }
}

# for_each를 사용하여 서비스별로 ecs 모듈 호출
module "ecs" {
  for_each = local.ecs_services
  source   = "../../../modules/ecs"

  # --- 공유 리소스 값 전달 ---
  aws_region                  = var.aws_region
  vpc_id                      = data.terraform_remote_state.network.outputs.vpc_id
  private_subnet_ids          = values(data.terraform_remote_state.network.outputs.private_app_subnet_ids)
  ecs_service_sg_id           = data.terraform_remote_state.security.outputs.app_security_group_id
  cluster_id                  = aws_ecs_cluster.main.id
  ecs_task_execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  listener_arn                = aws_lb_listener.http.arn

  # --- 서비스별 값 전달 ---
  service_name      = each.key
  image_uri         = each.value.image_uri
  container_port    = each.value.container_port
  listener_priority = each.value.priority


  # 각 서비스의 이름(each.key)에 해당하는 Cloud Map 서비스의 ARN을 전달
  cloudmap_service_arn = module.cloudmap.service_arns[each.key]
}