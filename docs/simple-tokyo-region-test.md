# 🗾 간단한 도쿄 리전 테스트 가이드

## 🎯 핵심 아이디어
**리전 하나만 바꾸면 모든 게 자동으로 도쿄 리전에서 실행됩니다!**

## 🚀 사용법

### 1. 도쿄 리전으로 변경
```bash
# terraform/envs/dev/shared-variables.tf 파일에서
aws_region = "ap-northeast-1"  # 도쿄 리전
azs = ["ap-northeast-1a", "ap-northeast-1c"]  # 도쿄 AZ
```

### 2. 일반적인 Terraform 명령 실행
```bash
# 네트워크 레이어 테스트
cd terraform/envs/dev/01-network
terraform init
terraform plan
terraform apply  # 실제 리소스 생성

# 다른 레이어들도 동일
cd ../02-security
terraform init && terraform plan && terraform apply

cd ../03-database  
terraform init && terraform plan && terraform apply
```

### 3. 기존 테스트 도구 활용
```powershell
# 단위 테스트 (도쿄 리전에서 자동 실행)
.\scripts\run-terraform-tests.ps1 -TestType "unit" -Module "vpc"

# 통합 테스트
.\scripts\run-terraform-tests.ps1 -TestType "integration"
```

### 4. 서울 리전으로 되돌리기
```bash
# terraform/envs/dev/shared-variables.tf 파일에서
aws_region = "ap-northeast-2"  # 서울 리전
azs = ["ap-northeast-2a", "ap-northeast-2c"]  # 서울 AZ
```

## ✅ 장점

1. **단순함**: 파일 하나만 수정
2. **일관성**: 모든 레이어가 자동으로 같은 리전 사용
3. **기존 도구 활용**: 추가 스크립트 불필요
4. **실수 방지**: 리전 불일치 문제 없음

## ⚠️ 주의사항

1. **비용**: 실제 AWS 리소스 생성됨 (시간당 ~$1)
2. **정리**: 테스트 후 `terraform destroy` 필수
3. **상태 파일**: 도쿄/서울 리전별로 다른 S3 버킷 사용 권장

## 🧹 정리 방법

```bash
# 역순으로 destroy
cd terraform/envs/dev/09-monitoring && terraform destroy
cd ../08-api-gateway && terraform destroy  
cd ../07-application && terraform destroy
cd ../06-lambda-genai && terraform destroy
cd ../05-cloud-map && terraform destroy
cd ../04-parameter-store && terraform destroy
cd ../03-database && terraform destroy
cd ../02-security && terraform destroy
cd ../01-network && terraform destroy
```

## 🎉 결론

복잡한 테스트 스크립트나 별도 설정 파일 없이, **shared-variables.tf 파일의 리전 설정 하나만 바꾸면** 모든 인프라가 도쿄 리전에서 테스트됩니다!

이게 가장 간단하고 실용적인 방법입니다. 👍