# Spring PetClinic Microservices

## 🏗️ 아키텍처 개요

이 프로젝트는 Spring Boot 기반의 마이크로서비스 아키텍처로 구성된 PetClinic 애플리케이션입니다. AWS 클라우드 인프라를 Terraform으로 관리하며, 완전 자동화된 CI/CD 파이프라인을 제공합니다.

## 🚀 배포 방식

### 인프라 관리 (Terraform)
- **모든 AWS 리소스**: VPC, ECS, RDS, Lambda, S3, CloudFront 등
- **레이어 기반 배포**: 01-network → 02-security → 03-database → ... → 11-frontend
- **환경별 격리**: dev, staging, prod 환경 지원

### 애플리케이션 배포 (GitHub Actions)
- **프론트엔드**: 정적 파일 자동 S3 업로드 + CloudFront 캐시 무효화
- **백엔드**: Docker 이미지 빌드 + ECR 푸시 + ECS 롤링 업데이트
- **모니터링**: CloudTrail, CloudWatch 자동 구성

## 📋 전제 조건

- AWS CLI v2.x
- Terraform v1.5+
- Java 17
- Docker
- GitHub 계정 (Actions 사용시)

## 🛠️ 빠른 시작

### 1. 인프라 배포

```bash
# Terraform 초기화 및 배포
cd terraform
terraform init -backend-config=backend.hcl
terraform plan -var-file="envs/dev.tfvars"
terraform apply -var-file="envs/dev.tfvars"
```

### 2. 애플리케이션 배포

```bash
# GitHub Actions를 통한 자동 배포 (권장)
git add .
git commit -m "Deploy application"
git push origin main

# 또는 수동 배포
./scripts/deploy-frontend.sh dev
```

### 3. 서비스 확인

```bash
# 프론트엔드 URL 확인
terraform output -json | jq -r '.frontend_url.value'

# 백엔드 서비스 상태 확인
aws ecs list-services --cluster petclinic-dev-cluster
```

## 📁 프로젝트 구조

```
├── spring-petclinic-*/          # 마이크로서비스들
│   ├── customers-service
│   ├── vets-service
│   ├── visits-service
│   ├── api-gateway
│   └── admin-server
├── terraform/                   # 인프라 코드
│   ├── layers/                  # 레이어 기반 배포
│   ├── modules/                 # 재사용 가능한 모듈
│   └── envs/                    # 환경별 변수
├── .github/workflows/           # CI/CD 파이프라인
├── scripts/                     # 배포 스크립트
└── docs/                        # 문서
```

## 🔄 CI/CD 파이프라인

### 프론트엔드 배포
- **트리거**: `static/` 디렉토리 변경시 자동 실행
- **프로세스**: S3 동기화 → CloudFront 캐시 무효화
- **소요시간**: 약 2-3분

### 백엔드 배포
- **트리거**: 소스 코드 변경시 자동 실행
- **프로세스**: 빌드 → Docker 이미지 생성 → ECR 푸시 → ECS 업데이트
- **소요시간**: 약 10-15분

### 인프라 검증
- **트리거**: Terraform 코드 변경시 자동 실행
- **프로세스**: 포맷 체크 → 유효성 검증 → Plan 실행
- **소요시간**: 약 3-5분

## 🎯 주요 기능

### 마이크로서비스
- **고객 관리**: 고객 정보 CRUD
- **수의사 관리**: 수의사 정보 및 전문분야
- **방문 관리**: 진료 예약 및 기록
- **API 게이트웨이**: 통합 API 엔드포인트
- **관리 서버**: 서비스 모니터링

### AI 기능
- **GenAI 채팅**: Amazon Bedrock 기반 AI 어시스턴트
- **스마트 추천**: 머신러닝 기반 추천 시스템

### 모니터링
- **CloudWatch**: 메트릭, 로그, 알람
- **CloudTrail**: 감사 로그
- **X-Ray**: 분산 추적 (선택적)

## 🔧 환경 설정

### AWS 자격증명
```bash
aws configure
# 또는 환경변수 설정
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
export AWS_DEFAULT_REGION=us-west-2
```

### GitHub Secrets (Actions 사용시)
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `CLOUDFRONT_DISTRIBUTION_DEV`

## 📊 모니터링

### 대시보드 접근
```bash
# CloudWatch 대시보드 URL
terraform output dashboard_url
```

### 로그 확인
```bash
# ECS 로그
aws logs tail /ecs/petclinic-dev-customers --follow

# Lambda 로그
aws logs tail /aws/lambda/petclinic-dev-genai-function --follow
```

## 🧪 테스트

### 로컬 테스트
```bash
# Docker Compose로 로컬 실행
cd scripts/local-test
docker-compose up
```

### 통합 테스트
```bash
# GitHub Actions에서 자동 실행
# 또는 수동 실행
cd terraform/scripts/testing
python integration_test_runner.py
```

## 🔒 보안

- **VPC 격리**: 모든 리소스 프라이빗 서브넷
- **IAM 최소 권한**: 서비스별 세분화된 권한
- **암호화**: S3, RDS, CloudTrail 암호화
- **WAF**: CloudFront WAF 규칙 (선택적)

## 📚 추가 문서

- [인프라 배포 가이드](terraform/docs/INIT_GUIDE.md)
- [레이어 실행 순서](terraform/docs/LAYER_EXECUTION_ORDER.md)
- [네트워크 아키텍처](docs/network-architecture-guide.md)
- [다음 단계](docs/NEXT_STEPS_REALISTIC.md)

## 🤝 기여

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📝 라이선스

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.