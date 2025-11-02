# 네트워크 레이어 Drift 분석 보고서

## 문제 요약
네트워크 레이어에서 29개 변경사항이 감지된 이유는 **태그 불일치** 때문입니다.

## 실제 AWS 리소스 태그 (VPC 예시)
```
Backup          = "not-required"
BillingCode     = "petclinic-dev"
Compliance      = "standard"
Component       = "networking"
CostCenter      = "training"
CreatedAt       = "2025-10-21"
CreatedBy       = "team-petclinic"
Environment     = "dev"
Layer           = "01-network"
ManagedBy       = "terraform"
Module          = "vpc"
Monitoring      = "enabled"
Name            = "petclinic-dev-vpc"
Owner           = "team-petclinic"
Project         = "petclinic"
TerraformModule = "common"
Tier            = "network"
```

## Terraform Plan에서 제거하려는 태그들
모든 리소스에서 다음 태그들을 제거하려고 함:
- `Backup`
- `BillingCode`
- `Compliance`
- `Component`
- `CostCenter`
- `CreatedAt`
- `CreatedBy`
- `Environment`
- `Layer`
- `ManagedBy`
- `Monitoring`
- `Name`
- `Owner`
- `Project`
- `TerraformModule`
- `Tier`

## 영향받는 리소스 (총 29개)
1. **VPC** (1개)
   - `aws_vpc.this`

2. **서브넷** (6개)
   - `aws_subnet.public[0]` (public-a)
   - `aws_subnet.public[1]` (public-b)
   - `aws_subnet.private_app[0]` (private-app-a)
   - `aws_subnet.private_app[1]` (private-app-b)
   - `aws_subnet.private_db[0]` (private-db-a)
   - `aws_subnet.private_db[1]` (private-db-b)

3. **라우트 테이블** (4개)
   - `aws_route_table.public`
   - `aws_route_table.private_app[0]`
   - `aws_route_table.private_app[1]`
   - `aws_route_table.private_db[0]`
   - `aws_route_table.private_db[1]`

4. **보안 그룹** (1개)
   - `aws_security_group.vpce`

5. **VPC 엔드포인트** (12개)
   - ECR API, ECR DKR
   - CloudWatch Logs, Monitoring
   - SSM, SSM Messages, EC2 Messages
   - Secrets Manager
   - KMS, X-Ray
   - S3 Gateway

## 원인 분석

### 1. 태그 정의 불일치
**현재 상황:**
- AWS 리소스: 17개 태그 존재
- Terraform 코드: 태그를 `(known after apply)`로 재설정하려고 함

### 2. Common 모듈 태그 설정
`terraform/modules/common/locals.tf`에서 정의된 태그들:
```hcl
common_tags = merge(
  local.mandatory_tags,    # Project, Environment, ManagedBy, CreatedBy, CreatedAt
  local.cost_tags,         # CostCenter, Owner, BillingCode
  local.operational_tags,  # Backup, Monitoring, Compliance
  local.technical_tags,    # TerraformModule, Layer, Component
  var.additional_tags
)
```

### 3. 수동 생성 vs Terraform 관리
**추정 시나리오:**
1. 초기에 AWS 콘솔이나 다른 도구로 리소스 생성
2. 풍부한 태그 세트 적용
3. 나중에 Terraform으로 Import
4. Terraform 코드의 태그 정의가 실제 태그와 다름

## 해결 방안

### 옵션 1: 태그 무시 (권장)
**장점:**
- 기능에 영향 없음
- 빠른 해결
- 기존 태그 보존

**방법:**
```hcl
# lifecycle 블록 추가
lifecycle {
  ignore_changes = [tags, tags_all]
}
```

### 옵션 2: 태그 동기화
**장점:**
- 완전한 Terraform 관리
- 일관된 태그 정책

**단점:**
- 기존 태그 정보 손실 가능
- 더 많은 작업 필요

### 옵션 3: 현재 태그 Import
**방법:**
1. 현재 AWS 태그를 Terraform 코드에 반영
2. `common_tags` 정의 업데이트

## 권장 조치

### 즉시 조치 (태그 무시)
```bash
# 1. VPC 모듈에 lifecycle 블록 추가
# 2. 엔드포인트 모듈에 lifecycle 블록 추가
# 3. Plan 재실행으로 확인
```

### 장기 조치 (태그 표준화)
1. 조직의 태그 정책 정의
2. Common 모듈 태그 업데이트
3. 모든 레이어에 일관된 태그 적용

## 결론

**이 29개 변경사항은 실제 기능에 영향을 주지 않는 무해한 drift입니다.**

- **우선순위**: 낮음
- **영향도**: 없음 (태그만 변경)
- **권장 조치**: lifecycle ignore_changes 적용
- **긴급도**: 낮음

다른 우선순위가 높은 오류들(02-security, 06-lambda-genai, 07-application)을 먼저 해결하는 것이 좋습니다.