# 09-Monitoring Layer

## 개요

기본 CloudWatch 모니터링을 제공하는 단순화된 레이어입니다. 과도한 개별 알람을 제거하고 핵심적인 모니터링 기능만 유지하여 운영 복잡성을 줄였습니다.

## 아키텍처

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   CloudWatch    │    │   SNS Topic     │    │   Email Alert   │
│                 │    │                 │    │                 │
│ - 대시보드       │───▶│ - 알람 알림     │───▶│ - 이메일 알림    │
│ - 기본 알람     │    │ - 토픽 구독     │    │ - 관리자 알림    │
│ - 로그 수집     │    └─────────────────┘    └─────────────────┘
└─────────────────┘
        │
        ▼
┌─────────────────┐
│   CloudTrail    │
│                 │
│ - 감사 로그     │
│ - S3 저장      │
│ - 선택적 활성화 │
└─────────────────┘
```

## 주요 기능

### 단순화된 모니터링
- **기본 CloudWatch 대시보드**: 핵심 메트릭만 표시
- **최소한의 알람**: ECS 서비스 상태, Aurora 연결 상태만
- **SNS 알림**: 이메일 기반 알람 알림
- **선택적 CloudTrail**: 필요시에만 활성화

### 제거된 복잡성
- ❌ 과도한 개별 알람 (CPU, 메모리, 5XX 에러 등)
- ❌ X-Ray 추적 설정
- ❌ 하드코딩된 버킷명
- ❌ 복잡한 모니터링 설정

## 의존성

이 레이어는 다음 레이어들에 의존합니다:

1. **03-database**: Aurora 클러스터 정보
2. **07-application**: ECS 클러스터 및 서비스 정보
3. **08-api-gateway**: API Gateway 정보 (선택적)

## 사용법

### 1. 초기화
```bash
cd terraform/layers/09-monitoring
terraform init -backend-config="../../envs/dev/backend.hcl"
```

### 2. 계획 확인
```bash
terraform plan -var-file="../../envs/dev/terraform.tfvars"
```

### 3. 배포
```bash
terraform apply -var-file="../../envs/dev/terraform.tfvars"
```

## 주요 변수

| 변수명 | 설명 | 기본값 | 필수 |
|--------|------|--------|------|
| `name_prefix` | 리소스 이름 접두사 | - | ✅ |
| `environment` | 배포 환경 | - | ✅ |
| `alert_email` | 알람 이메일 주소 | `""` | ❌ |
| `log_retention_days` | 로그 보관 기간 | `30` | ❌ |
| `enable_cloudtrail` | CloudTrail 활성화 | `false` | ❌ |
| `cloudtrail_log_retention_days` | CloudTrail 로그 보관 기간 | `90` | ❌ |

## 모니터링 대상

### ECS 서비스 모니터링
```hcl
메트릭: RunningTaskCount
임계값: < 1 (실행 중인 태스크 없음)
목적: 서비스 가용성 확인
```

### Aurora 데이터베이스 모니터링
```hcl
메트릭: DatabaseConnections
임계값: > 80 (연결 수 과다)
목적: 데이터베이스 성능 확인
```

### CloudWatch 대시보드
- ECS 서비스 상태
- Aurora 클러스터 상태
- ALB 기본 메트릭
- 로그 그룹 현황

## 출력값

### 대시보드 정보
- `dashboard_url`: CloudWatch 대시보드 URL
- `dashboard_name`: 대시보드 이름

### 알림 정보
- `sns_topic_arn`: SNS 토픽 ARN
- `sns_topic_name`: SNS 토픽 이름

### CloudTrail 정보 (활성화된 경우)
- `cloudtrail_arn`: CloudTrail ARN
- `cloudtrail_s3_bucket`: 로그 저장 S3 버킷
- `cloudtrail_log_group`: CloudWatch 로그 그룹

### 설정 정보
- `active_alarms`: 활성화된 알람 목록
- `monitoring_config`: 모니터링 설정 정보

## 개선사항

### ✅ 완료된 개선사항
1. **하드코딩 제거**: 버킷명, 리소스명 등 공유 변수 사용
2. **과도한 알람 제거**: 핵심 알람만 유지
3. **공유 변수 시스템 적용**: 일관성 있는 변수 관리
4. **선택적 기능**: CloudTrail, 이메일 알림 등 선택적 활성화
5. **단순화된 구조**: 복잡한 설정 제거

### 🔄 향후 개선 계획
1. **Grafana 통합**: 고급 시각화 (선택적)
2. **Prometheus 메트릭**: 커스텀 메트릭 수집
3. **Slack 알림**: 이메일 외 알림 채널
4. **자동 복구**: 알람 기반 자동 액션

## 알람 설정

### 기본 알람 (2개만)
```yaml
ECS 서비스 상태:
  메트릭: RunningTaskCount
  임계값: < 1
  평가 기간: 2회 연속
  알림: SNS 토픽

Aurora 연결 상태:
  메트릭: DatabaseConnections  
  임계값: > 80
  평가 기간: 2회 연속
  알림: SNS 토픽
```

### 제거된 알람
- ❌ API Gateway 5XX 에러
- ❌ ECS CPU 사용률
- ❌ ECS 메모리 사용률
- ❌ Aurora CPU 사용률
- ❌ ALB 5XX 에러

## CloudTrail 설정

### 기본 설정 (선택적)
```hcl
활성화: var.enable_cloudtrail = true
로그 보관: 90일 (설정 가능)
S3 버킷: {name_prefix}-{environment}-cloudtrail-logs-{random}
암호화: 기본 SSE-S3
```

### 비용 고려사항
```
CloudTrail 데이터 이벤트: $0.10 per 100,000 events
S3 저장: $0.023 per GB per month
CloudWatch Logs: $0.50 per GB ingested
```

## 문제 해결

### 일반적인 문제
1. **이메일 알림 안됨**: SNS 구독 확인 필요
2. **대시보드 접근 안됨**: IAM 권한 확인
3. **알람 발생 안됨**: 메트릭 데이터 확인
4. **CloudTrail 로그 없음**: S3 버킷 권한 확인

### 디버깅 명령어
```bash
# SNS 토픽 구독 확인
aws sns list-subscriptions-by-topic --topic-arn {topic_arn}

# CloudWatch 알람 상태 확인
aws cloudwatch describe-alarms --alarm-names {alarm_name}

# CloudTrail 상태 확인
aws cloudtrail describe-trails --trail-name-list {trail_name}

# 대시보드 확인
aws cloudwatch list-dashboards
```

## 비용 최적화

### 예상 월간 비용
```
CloudWatch 대시보드: $3 per dashboard
CloudWatch 알람: $0.10 per alarm (2개)
SNS 알림: $0.50 per million notifications
CloudTrail (선택적): $2.00 per 100,000 events
총계: 약 $5-10 per month
```

### 비용 절감 방안
1. **로그 보관 기간 최적화**: 필요한 기간만 설정
2. **CloudTrail 선택적 사용**: 필요시에만 활성화
3. **알람 최소화**: 핵심 알람만 유지
4. **대시보드 통합**: 여러 환경 대시보드 통합

## 태그 전략

모든 리소스에는 다음 태그가 자동으로 적용됩니다:

```hcl
{
  Environment = var.environment
  Layer       = "09-monitoring"
  Component   = "monitoring"
  ManagedBy   = "terraform"
  # + 사용자 정의 태그 (var.tags)
}
```