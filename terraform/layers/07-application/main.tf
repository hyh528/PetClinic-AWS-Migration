# =============================================================================
# Application Layer - 애플리케이션 인프라 (모듈 중심 설계)
# =============================================================================
# 목적: PetClinic의 4개 마이크로서비스를 위한 인프라 (모듈화된 접근 방식)
# 의존성: 01-network, 02-security, 03-database 레이어

# AWS 계정 정보
data "aws_caller_identity" "current" {}

# 공통 로컬 변수 (공유 변수 활용)

# =============================================================================
# Bastion Host 모듈 (조건부 생성)
# =============================================================================

module "debug_infrastructure" {
  source = "../../modules/debug-infrastructure"

  enable_debug_infrastructure = var.enable_debug_infrastructure

  name_prefix                       = var.name_prefix
  vpc_id                            = local.vpc_id
  public_subnet_ids                 = local.public_subnet_ids
  aurora_security_group_id          = local.aurora_security_group_id
  aws_region                        = var.aws_region
  db_cluster_endpoint               = data.terraform_remote_state.database.outputs.cluster_endpoint
  rds_secret_access_policy_arn      = local.rds_secret_access_policy_arn
  parameter_store_access_policy_arn = local.parameter_store_access_policy_arn

  tags = local.layer_common_tags
}

# Aurora 보안 그룹에 ECS 태스크 접근 허용 규칙 추가
resource "aws_security_group_rule" "aurora_allow_ecs" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = local.aurora_security_group_id
  source_security_group_id = local.ecs_security_group_id

  description = "Allow MySQL access from ECS tasks"
}

# ECS 태스크용 보안 그룹에 ALB 접근 허용 규칙 추가 (단일 규칙으로 모든 8080 포트 허용)
resource "aws_security_group_rule" "alb_to_ecs" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = local.ecs_security_group_id
  source_security_group_id = module.alb.alb_security_group_id

  description = "Allow ALB to access ECS tasks on port 8080"
}

# Admin 서비스용 9090 포트 ALB 접근 허용 규칙 추가
resource "aws_security_group_rule" "alb_to_ecs_admin" {
  type                     = "ingress"
  from_port                = 9090
  to_port                  = 9090
  protocol                 = "tcp"
  security_group_id        = local.ecs_security_group_id
  source_security_group_id = module.alb.alb_security_group_id

  description = "Allow ALB to access Admin service on port 9090 for health checks"
}

# ECS 서비스 간 통신 허용 (Admin 서버가 다른 서비스의 actuator에 접근하기 위해)
resource "aws_security_group_rule" "ecs_inter_service_8080" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  security_group_id = local.ecs_security_group_id
  self              = true

  description = "Allow ECS services to communicate with each other on port 8080 (for Admin to access service actuators)"
}

# ECS 서비스 간 통신 허용 - 9090 포트 (Admin 서버)
resource "aws_security_group_rule" "ecs_inter_service_9090" {
  type              = "ingress"
  from_port         = 9090
  to_port           = 9090
  protocol          = "tcp"
  security_group_id = local.ecs_security_group_id
  self              = true

  description = "Allow ECS services to communicate with Admin server on port 9090"
}

# =============================================================================
# Egress 규칙 (아웃바운드)
# =============================================================================

# Admin 서버가 ALB를 통해 다른 서비스의 actuator에 접근하기 위한 egress 규칙
# ALB의 공개 DNS를 통한 접근을 위해 모든 HTTP 트래픽 허용 (NAT Gateway를 통해 나감)
resource "aws_security_group_rule" "ecs_to_internet_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = local.ecs_security_group_id
  cidr_blocks       = ["0.0.0.0/0"]

  description = "Allow ECS to access internet on port 80 (for Admin to access ALB public DNS)"
}

# ECS 서비스 간 직접 통신을 위한 egress - 8080 포트
resource "aws_security_group_rule" "ecs_to_ecs_8080" {
  type              = "egress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  security_group_id = local.ecs_security_group_id
  self              = true

  description = "Allow ECS services to communicate with each other on port 8080"
}

# ECS 서비스 간 직접 통신을 위한 egress - 9090 포트
resource "aws_security_group_rule" "ecs_to_ecs_9090" {
  type              = "egress"
  from_port         = 9090
  to_port           = 9090
  protocol          = "tcp"
  security_group_id = local.ecs_security_group_id
  self              = true

  description = "Allow ECS services to communicate with Admin on port 9090"
}



# =============================================================================
# ECR 모듈 (각 서비스별 리포지토리)
# =============================================================================

module "ecr_services" {
  for_each = local.services

  source = "../../modules/ecr"

  repository_name = "${var.name_prefix}-${each.key}"
  tags = merge(local.layer_common_tags, {
    Service = each.key
  })
}

# Docker 이미지 관리는 CI 파이프라인으로 이동했습니다.
# 이 레이어는 빌드된 이미지를 외부(예: CI)에서 전달받아 사용합니다.
# 권장: GitHub Actions 등을 사용해 이미지 빌드 → ECR 푸시 → Terraform에는
# immutable tag(예: git SHA 또는 digest)를 제공하세요.

