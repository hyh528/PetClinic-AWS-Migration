# 현재 Terraform 인프라 이슈 및 해결 방안

## 📊 전체 상태 요약

| 레이어 | 상태 | 이슈 | 우선순위 |
|--------|------|------|----------|
| network | ✅ 정상 | 없음 | - |
| security | ✅ 정상 | 없음 | - |
| database | ✅ 정상 | 없음 | - |
| application | ⚠️ 오류 | task_role_arn 속성 오류 | 🔴 높음 |
| monitoring | ✅ 정상 | 없음 | - |
| aws-native | ✅ 정상 | 없음 | - |
| state-management | 🆕 신규 | 테스트 필요 | 🟡 중간 |

## 🚨 긴급 해결 필요 이슈

### Issue #1: Application 레이어 - ECS 모듈 오류

**오류 메시지:**
```
Error: Unexpected attribute: An attribute named "task_role_arn" is not expected here (76:2)
```

**원인 분석:**
- ECS 모듈에서 `task_role_arn` 변수는 정의되어 있음
- Application 레이어에서 모듈 호출 시 해당 속성을 전달하고 있음
- Terraform 캐시 또는 모듈 인식 문제로 추정

**해결 방안:**

#### 방안 1: 캐시 정리 및 재초기화 (권장)
```bash
cd terraform/envs/dev/application
rm -rf .terraform
rm .terraform.lock.hcl
terraform init
terraform validate
```

#### 방안 2: 모듈 호출 방식 수정
```hcl
# 현재 (오류 발생)
module "ecs" {
  source = "../../../modules/ecs"
  # ... 다른 설정들
  task_role_arn = aws_iam_role.ecs_task_role.arn
}

# 수정안 (조건부 전달)
module "ecs" {
  source = "../../../modules/ecs"
  # ... 다른 설정들
  task_role_arn = var.enable_task_role ? aws_iam_role.ecs_task_role.arn : null
}
```

#### 방안 3: 모듈 구조 재검토
ECS 모듈의 variables.tf와 main.tf 일관성 확인 필요

## 🔍 검증 필요 항목

### 1. 상태 관리 인프라 테스트

**테스트 항목:**
- [ ] S3 버킷 생성 및 암호화 확인
- [ ] DynamoDB 테이블 생성 및 잠금 테스트
- [ ] KMS 키 생성 및 권한 확인
- [ ] 백엔드 연결 테스트

**테스트 명령어:**
```bash
cd terraform/envs/dev/state-management
terraform init
terraform plan
# 주의: apply 전에 반드시 팀 검토 필요
```

### 2. 기존 리소스 상태 확인

**확인 필요 사항:**
- 현재 AWS 계정에 배포된 리소스 현황
- 로컬 상태 파일과 실제 리소스 일치 여부
- 리소스 태그 및 명명 규칙 준수 여부

**확인 명령어:**
```bash
# 각 레이어별 상태 확인
for layer in network security database application; do
    echo "=== $layer 레이어 ==="
    cd terraform/envs/dev/$layer
    terraform state list 2>/dev/null || echo "상태 파일 없음"
    cd - > /dev/null
done
```

## 🛠️ 단계별 해결 계획

### Phase 1: 긴급 이슈 해결 (1-2일)

1. **Application 레이어 오류 수정**
   - ECS 모듈 캐시 정리
   - 모듈 호출 방식 검토
   - 테스트 및 검증

2. **상태 관리 인프라 검증**
   - 개발 환경에서 안전 테스트
   - 백엔드 연결 확인
   - 문서화 완료

### Phase 2: 전체 인프라 검증 (3-5일)

1. **레이어별 순차 검증**
   - Network → Security → Database → Application 순서
   - 각 레이어별 terraform plan 실행
   - 예상치 못한 변경사항 확인

2. **원격 상태 마이그레이션**
   - 백업 생성
   - 단계별 마이그레이션
   - 검증 및 롤백 계획 수립

### Phase 3: 팀 교육 및 문서화 (1주일)

1. **팀원 교육**
   - Terraform 기초 교육
   - 프로젝트별 가이드 교육
   - 실습 및 Q&A

2. **운영 가이드 작성**
   - 일상 운영 절차
   - 장애 대응 매뉴얼
   - 모니터링 가이드

## 🚀 권장 작업 순서 (팀원용)

### 1단계: 환경 준비
```bash
# 1. 최신 코드 pull
git pull origin main

# 2. AWS 자격 증명 확인
aws sts get-caller-identity

# 3. Terraform 버전 확인
terraform version
```

### 2단계: 문법 검증
```bash
# 모든 모듈 문법 검증
cd terraform
find . -name "*.tf" -exec terraform fmt -check {} \;
```

### 3단계: 단계별 테스트
```bash
# 1. 상태 관리 (신규)
cd terraform/envs/dev/state-management
terraform init
terraform plan  # 검토 후 apply

# 2. 기존 레이어 검증
cd ../network
terraform init
terraform plan  # 변경사항 없어야 함

# 3. Application 레이어 (오류 수정 후)
cd ../application
terraform init
terraform plan
```

## 📞 에스컬레이션 기준

### 즉시 중단 및 문의 필요한 상황

1. **예상치 못한 리소스 삭제**
   ```
   Plan: 0 to add, 0 to change, 5 to destroy.
   ```

2. **높은 비용 리소스 생성**
   - RDS 인스턴스 타입 변경
   - NAT Gateway 추가 생성
   - 대용량 EBS 볼륨 생성

3. **보안 관련 변경**
   - IAM 정책 변경
   - 보안 그룹 규칙 변경
   - VPC 설정 변경

### 문의 시 포함할 정보

1. **오류 메시지 전체**
2. **실행한 명령어**
3. **현재 작업 디렉토리**
4. **terraform plan 출력 결과**

## 📋 체크리스트

### 배포 전 확인사항
- [ ] 올바른 AWS 계정 및 리전 확인
- [ ] terraform plan 결과 검토
- [ ] 백업 계획 수립
- [ ] 팀원 공지 완료

### 배포 후 확인사항
- [ ] AWS 콘솔에서 리소스 확인
- [ ] 애플리케이션 동작 테스트
- [ ] 모니터링 대시보드 확인
- [ ] 비용 모니터링 설정

---

**⚠️ 중요**: 불확실한 부분이 있으면 반드시 팀에 문의하세요. 인프라 변경은 되돌리기 어려울 수 있습니다.