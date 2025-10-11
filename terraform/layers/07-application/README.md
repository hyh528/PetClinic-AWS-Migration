# 07-Application Layer

## 개요

애플리케이션 인프라를 관리하는 레이어입니다. 단일 책임 원칙(SRP)을 적용하여 ECR, ALB, ECS 모듈을 분리하고, 각각의 책임을 명확히 구분했습니다.

## 아키텍처

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   ECR Module    │    │   ALB Module    │    │   ECS Module    │
│                 │    │                 │    │                 │
│ - 이미지 저장소  │    │ - 로드 밸런싱    │    │ - 컨테이너 실행  │
│ - 라이프사이클   │    │ - 헬스체크      │    │ - Auto Scaling  │
│ - 보안 스캔     │    │ - SSL 종료      │    │ - 서비스 관리   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 주요 기능

### ECR (Elastic Container Registry)
- **단일 책임**: Docker 이미지 저장 및 관리
- 이미지 스캔 활성화 (보안 취약점 검사)
- 라이프사이클 정책 (최근 10개 이미지 유지)
- 태그 기반 이미지 관리

### ALB (Application Load Balancer)
- **단일 책임**: 트래픽 분산 및 라우팅
- 퍼블릭 서브넷에 배치
- 헬스체크 설정 (`/actuator/health`)
- 보안 그룹 통합

### ECS (Elastic Container Service)
- **단일 책임**: 컨테이너 오케스트레이션
- Fargate 기반 서버리스 컨테이너
- Auto Scaling (CPU/메모리 기반)
- 프라이빗 서브넷에 배치
- X-Ray 사이드카 제거 (단순화)

## 의존성

이 레이어는 다음 레이어들에 의존합니다:

1. **01-network**: VPC, 서브넷 정보
2. **02-security**: 보안 그룹, IAM 역할
3. **03-database**: 데이터베이스 연결 정보 (선택적)

## 사용법

### 1. 초기화
```bash
cd terraform/layers/07-application
terraform init -backend-config="../../envs/dev/backend.hcl"
```

### 2. 계획 확인
```bash
terraform plan -var-file="../../envs/dev/terraform.tfvars"
```

### 3. 배포
```bash
terraform apply -var-file="../../envs/dev/terraform.tfvars"
```

## 주요 변수

| 변수명 | 설명 | 기본값 | 필수 |
|--------|------|--------|------|
| `name_prefix` | 리소스 이름 접두사 | - | ✅ |
| `environment` | 배포 환경 | - | ✅ |
| `container_name` | 컨테이너 이름 | `petclinic-app` | ❌ |
| `container_port` | 컨테이너 포트 | `8080` | ❌ |
| `desired_count` | 원하는 태스크 수 | `2` | ❌ |
| `enable_autoscaling` | Auto Scaling 활성화 | `true` | ❌ |
| `cpu_target_value` | CPU 목표값 (%) | `70` | ❌ |
| `memory_target_value` | 메모리 목표값 (%) | `80` | ❌ |

## 출력값

### ALB 관련
- `alb_dns_name`: ALB DNS 이름
- `alb_arn`: ALB ARN
- `target_group_arn`: 타겟 그룹 ARN

### ECR 관련
- `ecr_repository_url`: ECR 리포지토리 URL
- `ecr_repository_arn`: ECR 리포지토리 ARN

### ECS 관련
- `ecs_cluster_name`: ECS 클러스터 이름
- `ecs_service_name`: ECS 서비스 이름
- `ecs_task_definition_arn`: 태스크 정의 ARN

### 통합 정보
- `application_url`: 애플리케이션 접근 URL
- `health_check_url`: 헬스체크 URL
- `deployment_info`: 배포 관련 종합 정보

## 개선사항

### ✅ 완료된 개선사항
1. **단일 책임 원칙 적용**: ECR, ALB, ECS 모듈 분리
2. **공유 변수 시스템 적용**: 하드코딩 제거
3. **X-Ray 사이드카 제거**: 컨테이너 정의 단순화
4. **Auto Scaling 설정**: CPU/메모리 기반 자동 확장
5. **헬스체크 개선**: 컨테이너 레벨 헬스체크 추가
6. **보안 강화**: 이미지 스캔, 라이프사이클 정책

### 🔄 향후 개선 계획
1. **Blue-Green 배포**: 무중단 배포 지원
2. **Service Mesh**: Istio/App Mesh 통합
3. **Observability**: Prometheus/Grafana 통합
4. **Cost Optimization**: Spot 인스턴스 활용

## 모니터링

### CloudWatch 메트릭
- ECS 서비스 CPU/메모리 사용률
- ALB 요청 수 및 응답 시간
- 타겟 그룹 헬스체크 상태

### 로그
- ECS 태스크 로그: `/ecs/{name_prefix}-{environment}-app`
- ALB 액세스 로그 (선택적)

## 문제 해결

### 일반적인 문제
1. **서비스 시작 실패**: 헬스체크 경로 확인
2. **이미지 Pull 실패**: ECR 권한 확인
3. **로드 밸런서 연결 실패**: 보안 그룹 규칙 확인

### 디버깅 명령어
```bash
# ECS 서비스 상태 확인
aws ecs describe-services --cluster {cluster_name} --services {service_name}

# 태스크 로그 확인
aws logs get-log-events --log-group-name "/ecs/{name_prefix}-{environment}-app"

# ALB 타겟 상태 확인
aws elbv2 describe-target-health --target-group-arn {target_group_arn}
```

## 태그 전략

모든 리소스에는 다음 태그가 자동으로 적용됩니다:

```hcl
{
  Environment = var.environment
  Layer       = "07-application"
  Component   = "application-infrastructure"
  ManagedBy   = "terraform"
  # + 사용자 정의 태그 (var.tags)
}
```