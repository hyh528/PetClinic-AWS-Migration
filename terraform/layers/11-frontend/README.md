# Frontend Layer - 완전 자동화된 S3 + CloudFront 호스팅

## 🎯 목적
Spring PetClinic 프론트엔드를 S3와 CloudFront로 호스팅하며, GitHub Actions를 통한 완전 자동 배포를 지원합니다.

## 🚀 배포 방법

### 방법 1: 완전 자동 배포 (권장)

#### 1. GitHub Actions 설정
```bash
# GitHub Repository → Settings → Secrets and variables → Actions
# 다음 Secrets 추가:
# AWS_ACCESS_KEY_ID: your_aws_key
# AWS_SECRET_ACCESS_KEY: your_aws_secret
# CLOUDFRONT_DISTRIBUTION_DEV: ECU0OIUYY0NGN
```

#### 2. 자동 배포 트리거
```bash
# 프론트엔드 파일 변경 후 push
echo "변경사항" >> spring-petclinic-api-gateway/src/main/resources/static/index.html
git add .
git commit -m "Update frontend"
git push origin main

# → GitHub Actions가 자동으로 실행됨:
#   1. S3 버킷으로 파일 동기화
#   2. CloudFront 캐시 무효화
#   3. 배포 완료 알림
```

### 방법 2: 수동 배포

#### 1. 인프라 배포
```bash
cd terraform/layers/11-frontend
terraform init -backend-config=backend.config
terraform apply -var-file="../../envs/dev.tfvars"
```

#### 2. 파일 업로드 스크립트 사용
```bash
# 배포 스크립트 실행 (자동 캐시 무효화 포함)
../../scripts/deploy-frontend.sh dev

# 또는 수동으로 AWS CLI 사용
aws s3 sync ../../../spring-petclinic-api-gateway/src/main/resources/static/ s3://petclinic-dev-frontend-dev/ --delete
aws cloudfront create-invalidation --distribution-id ECU0OIUYY0NGN --paths '/*'
```

## 🔄 CI/CD 자동화 상세

### GitHub Actions 워크플로우
- **파일**: `.github/workflows/deploy-frontend.yml`
- **트리거 조건**:
  - `main` 브랜치 push (프론트엔드 파일 변경시)
  - Pull Request 생성 (변경사항 미리보기)
  - 수동 실행 (workflow_dispatch)

### 자동화 프로세스
1. **파일 변경 감지**: `static/` 폴더 내 파일 변경시 트리거
2. **AWS 인증**: GitHub Secrets를 통한 자동 인증
3. **S3 동기화**: `--delete` 옵션으로 변경사항만 업로드
4. **캐시 무효화**: CloudFront 캐시 즉시 갱신
5. **결과 보고**: 배포 성공/실패 및 URL 알림

### 배포 시간
- **평균 소요시간**: 2-3분
- **캐시 무효화**: 최대 15분 (글로벌 적용)

## 📋 주요 출력 정보

배포 완료 후 확인할 수 있는 정보:
- `frontend_url`: 프론트엔드 접속 URL (CloudFront)
- `s3_bucket_name`: S3 버킷 이름
- `upload_command`: 수동 업로드용 AWS CLI 명령어
- `cache_invalidation_command`: 수동 캐시 무효화 명령어
- `deployment_complete`: 배포 완료 요약 정보

## 💡 사용 팁

### 자동 배포 활용
1. **코드 변경**: 로컬에서 파일 수정 후 push만 하면 자동 배포
2. **배포 상태 확인**: GitHub Actions 탭에서 실시간 모니터링
3. **롤백**: 이전 커밋으로 revert 후 재배포

### 수동 배포 활용
1. **긴급 배포**: 스크립트로 즉시 배포
2. **테스트 배포**: staging 환경으로 먼저 배포
3. **디버깅**: `--dry-run` 옵션으로 변경사항 미리보기

### 성능 최적화
1. **캐시 전략**: HTML 파일은 캐시하지 않음 (즉시 반영)
2. **압축**: CloudFront에서 자동 Gzip 압축
3. **CDN**: 글로벌 엣지 로케이션으로 빠른 로딩

## 🔧 문제 해결

### 자주 발생하는 이슈

#### 1. GitHub Actions 실패
```bash
# 로컬에서 먼저 테스트
aws sts get-caller-identity  # 인증 확인
aws s3 ls s3://petclinic-dev-frontend-dev/  # 버킷 접근 확인
```

#### 2. 캐시가 갱신되지 않음
```bash
# 수동 캐시 무효화
aws cloudfront create-invalidation --distribution-id ECU0OIUYY0NGN --paths '/*'

# 상태 확인
aws cloudfront get-invalidation --distribution-id ECU0OIUYY0NGN --id INVALIDATION_ID
```

#### 3. 파일이 업로드되지 않음
```bash
# 로컬 파일 확인
ls -la spring-petclinic-api-gateway/src/main/resources/static/

# S3 업로드 테스트
aws s3 cp index.html s3://petclinic-dev-frontend-dev/
```

## 🔗 의존성
- **08-api-gateway**: API Gateway URL 참조 (프론트엔드에서 API 호출)
- **01-network**: VPC 및 서브넷 (CloudFront Origin Access Identity)
- **02-security**: IAM 역할 및 정책 (S3 접근 권한)

## 📊 모니터링

### CloudWatch 메트릭
- S3 버킷 요청 수 및 에러율
- CloudFront 캐시 적중률 및 응답시간
- 데이터 전송량 및 비용

### 로그 분석
```bash
# CloudFront 액세스 로그
aws s3 ls s3://petclinic-dev-frontend-dev/access-logs/ --recursive

# S3 서버 액세스 로그
aws logs tail /aws/s3/petclinic-dev-frontend-dev/access --follow
```

## 🎯 베스트 프랙티스

1. **작은 커밋**: 프론트엔드 변경사항을 별도 커밋으로 분리
2. **브랜치 전략**: `feature/frontend-*` 브랜치로 작업 후 main 병합
3. **테스트 환경**: dev → staging → prod 순서로 배포
4. **모니터링**: 배포 후 CloudWatch 메트릭 확인
5. **백업**: 중요한 변경 전 S3 버전닝 활용

이제 프론트엔드 배포는 완전히 자동화되어, 코드 변경만으로 전 세계 사용자에게 즉시 반영됩니다! 🚀