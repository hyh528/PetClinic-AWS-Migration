# Terraform ECS 구성 리팩토링 요약 (2025-10-12)

## 목표
- 기존에 제안된 ECS 구성을 Terraform 모범 사례에 맞게 리팩토링.
- 여러 마이크로서비스가 **공유하는 리소스**와 각 **서비스별 리소스**를 명확히 분리하여 재사용성과 확장성을 높이는 것을 목표로 함.

## 리팩토링 전략
- **공유 리소스**는 `application` 레이어(`terraform/envs/dev/application/`)에서 한 번만 생성.
- **서비스별 리소스**는 `ecs` 모듈(`terraform/modules/ecs/`)이 각 서비스마다 생성하도록 역할을 분리.

---

### 1단계: `application` 레이어에 공유 리소스 생성

`terraform/envs/dev/application/` 디렉터리에 공유 리소스를 정의하는 파일을 새로 만듭니다.

<details>
<summary><b>📄 terraform/envs/dev/application/cluster.tf</b></summary>

```terraform
# terraform/envs/dev/application/cluster.tf

resource "aws_ecs_cluster" "main" {
  name = "petclinic-cluster"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "petclinic-ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
```
</details>

<details>
<summary><b>📄 terraform/envs/dev/application/alb.tf</b></summary>

```terraform
# terraform/envs/dev/application/alb.tf

resource "aws_lb" "main" {
  name               = "petclinic-main-alb"
  internal           = false
  load_balancer_type = "application"
  # security 레이어에서 가져온 ALB 보안 그룹 ID 사용
  security_groups    = [data.terraform_remote_state.security.outputs.alb_security_group_id]
  # network 레이어에서 가져온 Public Subnet ID들 사용
  subnets            = values(data.terraform_remote_state.network.outputs.public_subnet_ids)

  tags = {
    Name = "petclinic-main-alb"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # default_action: 어떤 리스너 규칙과도 맞지 않을 때 기본적으로 수행할 동작
  # 여기서는 404 Not Found 응답을 보냅니다.
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Cannot route request."
      status_code  = "404"
    }
  }
}
```
</details>

---

### 2단계: `ecs` 모듈 리팩토링

`ecs` 모듈이 서비스별 리소스 생성에만 집중하도록 수정합니다.

<details>
<summary><b>📄 terraform/modules/ecs/variables.tf (수정 후)</b></summary>

```terraform
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
vartable "cluster_id" {
  description = "사용할 ECS 클러스터의 ID"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ECS Task 실행 역할의 ARN"
  type        = string
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
  default     = "256"
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
```
</details>

<details>
<summary><b>📄 terraform/modules/ecs/main.tf (수정 후)</b></summary>

```terraform
# 1. CloudWatch Log Group (서비스별 로그)
resource "aws_cloudwatch_log_group" "service" {
  name              = "/ecs/petclinic/${var.service_name}"
  retention_in_days = 7
}

# 2. Target Group (서비스별로 생성)
resource "aws_lb_target_group" "service" {
  name        = "tg-${var.service_name}"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/actuator/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# 3. Listener Rule (서비스별로 생성)
resource "aws_lb_listener_rule" "service" {
  listener_arn = var.listener_arn # application 레이어에서 전달받음
  priority     = var.listener_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service.arn
  }

  condition {
    path_pattern {
      # 예: /customers-service/* 요청을 이 서비스로 라우팅
      values = ["/${var.service_name}/*"]
    }
  }
}

# 4. ECS Task Definition (서비스별 청사진)
resource "aws_ecs_task_definition" "service" {
  family                   = "${var.service_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.ecs_task_execution_role_arn # application 레이어에서 전달받음

  container_definitions = jsonencode([{
    name      = var.service_name,
    image     = var.image_uri,
    cpu       = tonumber(var.task_cpu),
    memory    = tonumber(var.task_memory),
    essential = true,
    portMappings = [{
      containerPort = var.container_port,
      hostPort      = var.container_port
    }],
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.service.name,
        "awslogs-region"        = var.aws_region,
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# 5. ECS Service (서비스 실행 및 관리)
resource "aws_ecs_service" "service" {
  name            = var.service_name
  cluster         = var.cluster_id # application 레이어에서 전달받음
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.ecs_service_sg_id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.service.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener_rule.service]
}
```
</details>

---

### 3단계: `application` 레이어에서 모듈 호출 수정

`main.tf`에서 공유 리소스의 값을 `ecs` 모듈에 전달하도록 수정합니다.

<details>
<summary><b>📄 terraform/envs/dev/application/main.tf (수정 후)</b></summary>

```terraform
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
}

# 기존 cloudmap, ecr 모듈은 그대로 둡니다.
# ...
```
</details>

---

## 리팩토링 후 기대효과
- **명확한 역할 분리**: 공유 인프라와 애플리케이션 서비스의 책임이 코드 수준에서 명확해짐.
- **확장성 향상**: 새로운 마이크로서비스를 추가할 때, `locals` 맵에 서비스 정보를 한 줄 추가하는 것만으로 배포가 가능해짐.
- **재사용성 증가**: `ecs` 모듈이 특정 환경에 종속되지 않고, 필요한 값만 주입받아 동작하는 순수한 서비스 배포 모듈이 됨.

## 다음 단계
- 리팩토링된 코드를 `terraform plan` 및 `apply` 명령어를 통해 실제 AWS 환경에 배포.