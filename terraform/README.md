# PetClinic AWS Infrastructure

이 프로젝트는 Spring PetClinic 애플리케이션을 위한 완전한 AWS 인프라를 Terraform으로 관리합니다.

## 🎉 **Phase 1 완료** (2025-01-10)

**업계 표준 Terraform 아키텍처로 완전히 재구성되었습니다!**

### ✅ **주요 개선사항**
- **업계 표준 Backend 관리**: backend.hcl 템플릿 방식 적용
- **레이어별 상태 분리**: 변경 범위 최소화 및 병렬 작업 가능
- **공유 변수 시스템**: DRY 원칙 적용으로 코드 중복 제거
- **도쿄 리전 테스트 환경**: 완전히 새로운 인프라 구축

### 🚀 **빠른 시작**
```powershell
# 레이어 초기화 (새로운 표준 방식)
./scripts/init-layer.ps1 -Environment dev -Layer "01-network"
```

📖 **자세한 사용법**: [Phase 1 사용법 가이드](docs/PHASE1_USAGE_GUIDE.md)

## 🏗️ 아키텍처 개요

PetClinic 애플리케이션은 마이크로서비스 아키텍처로 구성되어 있으며, AWS 네이티브 서비스들을 활용하여 고가용성, 확장성, 보안을 갖춘 인프라를 구축합니다.

### 주요 컴포넌트
- **Spring Boot 마이크로서비스**: customers, vets, visits, admin-server
- **API Gateway**: 통합 API 엔드포인트
- **ECS Fargate**: 컨테이너 오케스트레이션
- **Aurora MySQL**: 데이터베이스
- **Application Load Balancer**: 로드 밸런싱
- **CloudWatch**: 모니터링 및 로깅

## 📁 프로젝트 구조

```
terraform/
├── docs/                          # 문서 파일들
├── scripts/                       # 자동화 스크립트들
├── bootstrap/                     # 초기 설정 (S3, DynamoDB 등)
├── envs/                          # 환경별 설정
│   ├── dev/                       # 개발 환경
│   ├── staging/                   # 스테이징 환경
│   └── prod/                      # 프로덕션 환경
├── modules/                       # 재사용 가능한 모듈들
└── ci-cd/                         # CI/CD 설정
```

## 🚀 빠른 시작

### 사전 준비사항

1. **AWS CLI 및 Terraform 설치**
   ```bash
   # AWS CLI 설치
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install

   # Terraform 설치
   wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com jammy main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
   sudo apt update && sudo apt install terraform
   ```

2. **AWS 프로필 설정**
   ```bash
   aws configure --profile petclinic-admin
   ```

3. **관리자 프로필 설정**
   ```bash
   ./scripts/setup-admin-profile.sh
   ```

### 배포 실행

1. **환경별 배포**
   ```bash
   # 개발 환경 전체 배포
   ./scripts/apply-all.sh dev

   # 또는 개별 레이어 배포
   cd envs/dev/01-network
   terraform init
   terraform plan -var-file=../../../dev.tfvars
   terraform apply -var-file=../../../dev.tfvars
   ```

2. **계층적 배포 순서**
   - `01-network`: VPC, 서브넷, 보안 그룹
   - `02-security`: IAM 역할, 정책, 키 관리
   - `03-database`: Aurora MySQL 클러스터
   - `04-parameter-store`: 설정 및 시크릿 관리
   - `05-cloud-map`: 서비스 디스커버리
   - `06-lambda-genai`: AI Lambda 함수
   - `07-application`: ECS 클러스터 및 서비스
   - `08-api-gateway`: API Gateway 설정
   - `09-monitoring`: CloudWatch 모니터링
   - `10-aws-native`: 통합 설정


## 🔧 개발 환경 설정

### Pre-commit Hooks 설정
```bash
cd terraform
pip install pre-commit
pre-commit install
```

### 문서 자동 생성
```bash
./scripts/terraform-docs-gen.sh
```

## 🔍 검증 및 테스트

### 인프라 검증
```bash
# 전체 검증 실행
./scripts/validate-infrastructure.sh

# 네트워크 연결성 테스트
./scripts/test-network-connectivity.sh
```

### 보안 스캔
```bash
# 보안 스캔은 GitHub Actions에서 자동으로 실행됩니다
# PR 생성 시 자동으로 checkov와 tflint가 실행됨

# 로컬에서 기본 검증만 실행
terraform fmt -check -recursive
terraform validate
```

## 📊 모니터링 및 운영

### Drift 감지
```bash
# 수동 drift 감지
./scripts/drift-detect.sh dev

# 자동화된 drift 감지는 GitHub Actions에서 매일 실행
```

### 로그 및 메트릭
- **CloudWatch Logs**: 모든 서비스 로그 중앙화
- **CloudWatch Metrics**: 성능 및 상태 메트릭
- **CloudWatch Alarms**: 자동 알림 설정

## 🤝 기여 가이드

### 브랜치 전략
- `main`: 프로덕션 환경
- `staging`: 스테이징 환경
- `feature/*`: 기능 개발 브랜치

### 커밋 메시지 규칙
```bash
feat: 새로운 기능 추가
fix: 버그 수정
docs: 문서 업데이트
refactor: 코드 리팩토링
test: 테스트 추가
chore: 유지보수 작업
```

### PR 템플릿
PR 생성 시 다음 항목들을 포함해주세요:
- 변경 사항 설명
- 테스트 결과
- 영향 범위
- 롤백 계획

## 📚 추가 문서

- [실무형 구조 설명](docs/LAYER_EXECUTION_ORDER.md)
- [AWS 프로필 전략](docs/AWS_PROFILE_STRATEGY.md)
- [관리자 프로필 사용법](docs/ADMIN_PROFILE_USAGE.md)
- [빠른 시작 가이드](docs/QUICK_START.md)
- [검증 가이드](docs/VALIDATION_GUIDE.md)
- [도쿄 리전 테스트](docs/TOKYO_TEST_GUIDE.md)

## 🆘 문제 해결

### 일반적인 문제들

1. **Terraform State 잠금**
   ```bash
   # 강제 잠금 해제 (주의: 동시 작업 시 데이터 손실 가능)
   terraform force-unlock LOCK_ID
   ```

2. **AWS 권한 문제**
   ```bash
   # 프로필 확인
   aws sts get-caller-identity --profile petclinic-admin
   ```

3. **리소스 종속성 오류**
   - 레이어 실행 순서를 확인하세요
   - 이전 레이어의 output을 확인하세요

## 📞 지원

문의사항이나 문제가 발생하면 다음 채널을 이용해주세요:
- **이슈**: GitHub Issues
- **토론**: GitHub Discussions
- **문서**: Wiki

---

## 🎯 다음 단계

- [ ] CI/CD 파이프라인 최적화
- [ ] 비용 최적화 자동화
- [ ] 다중 리전 배포 지원
- [ ] IaC 테스트 자동화 강화