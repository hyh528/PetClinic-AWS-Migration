# 안전한 Terraform 재배포 가이드

## 개요
현재 Import 작업이 85% 완료된 상태에서 전체 destroy 후 재배포가 가능한지 검증 및 안전한 절차 제시

## 재배포 가능성 평가: ✅ 가능

### 긍정적 요소
- 모든 핵심 리소스가 Terraform 코드로 정의됨
- `ManagedBy: terraform` 태그로 관리 상태 확인됨
- 레이어별 의존성 구조가 명확함

### 주의 요소
- 3개 레이어에 현재 오류 존재
- 데이터 손실 위험 (Aurora, S3, 로그)
- 외부 의존성 (상태 파일, ECR 이미지)

## 사전 준비 작업

### 1. 데이터 백업
```bash
# Aurora 스냅샷 생성
aws rds create-db-cluster-snapshot \
  --db-cluster-identifier petclinic-dev-aurora-cluster \
  --db-cluster-snapshot-identifier petclinic-backup-$(date +%Y%m%d)

# S3 버킷 백업 (중요 데이터만)
aws s3 sync s3://petclinic-dev-frontend-dev ./backup/frontend/
aws s3 sync s3://petclinic-cloudtrail-logs-897722691159 ./backup/cloudtrail/
```

### 2. ECR 이미지 확인
```bash
# ECR 리포지토리 및 이미지 확인
aws ecr describe-repositories --query 'repositories[?contains(repositoryName,`petclinic`)]'
aws ecr list-images --repository-name petclinic-dev-customers
```

### 3. 현재 설정 백업
```bash
# 중요 설정 내보내기
aws ssm get-parameters-by-path --path "/petclinic" --recursive > backup/parameters.json
aws secretsmanager list-secrets --query 'SecretList[?contains(Name,`petclinic`)]' > backup/secrets.json
```

## 오류 수정 후 재배포 절차

### Phase 1: 오류 레이어 수정
```bash
# 1. Security 레이어 초기화
cd terraform/layers/02-security
terraform init -backend-config=backend.config

# 2. Application 레이어 output 참조 수정
# locals.tf에서 security output 참조 경로 확인

# 3. Lambda GenAI 타임아웃 원인 분석
cd terraform/layers/06-lambda-genai
terraform plan -target=aws_iam_role.lambda_execution_role
```

### Phase 2: 안전한 재배포 테스트
```bash
# 1. 비중요 레이어부터 테스트 (11-frontend)
cd terraform/layers/11-frontend
terraform destroy -auto-approve
terraform apply -auto-approve

# 2. 네트워크 레이어 테스트 (데이터 영향 없음)
cd terraform/layers/01-network
terraform destroy -auto-approve  
terraform apply -auto-approve
```

### Phase 3: 전체 재배포 (권장 순서)
```bash
# Destroy 순서 (역순)
terraform/layers/11-frontend     # 프론트엔드
terraform/layers/10-monitoring   # 모니터링
terraform/layers/09-aws-native   # AWS 네이티브
terraform/layers/08-api-gateway  # API Gateway
terraform/layers/07-application  # 애플리케이션 (ECS, ALB)
terraform/layers/06-lambda-genai # Lambda
terraform/layers/05-cloud-map    # 서비스 디스커버리
terraform/layers/04-parameter-store # 파라미터
terraform/layers/03-database     # 데이터베이스 ⚠️
terraform/layers/02-security     # 보안
terraform/layers/01-network      # 네트워크

# Apply 순서 (정순)
terraform/layers/01-network      # 네트워크
terraform/layers/02-security     # 보안  
terraform/layers/03-database     # 데이터베이스
terraform/layers/04-parameter-store # 파라미터
terraform/layers/05-cloud-map    # 서비스 디스커버리
terraform/layers/06-lambda-genai # Lambda
terraform/layers/07-application  # 애플리케이션
terraform/layers/08-api-gateway  # API Gateway
terraform/layers/09-aws-native   # AWS 네이티브
terraform/layers/10-monitoring   # 모니터링
terraform/layers/11-frontend     # 프론트엔드
```

## 데이터 보존 전략

### 옵션 1: 데이터베이스 보존 (권장)
```bash
# 데이터베이스 레이어만 제외하고 재배포
# 03-database는 그대로 유지
```

### 옵션 2: 스냅샷 복원
```bash
# 재배포 후 스냅샷에서 복원
aws rds restore-db-cluster-from-snapshot \
  --db-cluster-identifier petclinic-dev-aurora-cluster \
  --snapshot-identifier petclinic-backup-20250101
```

### 옵션 3: 데이터 마이그레이션
```bash
# 기존 데이터 덤프 후 새 DB에 복원
mysqldump -h old-endpoint -u admin -p petclinic > backup.sql
mysql -h new-endpoint -u admin -p petclinic < backup.sql
```

## 검증 체크리스트

### 재배포 전 확인사항
- [ ] 모든 오류 레이어 수정 완료
- [ ] 데이터 백업 완료
- [ ] ECR 이미지 존재 확인
- [ ] Terraform 상태 파일 백업
- [ ] 외부 의존성 확인 (도메인, 인증서 등)

### 재배포 후 확인사항
- [ ] 모든 레이어 `terraform plan` 결과 "No changes"
- [ ] 애플리케이션 정상 동작 확인
- [ ] 데이터베이스 연결 및 데이터 확인
- [ ] API 엔드포인트 정상 응답
- [ ] 모니터링 및 로그 수집 정상

## 롤백 계획

### 문제 발생 시 대응
1. **즉시 중단**: 문제 발생 시 apply 중단
2. **이전 상태 복원**: 백업된 스냅샷으로 복원
3. **부분 롤백**: 문제 레이어만 이전 상태로 복원
4. **수동 복구**: 필요시 AWS 콘솔에서 수동 복구

## 예상 소요 시간

| 단계 | 예상 시간 | 비고 |
|------|-----------|------|
| 사전 준비 | 30분 | 백업, 설정 확인 |
| 오류 수정 | 2-4시간 | 3개 레이어 수정 |
| 테스트 재배포 | 1시간 | 비중요 레이어 |
| 전체 재배포 | 2-3시간 | 순차적 destroy/apply |
| 검증 및 테스트 | 1시간 | 기능 확인 |
| **총 소요 시간** | **6-9시간** | 하루 작업 |

## 권장 실행 시점

### 최적 시점
- **평일 오전**: 문제 발생 시 대응 시간 확보
- **개발 환경**: 운영 영향 최소화
- **팀 전체 가용**: 문제 발생 시 협업 가능

### 피해야 할 시점
- 금요일 오후 (주말 대응 어려움)
- 중요 데모/발표 직전
- 팀원 부재 시

## 결론

**재배포 가능성: ✅ 높음 (95%)**

현재 Terraform 코드 상태가 양호하고 대부분의 리소스가 정확히 정의되어 있어 안전한 재배포가 가능합니다. 다만 오류 레이어 수정과 적절한 백업 후 진행하는 것을 강력히 권장합니다.

**추천 접근법:**
1. 먼저 오류 3개 레이어 수정 (2-4시간)
2. 비중요 레이어로 재배포 테스트 (1시간)  
3. 전체 재배포 진행 (2-3시간)

이렇게 하면 **안전하고 확실한 재배포**가 가능합니다.