# Terraform에서 사용할 서비스 이미지 매핑은 변수 `var.service_image_map` 를 통해 주입됩니다.
# 예: { customers = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/petclinic-customers:sha-abc123" }

# =============================================================================
# ALB 모듈 (공통 로드 밸런서)
# =============================================================================

module "alb" {
  source = "../../modules/alb"

  name_prefix = var.name_prefix
  environment = var.environment

  vpc_id            = local.vpc_id
  public_subnet_ids = local.public_subnet_ids

  # Rate Limiting 및 보안 설정
  enable_waf_rate_limiting = var.enable_alb_rate_limiting
  rate_limit_per_ip        = var.alb_rate_limit_per_ip
  rate_limit_burst_per_ip  = var.alb_rate_limit_burst_per_ip
  enable_geo_blocking      = var.enable_geo_blocking
  blocked_countries        = var.blocked_countries
  enable_security_rules    = var.enable_security_rules

  # 모니터링 설정
  enable_waf_monitoring      = var.enable_waf_monitoring
  rate_limit_alarm_threshold = var.alb_rate_limit_alarm_threshold
  alarm_actions              = var.alarm_actions

  tags = local.layer_common_tags
}

# 각 서비스별 타겟 그룹 (ALB 모듈 외부에서 생성)
resource "aws_lb_target_group" "services" {
  for_each = local.services

  name        = "${var.name_prefix}-${each.key}"
  port        = each.value.port
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = each.value.health_path
    port                = each.value.port
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  tags = merge(local.layer_common_tags, {
    Service = each.key
  })
}

# 리스너 규칙 (경로 기반 라우팅)
resource "aws_lb_listener_rule" "services" {
  for_each = local.services

  listener_arn = module.alb.listener_http_arn
  priority     = 100 + index(keys(local.services), each.key)

  action {
    type = "forward"
    forward {
      target_group {
        arn = aws_lb_target_group.services[each.key].arn
      }
      stickiness {
        enabled  = false
        duration = 1
      }
    }
  }

  condition {
    path_pattern {
      values = each.key == "admin" ? ["/admin", "/admin/*"] : ["/api/${each.key}", "/api/${each.key}/*"]
    }
  }

  tags = merge(local.layer_common_tags, {
    Service = each.key
  })
}


# =============================================================================
# ECS 클러스터
# =============================================================================

resource "aws_ecs_cluster" "main" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.layer_common_tags
}

# CloudWatch 로그 그룹
resource "aws_cloudwatch_log_group" "services" {
  for_each = local.services

  name              = "/ecs/${var.name_prefix}-${each.key}"
  retention_in_days = local.log_retention_days

  tags = merge(local.layer_common_tags, {
    Service = each.key
  })
}

# =============================================================================
# ECS 서비스들 (각 마이크로서비스별)
# =============================================================================

resource "aws_ecs_task_definition" "services" {
  for_each = local.services

  family                   = "${var.name_prefix}-${each.key}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = data.terraform_remote_state.security.outputs.ecs_task_execution_role_arn
  task_role_arn            = data.terraform_remote_state.security.outputs.ecs_task_execution_role_arn

  container_definitions = templatefile("${path.module}/templates/container-definition.json.tpl", {
    service_name     = each.key
    image_uri        = lookup(var.service_image_map, each.key, "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.name_prefix}-${each.key}:latest")
    cpu              = each.value.cpu
    memory           = each.value.memory
    container_port   = each.value.port
    log_group_name   = aws_cloudwatch_log_group.services[each.key].name
    aws_region       = var.aws_region
    environment_vars = each.key == "admin" ? local.admin_environment : local.common_environment
    secrets          = each.key == "admin" ? local.admin_secrets : local.common_secrets
  })

  tags = merge(local.layer_common_tags, {
    Service = each.key
  })
}

resource "aws_ecs_service" "services" {
  for_each = local.services

  name            = "${var.name_prefix}-${each.key}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.services[each.key].arn
  desired_count   = 1

  launch_type = "FARGATE"

  network_configuration {
    subnets          = local.private_app_subnet_ids
    security_groups  = [local.ecs_security_group_id]
    assign_public_ip = false
  }

  # Enable execute command for debugging
  enable_execute_command = true

  # 헬스 체크 그레이스 기간 증가 (Spring Boot 시작 시간 고려)
  health_check_grace_period_seconds = 600

  load_balancer {
    target_group_arn = aws_lb_target_group.services[each.key].arn
    container_name   = each.key
    container_port   = each.value.port
  }

  tags = merge(local.layer_common_tags, {
    Service = each.key
  })

  depends_on = [aws_ecs_task_definition.services]
}

# =============================================================================
# Auto Scaling (선택사항 - 향후 확장 가능)
# =============================================================================

resource "aws_appautoscaling_target" "services" {
  for_each = local.services

  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.services[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu_scaling" {
  for_each = local.services

  name               = "${var.name_prefix}-${each.key}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.services[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.services[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.services[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
