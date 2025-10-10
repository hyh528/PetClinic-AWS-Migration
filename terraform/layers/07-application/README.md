# 07-application 레이어

## 개요

애플리케이션 인프라를 관리하는 레이어입니다. ECR, ALB, ECS 모듈을 통해 컨테이너 기반 애플리케이션 플랫폼을 구성합니다.

## 구성 요소

### ECR (Elastic Container Registry)
- Docker 이미지 저장소
- 이미지 스캔 및 라이프사이클 정책 적용
- 최신 10개 이미지만 보존

### ALB (Application Load Balancer)
- HTTP/HTTPS 트래픽 로드 밸런싱
- 퍼블릭 서브넷에 배치
- 헬스체크 경로: `/actuator/health`

### ECS (Elastic Container Service)
- Fargate 기반 컨테이너 실행 환경
- 프라이빗 서브넷에 배치
- ALB와 통합된 서비스 디스커버리

## 의존성

이 레이어는 다음 레이어들에 의존합니다:

1. **01-network**: VPC, 서브넷 정보
2. **02-security**: 보안 그룹, IAM 역할
3. **03-database**: 데이터베이스 연결 정보

## 실행 방법

```bash
# 레이어 디렉토리로 이동
cd terraform/layers/07-application

# Terraform 초기화
terraform init

# 계획 확인
terraform plan -var-file="../../envs/dev.tfvars"

# 적용
terraform apply -var-file="../../envs/dev.tfvars"
```

## 출력값

- `alb_dns_name`: ALB DNS 이름 (애플리케이션 접근 URL)
- `ecr_repository_url`: ECR 리포지토리 URL (Docker 이미지 푸시용)
- `ecs_cluster_name`: ECS 클러스터 이름
- `ecs_service_name`: ECS 서비스 이름

## 주요 특징

### 단일 책임 원칙 적용
- ECR: 이미지 저장소 관리
- ALB: 로드 밸런싱
- ECS: 컨테이너 실행

### 단순화된 구성
- 기본적인 컨테이너 설정만 포함
- 복잡한 X-Ray 설정 제거
- 표준 Spring Boot 애플리케이션 지원

### 보안 고려사항
- 프라이빗 서브넷에서 컨테이너 실행
- 최소 권한 IAM 역할 사용
- 보안 그룹을 통한 네트워크 격리

## 태그 전략

모든 리소스에 다음 태그가 적용됩니다:
- `Layer`: 07-application
- `Component`: application-infrastructure
- `Purpose`: container-platform
- 공통 태그 (Environment, Project 등)