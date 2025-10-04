# Terraform 상태 관리 (${environment} 환경)

이 디렉토리는 Terraform 원격 상태 관리 인프라를 구성합니다.

## 📋 개요

- **S3 버킷**: `${bucket_name}`
- **DynamoDB 테이블**: `${table_name}`
- **KMS 키**: `${kms_key_arn}`
- **환경**: `${environment}`

## 🏗️ 아키텍처

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Terraform     │───▶│   S3 Bucket      │───▶│   KMS Key       │
│   Clients       │    │   (State Files)  │    │   (Encryption)  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │
         ▼
┌─────────────────┐
│   DynamoDB      │
│   (State Lock)  │
└─────────────────┘
```

## 🚀 배포 방법

### 1. 초기 배포

```bash
# 상태 관리 인프라 배포
cd terraform/envs/dev/state-management
terraform init
terraform plan
terraform apply
```

### 2. 원격 상태 마이그레이션

```bash
# 자동 마이그레이션 스크립트 실행
./scripts/migrate-to-remote-state.sh

# 또는 수동으로 각 레이어별 마이그레이션
cd ../network
terraform init -migrate-state
```

## 📁 백엔드 키 구조

%{ for layer, key in backend_keys ~}
- **${layer}**: `${key}`
%{ endfor ~}

## 🔧 백엔드 설정 템플릿

각 레이어의 `backend.tf` 파일:

```hcl
terraform {
  backend "s3" {
    bucket         = "${bucket_name}"
    key            = "envs/${environment}/LAYER_NAME/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "${table_name}"
    encrypt        = true
    kms_key_id     = "${kms_key_arn}"
  }
}
```

## 🔒 보안 기능

### 암호화
- **저장 시 암호화**: KMS 키를 사용한 S3 및 DynamoDB 암호화
- **전송 중 암호화**: HTTPS 전용 액세스 정책

### 접근 제어
- **퍼블릭 액세스 차단**: S3 버킷 완전 차단
- **IAM 기반 접근**: 최소 권한 원칙 적용
- **MFA 삭제**: 중요 리소스 보호 (선택사항)

### 감사 및 모니터링
- **CloudTrail**: 모든 API 호출 로깅
- **버전 관리**: S3 버킷 버전 관리 활성화
- **백업**: 자동 백업 및 복원 전략

## 💰 비용 최적화

### 스토리지 최적화
- **라이프사이클 정책**: 자동 스토리지 클래스 전환
  - 30일 후 → Standard-IA
  - 90일 후 → Glacier
  - 180일 후 → 삭제 (개발 환경)

### 컴퓨팅 최적화
- **DynamoDB 온디맨드**: 사용량 기반 과금
- **KMS 키 공유**: 여러 리소스에서 동일 키 사용

## 🔄 운영 가이드

### 일상 운영

```bash
# 상태 파일 목록 확인
aws s3 ls s3://${bucket_name}/envs/${environment}/ --recursive

# 잠금 상태 확인
aws dynamodb scan --table-name ${table_name} --region ap-northeast-2

# 백업 확인
aws s3api list-object-versions --bucket ${bucket_name}
```

### 장애 복구

```bash
# 상태 파일 복원 (특정 버전)
aws s3api get-object \
  --bucket ${bucket_name} \
  --key envs/${environment}/LAYER/terraform.tfstate \
  --version-id VERSION_ID \
  terraform.tfstate

# 잠금 해제 (강제)
terraform force-unlock LOCK_ID
```

### 백업 및 복원

```bash
# 수동 백업
aws s3 sync s3://${bucket_name} ./backup/

# 특정 레이어 백업
aws s3 cp s3://${bucket_name}/envs/${environment}/network/terraform.tfstate \
  ./backup/network-$(date +%Y%m%d).tfstate
```

## 🚨 문제 해결

### 일반적인 문제

1. **백엔드 초기화 실패**
   ```bash
   # 캐시 정리 후 재시도
   rm -rf .terraform
   terraform init
   ```

2. **상태 잠금 오류**
   ```bash
   # 잠금 상태 확인
   aws dynamodb get-item \
     --table-name ${table_name} \
     --key '{"LockID":{"S":"BUCKET/KEY"}}'
   
   # 강제 잠금 해제
   terraform force-unlock LOCK_ID
   ```

3. **권한 오류**
   ```bash
   # 현재 자격 증명 확인
   aws sts get-caller-identity
   
   # S3 버킷 권한 확인
   aws s3api get-bucket-policy --bucket ${bucket_name}
   ```

### 로그 확인

```bash
# CloudTrail 로그 확인
aws logs filter-log-events \
  --log-group-name /aws/cloudtrail \
  --filter-pattern "{ $.eventSource = s3.amazonaws.com && $.requestParameters.bucketName = ${bucket_name} }"

# Terraform 디버그 모드
export TF_LOG=DEBUG
terraform plan
```

## 📚 참고 자료

- [Terraform S3 Backend](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [AWS S3 보안 모범 사례](https://docs.aws.amazon.com/s3/latest/userguide/security-best-practices.html)
- [DynamoDB 모범 사례](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)

## 🤝 기여 가이드

1. 변경 사항은 반드시 테스트 환경에서 먼저 검증
2. 상태 파일 변경 시 백업 생성
3. 중요한 변경 사항은 팀 리뷰 필수
4. 문서 업데이트 동반

---

**⚠️ 주의사항**: 이 인프라는 모든 Terraform 상태를 관리하는 핵심 컴포넌트입니다. 변경 시 각별한 주의가 필요합니다.