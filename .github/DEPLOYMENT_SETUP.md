# GitHub Actions 배포 설정 가이드

## 🚀 개요

이 문서는 PetClinic AWS 마이그레이션 프로젝트의 GitHub Actions CI/CD 파이프라인 설정 방법을 설명합니다.

## 📋 워크플로우 구조

### 1. 기본 빌드 및 테스트
- **파일**: `.github/workflows/maven-build.yml`
- **트리거**: PR 생성/업데이트, main/develop 브랜치 푸시
- **목적**: 코드 품질 검증, 단위 테스트 실행

### 2. Terraform 인프라 배포
- **파일**: `.github/workflows/terraform-infrastructure.yml`
- **트리거**: terraform/ 경로 변경 시, 수동 실행
- **목적**: AWS 인프라 자동 배포

### 3. Lambda 함수 배포
- **파일**: `.github/workflows/lambda-deployment.yml`
- **트리거**: Lambda 코드 변경 시, 수동 실행
- **목적**: GenAI Lambda 함수 배포 및 버전 관리

### 4. Spring Boot 애플리케이션 배포
- **파일**: `.github/workflows/application-deployment.yml`
- **트리거**: 애플리케이션 코드 변경 시, 수동 실행
- **목적**: ECS 서비스 배포

### 5. 통합 배포
- **파일**: `.github/workflows/full-deployment.yml`
- **트리거**: 수동 실행만
- **목적**: 전체 시스템 순차 배포

## 🔧 필수 설정

### 1. GitHub Secrets 설정

Repository Settings > Secrets and variables > Actions에서 다음 시크릿을 설정하세요:

```bash
# AWS 인증 정보
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_ROLE_TO_ASSUME=arn:aws:iam::339713019108:role/GitHubActionsRole (선택사항)

# 기타 설정
REGISTRY_URL=339713019108.dkr.ecr.ap-northeast-2.amazonaws.com
```

### 2. GitHub Environments 설정

Repository Settings > Environments에서 다음 환경을 생성하세요:

#### Development Environment
- **이름**: `dev`
- **보호 규칙**: 없음 (자동 배포)
- **환경 변수**:
  ```
  AWS_REGION=ap-northeast-2
  ENVIRONMENT=dev
  ```

#### Staging Environment
- **이름**: `staging`
- **보호 규칙**: 
  - Required reviewers: 1명 이상
  - Wait timer: 5분
- **환경 변수**:
  ```
  AWS_REGION=ap-northeast-2
  ENVIRONMENT=staging
  ```

#### Production Environment
- **이름**: `prod`
- **보호 규칙**:
  - Required reviewers: 2명 이상
  - Wait timer: 30분
  - Restrict to specific branches: `main`
- **환경 변수**:
  ```
  AWS_REGION=ap-northeast-2
  ENVIRONMENT=prod
  ```

### 3. AWS IAM 역할 설정 (OIDC 방식 - 권장)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::339713019108:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:hyh528/PetClinic-AWS-Migration:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

## 🎯 배포 시나리오

### 시나리오 1: 개발 환경 전체 배포
```bash
# GitHub Actions > Full System Deployment 워크플로우 실행
Environment: dev
Deployment Type: infrastructure_and_apps
Force Rebuild: false
```

### 시나리오 2: 애플리케이션만 업데이트
```bash
# 코드 변경 후 main 브랜치에 푸시
git add .
git commit -m "feat: 고객 서비스 기능 개선"
git push origin main

# 또는 수동으로 Application Deployment 워크플로우 실행
Environment: dev
Services: customers-service,vets-service
```

### 시나리오 3: Lambda 함수만 업데이트
```bash
# Lambda 코드 변경 후 푸시
git add terraform/modules/lambda-genai/lambda_function.py
git commit -m "feat: GenAI 응답 로직 개선"
git push origin main

# 또는 수동으로 Lambda Deployment 워크플로우 실행
```

### 시나리오 4: 인프라 변경
```bash
# Terraform 코드 변경 후 푸시
git add terraform/
git commit -m "feat: Aurora 인스턴스 타입 변경"
git push origin main

# 또는 수동으로 Terraform Infrastructure 워크플로우 실행
```

## 🔍 모니터링 및 디버깅

### 1. 배포 상태 확인
- GitHub Actions 탭에서 워크플로우 실행 상태 확인
- AWS Console에서 리소스 상태 확인
- CloudWatch Logs에서 애플리케이션 로그 확인

### 2. 배포 실패 시 대응
1. **빌드 실패**: 로그 확인 후 코드 수정
2. **Terraform 실패**: AWS 권한 및 리소스 상태 확인
3. **ECS 배포 실패**: 태스크 정의 및 서비스 상태 확인
4. **Lambda 배포 실패**: 함수 코드 및 권한 확인

### 3. 롤백 방법
```bash
# ECS 서비스 롤백
aws ecs update-service \
  --cluster petclinic-cluster-dev \
  --service petclinic-customers-dev \
  --task-definition petclinic-customers-dev:PREVIOUS_REVISION

# Lambda 함수 롤백
aws lambda update-alias \
  --function-name petclinic-genai-service-dev \
  --name LIVE \
  --function-version PREVIOUS_VERSION
```

## 📊 성능 최적화

### 1. 빌드 시간 단축
- Maven 의존성 캐싱 활용
- Docker 레이어 캐싱 활용
- 병렬 빌드 설정

### 2. 배포 시간 단축
- 변경된 서비스만 배포
- Blue-Green 배포 전략 활용
- 헬스체크 최적화

### 3. 비용 최적화
- 개발 환경 자동 종료 스케줄링
- Spot 인스턴스 활용
- 불필요한 리소스 정리

## 🔒 보안 고려사항

### 1. 시크릿 관리
- GitHub Secrets 사용
- AWS Secrets Manager 통합
- 환경별 시크릿 분리

### 2. 권한 관리
- 최소 권한 원칙 적용
- 환경별 IAM 역할 분리
- 정기적인 권한 검토

### 3. 코드 보안
- 의존성 취약점 스캔
- 코드 정적 분석
- 컨테이너 이미지 스캔

## 🚨 문제 해결

### 자주 발생하는 문제

1. **AWS 권한 부족**
   ```
   해결: IAM 정책 확인 및 권한 추가
   ```

2. **Terraform 상태 잠금**
   ```bash
   # DynamoDB에서 잠금 해제
   aws dynamodb delete-item \
     --table-name terraform-state-lock \
     --key '{"LockID":{"S":"terraform-state-dev"}}'
   ```

3. **ECS 서비스 업데이트 실패**
   ```
   해결: 태스크 정의 검증, 리소스 할당량 확인
   ```

4. **Docker 이미지 빌드 실패**
   ```
   해결: Dockerfile 검증, 의존성 확인
   ```

## 📞 지원

문제가 발생하면 다음을 확인하세요:

1. GitHub Actions 로그
2. AWS CloudWatch Logs
3. AWS CloudTrail (권한 관련)
4. 이 문서의 문제 해결 섹션

추가 지원이 필요하면 팀 Slack 채널 또는 이슈를 생성해주세요.