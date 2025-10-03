# ==========================================
# ECS (Elastic Container Service) 모듈
# ==========================================
# 컨테이너 실행 환경을 관리하는 모듈
# 컨테이너 실행 책임 분리

# ECS 클러스터 생성
resource "aws_ecs_cluster" "this" {
  name = var.cluster_name

  # 모니터링 활성화: CloudWatch Container Insights
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.tags, {
    Component = "ecs-cluster"
    Purpose   = "container-orchestration"
  })
}

# ECS 태스크 정의
resource "aws_ecs_task_definition" "this" {
  family                   = var.task_family
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn           = var.task_role_arn

  container_definitions = var.container_definitions

  tags = merge(var.tags, {
    Component = "ecs-task-definition"
    Purpose   = "container-configuration"
  })
}

# CloudWatch 로그 그룹
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.task_family}"
  retention_in_days = 30

  tags = merge(var.tags, {
    Component = "cloudwatch-logs"
    Purpose   = "application-monitoring"
  })
}

# ECS 서비스
resource "aws_ecs_service" "this" {
  name            = "${var.task_family}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count

  launch_type = "FARGATE"

  network_configuration {
    subnets          = var.subnets
    security_groups  = var.security_groups
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  # 배포 전략: 기본 롤링 업데이트 사용

  tags = merge(var.tags, {
    Component = "ecs-service"
    Purpose   = "container-deployment"
  })
}