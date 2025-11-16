# 07-Application 레이어 Terraform 베스트 프랙티스 분석

## 📊 현재 상태 평가

### ✅ 잘 구현된 부분 (Best Practices 준수)

#### 1. **모듈화 및 구조**
- ✅ **모듈 기반 설계**: ECR, ALB, debug-infrastructure 모듈 활용
- ✅ **레이어 분리**: 네트워크, 보안, 데이터베이스와 명확한 의존성 구조
- ✅ **파일 구조**: main.tf, variables.tf, outputs.tf, locals.tf, data.tf 표준 구조

#### 2. **상태 관리**
- ✅ **Remote State**: S3 백엔드 사용
- ✅ **State 참조**: terraform_remote_state로 레이어 간 데이터 공유
- ✅ **의존성 관리**: 명확한 레이어 의존성 (network → security → database → application)

#### 3. **리소스 관리**
- ✅ **태그 표준화**: 일관된 태그 전략 (layer_common_tags)
- ✅ **명명 규칙**: name_prefix 기반 일관된 명명
- ✅ **조건부 리소스**: enable_debug_infrastructure로 선택적 생성

#### 4. **보안**
- ✅ **최소 권한**: IAM 역할 분리 (execution_role, task_role)
- ✅ **네트워크 격리**: Private subnet에 ECS 배치
- ✅ **보안 그룹**: 명시적 보안 그룹 규칙
- ✅ **시크릿 관리**: Secrets Manager 통합

#### 5. **확장성**
- ✅ **멀티 서비스**: for_each로 여러 서비스 지원
- ✅ **Auto Scaling**: ECS 서비스 자동 확장 설정
- ✅ **로드 밸런싱**: ALB 기반 트래픽 분산

### ⚠️ 개선이 필요한 부분

#### 1. **코드 품질 및 유지보수성**

**문제점:**
```hcl
# 하드코딩된 값들
secrets = [
  {
    name      = "SPRING_DATASOURCE_PASSWORD"
    valueFrom = "arn:aws:secretsmanager:us-west-2:897722691159:secret:rds!cluster-a2e69195-87ba-46c7-beb9-f3cb45e32887-AOx2t1:password::"
  }
]

# 복잡한 인라인 JSON
container_definitions = jsonencode([...])  # 100+ 줄의 복잡한 JSON
```

**개선 방안:**
```hcl
# 1. 시크릿 ARN을 변수화
locals {
  db_secret_arn = data.terraform_remote_state.database.outputs.db_secret_arn
}

# 2. 컨테이너 정의를 별도 템플릿으로 분리
container_definitions = templatefile("${path.module}/templates/container-definition.json.tpl", {
  service_name = each.key
  image_uri    = lookup(var.service_image_map, each.key, "")
  # ... 기타 변수들
})
```

#### 2. **변수 관리**

**문제점:**
```hcl
# 사용되지 않는 변수들
variable "container_definitions" {
  # 실제로는 사용되지 않음
}

variable "repository_name" {
  # ECR 모듈에서 직접 생성하므로 불필요
}
```

**개선 방안:**
- 사용되지 않는 변수 제거
- 변수 그룹화 및 validation 추가

#### 3. **에러 처리 및 검증**

**문제점:**
```hcl
# 이미지 맵 검증 없음
image = lookup(var.service_image_map, each.key, null)  # null일 수 있음
```

**개선 방안:**
```hcl
# 변수 검증 추가
variable "service_image_map" {
  validation {
    condition = alltrue([
      for service in ["customers", "vets", "visits", "admin"] :
      contains(keys(var.service_image_map), service)
    ])
    error_message = "All required services must have image mappings."
  }
}
```

#### 4. **모니터링 및 관찰성**

**문제점:**
- CloudWatch 알람 부족
- 메트릭 수집 설정 미흡
- 로그 보존 정책 하드코딩

**개선 방안:**
```hcl
# CloudWatch 알람 추가
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  for_each = local.services
  
  alarm_name          = "${var.name_prefix}-${each.key}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ecs cpu utilization"
  
  dimensions = {
    ServiceName = aws_ecs_service.services[each.key].name
    ClusterName = aws_ecs_cluster.main.name
  }
}
```

## 🔧 권장 리팩토링 계획

### Phase 1: 즉시 개선 (1-2시간)

#### 1. 하드코딩 제거
```hcl
# locals.tf에 추가
locals {
  # 데이터베이스 시크릿 ARN을 동적으로 참조
  db_secret_arn = data.terraform_remote_state.database.outputs.db_secret_arn
  
  # 환경별 설정
  log_retention_days = var.environment == "prod" ? 90 : 30
  
  # 컨테이너 환경 변수 표준화
  common_environment = [
    {
      name  = "SPRING_PROFILES_ACTIVE"
      value = "mysql,aws"
    },
    {
      name  = "AWS_REGION"
      value = var.aws_region
    }
  ]
}
```

