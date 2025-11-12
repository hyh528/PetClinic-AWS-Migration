# ALB와 ECS 연결 방법 (기본틀)

이 문서는 Terraform에서 Application Load Balancer(ALB)와 ECS 서비스를 연결하는 기본적인 구조와 원리를 설명합니다.

## 1. 기본 개념

ALB와 ECS 서비스는 직접적으로 연결되지 않습니다. 상위 모듈(예: `application` 레이어)에서 두 리소스를 생성하고, **리스너 규칙(Listener Rule)**을 통해 연결해주는 '접착제' 역할이 필요합니다.

**전체 데이터 흐름:**

`외부 요청` -> `ALB` -> `ALB 리스너` -> `ALB 리스너 규칙` -> `ALB 타겟 그룹` -> `ECS 서비스`

- **ALB (Application Load Balancer)**: 외부 트래픽을 수신하는 로드 밸런서.
- **ALB 리스너 (Listener)**: 특정 포트(예: 80, 443)에서 연결을 확인하는 프로세스.
- **ALB 리스너 규칙 (Listener Rule)**: 리스너에 도달한 트래픽을 어떤 타겟 그룹으로 보낼지 결정하는 규칙. (예: URL 경로가 `/users/*`이면 user-service-tg로 전달)
- **ALB 타겟 그룹 (Target Group)**: 요청을 전달할 대상(ECS 태스크 등)의 그룹.
- **ECS 서비스 (ECS Service)**: 실제 애플리케이션 컨테이너를 실행하고 관리.

---

## 2. Terraform 코드 기본 구조

연결을 위해서는 **공유 리소스**와 **서비스별 리소스**를 분리하여 생각해야 합니다.

- **공유 리소스**: ALB, 리스너 (보통 `application` 레이어의 `alb.tf` 같은 파일에 정의)
- **서비스별 리소스**: 타겟 그룹, 리스너 규칙, ECS 서비스 (보통 `ecs` 모듈 내부에 정의)

### 1단계: 공유 리소스 생성 (`application` 레이어)

모든 서비스가 공유할 ALB와 기본 리스너를 생성합니다.

**파일 예시: `terraform/envs/dev/application/alb.tf`**
```terraform
# 1. 메인 ALB 생성
resource "aws_lb" "main" {
  name               = "petclinic-main-alb"
  load_balancer_type = "application"
  subnets            = data.terraform_remote_state.network.outputs.public_subnet_ids
  security_groups    = [data.terraform_remote_state.security.outputs.alb_security_group_id]
}

# 2. 기본 리스너 생성 (HTTP:80)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  # 일치하는 규칙이 없을 때의 기본 동작
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Cannot route request"
      status_code  = "404"
    }
  }
}
```

### 2단계: `ecs` 모듈에서 서비스별 리소스 생성 및 연결

`ecs` 모듈은 `application` 레이어로부터 **`listener_arn`**을 전달받아, 서비스에 필요한 타겟 그룹과 리스너 규칙을 생성합니다.

**파일 예시: `terraform/modules/ecs/main.tf`**
```terraform
# 1. 서비스별 타겟 그룹 생성
resource "aws_lb_target_group" "service" {
  name        = "tg-${var.service_name}"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  # ... 헬스 체크 등 ...
}

# 2. 서비스별 리스너 규칙 생성 (★핵심 연결 부분★)
resource "aws_lb_listener_rule" "service" {
  # application 레이어에서 전달받은 리스너 ARN
  listener_arn = var.listener_arn 
  
  # 서비스마다 겹치지 않는 고유한 우선순위
  priority     = var.listener_priority

  # 동작: 이 규칙에 맞으면, 위에서 만든 타겟 그룹으로 트래픽을 전달
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service.arn
  }

  # 조건: 어떤 요청이 이 규칙에 해당하는가? (경로 기반)
  condition {
    path_pattern {
      values = ["/${var.service_name}/*"]
    }
  }
}

# 3. ECS 서비스 생성
resource "aws_ecs_service" "service" {
  # ... (생략) ...
  
  # 이 서비스가 어떤 로드 밸런서와 연결되는지 지정
  load_balancer {
    target_group_arn = aws_lb_target_group.service.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }
}
```

### 3단계: `application` 레이어에서 `ecs` 모듈 호출

`for_each`를 사용하여 여러 서비스를 배포하고, 각 서비스에 공유 리소스 정보(`listener_arn` 등)를 전달합니다.

**파일 예시: `terraform/envs/dev/application/ecs.tf`**
```terraform
module "ecs" {
  for_each = local.ecs_services
  source   = "../../../modules/ecs"

  # --- 공유 리소스 값 전달 ---
  cluster_id   = aws_ecs_cluster.main.id
  listener_arn = aws_lb_listener.http.arn # ★ 1단계에서 만든 리스너 ARN 전달

  # --- 서비스별 값 전달 ---
  service_name      = each.key
  container_port    = each.value.container_port
  listener_priority = each.value.priority
  
  # ... 기타 등등 ...
}
```

---

## 3. 요약

1.  `application` 레이어에서 **ALB와 리스너**를 만든다.
2.  `ecs` 모듈을 호출할 때, 위에서 만든 **리스너의 ARN**을 `listener_arn` 변수로 전달한다.
3.  `ecs` 모듈 내부에서는 전달받은 `listener_arn`을 사용하여 **리스너 규칙**을 생성하고, "특정 경로의 요청은 우리 서비스의 타겟 그룹으로 보내라"고 ALB에 등록한다.

이 구조를 통해 ALB와 ECS 서비스 간의 연결이 완성됩니다.
