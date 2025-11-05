# 배포할 서비스별 목록 및 고유 설정, 파라미터 스토어 경로 이름 정의
locals {
  service_definitions = {
    "customers-service" = { priority = 110, path_name = "customers", needs_db = true }
    "vets-service"      = { priority = 120, path_name = "vets", needs_db = true }
    "visits-service"    = { priority = 130, path_name = "visits", needs_db = true }
  }
}

# 2. for_each를 사용해 각 서비스의 포트 번호를 Parameter Store에서 가져옵니다.
#    새로 추가한 path_name을 사용해 경로를 동적으로 구성합니다.
data "aws_ssm_parameter" "service_ports" {
  for_each = local.service_definitions
  name     = "/petclinic/dev/${each.value.path_name}/server.port"
}

data "aws_ssm_parameter" "admin_server_port" {
   name = "/petclinic/dev/admin/server.port"
}



# 3. 위 정보들을 조합하여 ecs_services 맵을 동적으로 생성합니다.
locals {
  ecs_services = {
    for name, config in local.service_definitions : name => {
      # 데이터 소스는 원래 서비스 이름(map의 key)으로 참조합니다.
      container_port = tonumber(data.aws_ssm_parameter.service_ports[name].value)
      image_uri      = "${module.ecr.repository_urls[name]}:latest"
      priority       = config.priority
      needs_db       = config.needs_db
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
  cluster_id                  = module.ecs_cluster.cluster_id
  ecs_task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
  listener_arn                = module.alb.listener_arn
  task_role_arn               = data.terraform_remote_state.security.outputs.ecs_task_role_arn   
  context_path                = local.service_definitions[each.key].path_name

  secrets_variables = each.value.needs_db ? {
    "SPRING_DATASOURCE_PASSWORD" = "${data.terraform_remote_state.database.outputs.db_master_user_secret_arn}:password::",
    "SPRING_DATASOURCE_URL"      = data.terraform_remote_state.database.outputs.db_url_parameter_arn,
    "SPRING_DATASOURCE_USERNAME" = data.terraform_remote_state.database.outputs.db_username_parameter_arn 
  } : {}

  environment_variables = {
   "SPRING_PROFILES_ACTIVE" = "mysql,aws",
   "SERVER_SERVLET_CONTEXT_PATH" = "/${local.service_definitions[each.key].path_name}",
   "MANAGEMENT_HEALTH_PROBES_ENABLED" = "true"
  }
  
  # --- 서비스별 값 전달 ---
  service_name      = each.key
  image_uri         = each.value.image_uri
  container_port    = each.value.container_port
  listener_priority = each.value.priority
  cloudmap_service_arn = module.cloudmap.service_arns[each.key]

  # [수정] DB 사용 서비스들의 헬스 체크 유예 기간 증가
  health_check_grace_period = 180
}

# ===================================================================
# Admin Server 전용 리소스 (별도 관리)
# ===================================================================

# 1. admin-server용 CloudWatch Log Group
resource "aws_cloudwatch_log_group" "admin_server" {
  name              = "/ecs/petclinic/admin-server"
  retention_in_days = 7
}

# 2. admin-server용 Target Group (전용 Health Check 경로 사용)
resource "aws_lb_target_group" "admin_server" {
  name        = "tg-admin-server"
  port        = tonumber(data.aws_ssm_parameter.admin_server_port.value) # admin-server는 9090 포트를 사용
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  target_type = "ip"

  health_check {
    path                = "/actuator/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# 3. admin-server용 Listener Rule
resource "aws_lb_listener_rule" "admin_server" {
  listener_arn = module.alb.listener_arn
  priority     = 100 # 기존 admin-server 우선순위

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.admin_server.arn
  }

  condition {
    path_pattern {
      values = ["/admin*"] # admin-server의 경로 패턴
    }
  }
}

# 4. admin-server용 ECS Task Definition
resource "aws_ecs_task_definition" "admin_server" {
  family                   = "admin-server-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = module.ecs_cluster.task_execution_role_arn
  task_role_arn            = data.terraform_remote_state.security.outputs.ecs_task_role_arn

  container_definitions = jsonencode([{
    name      = "admin-server",
    image     = "${module.ecr.repository_urls["admin-server"]}:latest"
    cpu       = 256
    memory    = 512
    essential = true,
    portMappings = [{
      containerPort = tonumber(data.aws_ssm_parameter.admin_server_port.value), # admin-server 포트
      hostPort      = tonumber(data.aws_ssm_parameter.admin_server_port.value)
    }],
    environment = [
      //{ name = "MANAGEMENT_HEALTH_PROBES_ENABLED", value = "true" },
      { name = "SPRING_PROFILES_ACTIVE", value = "mysql,aws" }
    ],
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.admin_server.name,
        "awslogs-region"        = var.aws_region,
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# 5. admin-server용 ECS Service
resource "aws_ecs_service" "admin_server" {
  name            = "admin-server"
  cluster         = module.ecs_cluster.cluster_id
  task_definition = aws_ecs_task_definition.admin_server.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  service_registries {
    registry_arn = module.cloudmap.service_arns["admin-server"]
  }

  network_configuration {
    subnets         = values(data.terraform_remote_state.network.outputs.private_app_subnet_ids)
    security_groups = [data.terraform_remote_state.security.outputs.app_security_group_id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.admin_server.arn
    container_name   = "admin-server"
    container_port   = tonumber(data.aws_ssm_parameter.admin_server_port.value) # admin-server 포트
  }

  depends_on = [aws_lb_listener_rule.admin_server]
}