#### 2. 사용되지 않는 변수 정리
```hcl
# variables.tf에서 제거할 변수들
# - container_definitions
# - repository_name  
# - cluster_name
# - task_family
# - container_name
# - container_port
```

### Phase 2: 구조 개선 (2-4시간)

#### 1. 컨테이너 정의 템플릿화
```hcl
# templates/container-definition.json.tpl 생성
[
  {
    "name": "${service_name}",
    "image": "${image_uri}",
    "cpu": ${cpu},
    "memory": ${memory},
    "essential": true,
    "portMappings": [
      {
        "containerPort": ${container_port},
        "hostPort": ${container_port},
        "protocol": "tcp"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${log_group_name}",
        "awslogs-region": "${aws_region}",
        "awslogs-stream-prefix": "ecs"
      }
    },
    "environment": ${jsonencode(environment_vars)},
    "secrets": ${jsonencode(secrets)}
  }
]
```

#### 2. 변수 검증 강화
```hcl
variable "service_image_map" {
  description = "Service to image URI mapping"
  type        = map(string)
  
  validation {
    condition = alltrue([
      for service in keys(local.services) :
      contains(keys(var.service_image_map), service)
    ])
    error_message = "All services must have corresponding image URIs."
  }
  
  validation {
    condition = alltrue([
      for image_uri in values(var.service_image_map) :
      can(regex("^[0-9]+\\.dkr\\.ecr\\.", image_uri))
    ])
    error_message = "All image URIs must be valid ECR URLs."
  }
}
```

### Phase 3: 고급 기능 추가 (4-6시간)

#### 1. 모니터링 강화
```hcl
# monitoring.tf 파일 생성
resource "aws_cloudwatch_dashboard" "application" {
  dashboard_name = "${var.name_prefix}-application-dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            for service in keys(local.services) : [
              "AWS/ECS", "CPUUtilization", "ServiceName", 
              aws_ecs_service.services[service].name, "ClusterName", 
              aws_ecs_cluster.main.name
            ]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS CPU Utilization"
        }
      }
    ]
  })
}
```

#### 2. 보안 강화
```hcl
# 태스크 역할 분리
resource "aws_iam_role" "ecs_task_role" {
  for_each = local.services
  
  name = "${var.name_prefix}-${each.key}-task-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# 서비스별 최소 권한 정책
resource "aws_iam_role_policy" "service_specific" {
  for_each = local.services
  
  name = "${var.name_prefix}-${each.key}-policy"
  role = aws_iam_role.ecs_task_role[each.key].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/petclinic/${var.environment}/${each.key}/*"
      }
    ]
  })
}
```

## 📋 최종 베스트 프랙티스 체크리스트

### ✅ 현재 준수 중
- [x] 모듈 기반 아키텍처
- [x] Remote State 사용
- [x] 일관된 태그 전략
- [x] 네트워크 보안
- [x] 멀티 서비스 지원
- [x] Auto Scaling 설정

### 🔄 개선 필요
- [ ] 하드코딩 제거
- [ ] 변수 검증 강화
- [ ] 컨테이너 정의 템플릿화
- [ ] 모니터링 대시보드
- [ ] 서비스별 IAM 역할 분리
- [ ] 에러 처리 개선

### 🚀 고급 기능 (선택사항)
- [ ] Blue/Green 배포 지원
- [ ] Canary 배포 설정
- [ ] 서비스 메시 통합
- [ ] 비용 최적화 정책
- [ ] 재해 복구 계획

## 🎯 권장 우선순위

1. **즉시 (1-2시간)**: 하드코딩 제거, 사용되지 않는 변수 정리
2. **단기 (1-2일)**: 컨테이너 정의 템플릿화, 변수 검증 강화
3. **중기 (1주일)**: 모니터링 강화, 보안 개선
4. **장기 (1개월)**: 고급 배포 전략, 비용 최적화

## 결론

현재 07-application 레이어는 **Terraform 베스트 프랙티스의 80% 정도를 준수**하고 있습니다. 

**강점:**
- 모듈화된 구조
- 확장 가능한 설계
- 보안 고려사항 반영

**개선점:**
- 하드코딩 제거 (가장 우선)
- 모니터링 강화
- 에러 처리 개선

전체적으로 **프로덕션 환경에서 사용 가능한 수준**이며, 위의 개선사항들을 단계적으로 적용하면 **엔터프라이즈급 Terraform 코드**가 될 수 있습니다.