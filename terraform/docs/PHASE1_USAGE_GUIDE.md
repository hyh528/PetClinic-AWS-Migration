# Phase 1 완료 후 사용법 가이드

## 🚀 **빠른 시작**

Phase 1 완료로 새로운 표준화된 방식을 사용할 수 있습니다.

### **레이어 초기화 (새로운 방식)**

```powershell
# 기본 초기화
./scripts/init-layer.ps1 -Environment dev -Layer "01-network"

# 기존 상태가 있는 경우 재구성
./scripts/init-layer.ps1 -Environment dev -Layer "02-security" -Reconfigure
```

### **전체 레이어 순서**

```bash
01-network      # VPC, 서브넷, 게이트웨이
02-security     # 보안 그룹, IAM, VPC 엔드포인트  
03-database     # Aurora 클러스터
04-parameter-store  # Parameter Store
05-cloud-map    # 서비스 디스커버리
06-lambda-genai # Lambda AI 서비스
07-application  # ECS, ALB, ECR
08-api-gateway  # API Gateway
09-monitoring   # CloudWatch
10-aws-native   # AWS 네이티브 서비스 통합
```

## 🔧 **새로운 Backend 시스템**

### **도쿄 리전 테스트 환경**
- **S3 버킷**: `petclinic-yeonghyeon-test`
- **DynamoDB 테이블**: `petclinic-yeonghyeon-test-locks`
- **리전**: `ap-northeast-1` (도쿄)

### **상태 파일 구조**
```
s3://petclinic-yeonghyeon-test/
├── dev/01-network/terraform.tfstate
├── dev/02-security/terraform.tfstate
├── dev/03-database/terraform.tfstate
└── ...
```

## 📋 **주요 변경사항**

### **✅ 개선된 점**
- 레이어별 독립적 상태 관리
- 업계 표준 backend.hcl 방식
- 공유 변수 시스템 적용
- 자동화된 초기화 스크립트

### **❌ 제거된 것**
- 11-state-management 레이어
- 개인 경로 (dev/yeonghyeon/network)
- 중복된 backend.tf 설정

## 🔍 **문제 해결**

### **일반적인 문제**

1. **Backend configuration changed 에러**
   ```powershell
   # 해결: -Reconfigure 옵션 사용
   ./scripts/init-layer.ps1 -Environment dev -Layer "레이어명" -Reconfigure
   ```

2. **S3 버킷 접근 에러**
   ```bash
   # AWS 프로파일 확인
   aws configure list --profile petclinic-dev
   ```

3. **DynamoDB 테이블 에러**
   ```bash
   # 테이블 상태 확인
   aws dynamodb describe-table --table-name petclinic-yeonghyeon-test-locks --region ap-northeast-1 --profile petclinic-dev
   ```

## 📞 **지원**

문제가 발생하면 다음을 확인하세요:
1. AWS 프로파일 설정 (`petclinic-dev`)
2. 도쿄 리전 권한 (`ap-northeast-1`)
3. S3 버킷 및 DynamoDB 테이블 존재 여부

---

**업데이트**: 2025-01-10  
**버전**: 1.0