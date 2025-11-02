# Import되지 않은 수동 리소스 목록

## 검증 완료 일시
- 날짜: 2025-01-01
- 환경: dev (ap-northeast-2)
- 검증 방법: terraform plan + validate

## 수동 리소스 분류

### 🔴 Import 필요한 리소스

#### 1. 네트워크 레이어 (01-network) - 29개 변경사항
**예상 수동 리소스:**
- VPC 태그 불일치
- 서브넷 태그 불일치  
- 라우팅 테이블 연결 차이
- 보안 그룹 규칙 일부
- VPC 엔드포인트 정책 설정

**조치 방안:**
- 태그 차이는 무시 가능 (중요도 낮음)
- 실제 설정 차이만 Import 또는 수정

#### 2. 데이터베이스 레이어 (03-database) - 3개 변경사항
**예상 수동 리소스:**
- Aurora 클러스터 파라미터 그룹 설정
- 백업 윈도우 설정
- Enhanced Monitoring 설정

**조치 방안:**
- 설정 차이 확인 후 코드 수정 또는 Import

#### 3. 파라미터 스토어 레이어 (04-parameter-store) - 1개 추가
**누락 리소스:**
- SSM 파라미터 1개 (애플리케이션 설정용)

**조치 방안:**
- 누락된 파라미터 생성 또는 Import

### 🟡 설정 오류 해결 필요

#### 1. 보안 레이어 (02-security)
**문제:**
- Terraform 모듈 초기화 오류
- IAM 역할 모듈 의존성 문제

**조치 방안:**
```bash
cd terraform/layers/02-security
terraform init -backend-config=backend.config
```

#### 2. 애플리케이션 레이어 (07-application)
**문제:**
- security 레이어 output 참조 오류
- `ecs_task_execution_role_arn` 속성 없음

**조치 방안:**
- security 레이어 output 확인 및 수정
- 참조 경로 수정

#### 3. Lambda GenAI 레이어 (06-lambda-genai)
**문제:**
- Plan 실행 시간 초과 (30초+)
- 복잡한 IAM 정책 또는 Lambda 설정

**조치 방안:**
- 개별 리소스별 plan 실행
- 타임아웃 원인 분석

### ✅ 정상 동기화된 레이어

#### 1. Cloud Map 레이어 (05-cloud-map)
- **상태**: 완전 동기화
- **변경사항**: 없음
- **비고**: Import 작업 성공

#### 2. 설정 검증 완료 레이어
- **08-api-gateway**: 설정 유효 (경고만 있음)
- **09-aws-native**: 설정 유효
- **10-monitoring**: 설정 유효  
- **11-frontend**: 설정 유효

## 수동 생성 리소스 상세 목록

### AWS 콘솔에서 수동 생성된 것으로 추정되는 리소스

#### VPC 및 네트워킹
- [ ] VPC 태그 (Name, Environment 등)
- [ ] 서브넷 태그
- [ ] 라우팅 테이블 태그
- [ ] 보안 그룹 규칙 (일부)
- [ ] VPC 엔드포인트 정책

#### ECS 및 컨테이너
- [ ] ECS 태스크 정의 (일부 설정)
- [ ] ECS 서비스 설정 (일부)
- [ ] Auto Scaling 정책 (일부)

#### 로드 밸런서
- [ ] ALB 리스너 규칙 (일부)
- [ ] 타겟 그룹 설정 (일부)
- [ ] 헬스체크 설정

#### 데이터베이스
- [ ] Aurora 파라미터 그룹 설정
- [ ] 백업 설정 차이
- [ ] 모니터링 설정

#### IAM
- [ ] 일부 정책 연결
- [ ] 역할 신뢰 관계 (일부)
- [ ] 인스턴스 프로파일 (일부)

#### 모니터링
- [ ] CloudWatch 대시보드 (일부)
- [ ] 알람 설정 (일부)
- [ ] 로그 그룹 설정

## 추가 Import 계획

### 우선순위 1 (즉시 처리)
1. **02-security 초기화**
   ```bash
   cd terraform/layers/02-security
   terraform init -backend-config=backend.config
   terraform plan -var-file="../../envs/dev.tfvars"
   ```

2. **07-application output 오류 수정**
   - security 레이어 output 확인
   - 참조 경로 수정

### 우선순위 2 (단기 처리)
1. **01-network drift 분석**
   ```bash
   cd terraform/layers/01-network  
   terraform plan -var-file="../../envs/dev.tfvars" > network-drift.txt
   # 29개 변경사항 상세 분석
   ```

2. **03-database drift 분석**
   ```bash
   cd terraform/layers/03-database
   terraform plan -var-file="../../envs/dev.tfvars" > database-drift.txt
   # 3개 변경사항 상세 분석
   ```

3. **04-parameter-store 리소스 추가**
   ```bash
   cd terraform/layers/04-parameter-store
   terraform plan -var-file="../../envs/dev.tfvars" > parameter-drift.txt
   # 1개 누락 리소스 확인
   ```

### 우선순위 3 (중기 처리)
1. **06-lambda-genai 타임아웃 해결**
   - 개별 리소스 plan 실행
   - 복잡한 IAM 정책 분석

2. **나머지 레이어 plan 실행**
   - 08-api-gateway부터 11-frontend까지
   - 실제 drift 확인

## 리소스 정리 계획

### 제거 대상 리소스
- [ ] 중복된 보안 그룹 규칙
- [ ] 사용하지 않는 IAM 정책
- [ ] 테스트용 리소스 (있다면)

### 유지 대상 리소스  
- [ ] 프로덕션 데이터
- [ ] 중요한 설정 파일
- [ ] 백업 및 스냅샷

### Terraform 외부 관리 리소스
- [ ] 수동 백업 스냅샷
- [ ] 임시 디버깅 리소스
- [ ] 외부 도구로 생성된 리소스

## 최종 목표

**완료 기준:**
- [ ] 모든 레이어에서 `terraform plan` 결과가 "No changes"
- [ ] 수동 생성 리소스 100% 문서화
- [ ] Import 불가능한 리소스 명확히 분류
- [ ] 정리 대상 리소스 제거 완료

**예상 완료 시점:**
- 우선순위 1: 즉시 (1-2시간)
- 우선순위 2: 1-2일
- 우선순위 3: 3-5일
- 전체 완료: 1주일 이내