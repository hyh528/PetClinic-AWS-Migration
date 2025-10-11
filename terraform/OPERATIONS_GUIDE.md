# Terraform Infrastructure Operations Guide

## 📋 개요

이 가이드는 PetClinic AWS 인프라의 일상 운영, 모니터링, 장애 대응을 위한 종합 운영 매뉴얼입니다.

## 🎯 운영 목표

### 가용성 목표
- **서비스 가용성**: 99.9% (월 43분 다운타임 허용)
- **데이터베이스 가용성**: 99.95% (월 22분 다운타임 허용)
- **복구 시간 목표 (RTO)**: 30분 이내
- **복구 지점 목표 (RPO)**: 1시간 이내

### 성능 목표
- **응답 시간**: P95 < 500ms
- **처리량**: 1000 RPS
- **에러율**: < 0.1%

## 🔄 일상 운영 절차

### 매일 체크리스트

#### 1. 시스템 상태 확인 (오전 9시)
```bash
# 전체 서비스 상태 확인
cd terraform
bash scripts/validate-infrastructure.sh

# ECS 서비스 상태
aws ecs describe-services --cluster petclinic-dev-cluster \
  --services petclinic-dev-app --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'

# Aurora 클러스터 상태
aws rds describe-db-clusters --db-cluster-identifier petclinic-dev-aurora \
  --query 'DBClusters[0].{Status:Status,Engine:Engine,MultiAZ:MultiAZ}'

# ALB 상태
aws elbv2 describe-load-balancers --names petclinic-dev-alb \
  --query 'LoadBalancers[0].{State:State.Code,DNS:DNSName}'
```

#### 2. 리소스 사용량 확인
```bash
# CloudWatch 메트릭 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=petclinic-dev-app \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum

# Aurora 연결 수 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBClusterIdentifier,Value=petclinic-dev-aurora \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum
```

#### 3. 로그 확인
```bash
# ECS 서비스 로그 (최근 1시간)
aws logs filter-log-events \
  --log-group-name /ecs/petclinic-dev-app \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --filter-pattern "ERROR"

# ALB 액세스 로그 확인 (S3에 저장된 경우)
aws s3 ls s3://petclinic-dev-alb-logs/$(date +%Y/%m/%d)/ --recursive
```

### 주간 체크리스트 (매주 월요일)

#### 1. 보안 업데이트 확인
```bash
# ECR 이미지 스캔 결과 확인
aws ecr describe-image-scan-findings \
  --repository-name petclinic-dev-app \
  --image-id imageTag=latest

# 보안 그룹 규칙 검토
aws ec2 describe-security-groups \
  --filters "Name=tag:Project,Values=petclinic" \
  --query 'SecurityGroups[*].{GroupId:GroupId,GroupName:GroupName,IpPermissions:IpPermissions}'
```

#### 2. 백업 상태 확인
```bash
# Aurora 자동 백업 확인
aws rds describe-db-cluster-snapshots \
  --db-cluster-identifier petclinic-dev-aurora \
  --snapshot-type automated \
  --max-items 7

# 수동 스냅샷 생성 (주간)
aws rds create-db-cluster-snapshot \
  --db-cluster-identifier petclinic-dev-aurora \
  --db-cluster-snapshot-identifier petclinic-dev-aurora-weekly-$(date +%Y%m%d)
```

#### 3. 비용 분석
```bash
# 태그 기반 비용 확인
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

### 월간 체크리스트 (매월 1일)

#### 1. 성능 리뷰
```bash
# 월간 성능 리포트 생성
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=app/petclinic-dev-alb/xxx \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Average,Maximum
```

#### 2. 용량 계획
```bash
# 리소스 사용량 트렌드 분석
# ECS 태스크 수 변화
# Aurora 연결 수 변화
# 스토리지 사용량 변화
```

#### 3. 보안 감사
```bash
# CloudTrail 로그 분석
# Config 규칙 준수 확인
# IAM 정책 검토
```

## 🚨 장애 대응 절차

### 심각도 분류

| 심각도 | 정의 | 대응 시간 | 예시 |
|--------|------|-----------|------|
| **P0 - Critical** | 서비스 완전 중단 | 15분 이내 | 전체 서비스 다운 |
| **P1 - High** | 주요 기능 장애 | 1시간 이내 | 데이터베이스 연결 실패 |
| **P2 - Medium** | 부분 기능 장애 | 4시간 이내 | 특정 API 응답 지연 |
| **P3 - Low** | 성능 저하 | 24시간 이내 | 로그 수집 지연 |

### P0 - Critical 장애 대응

#### 1. 즉시 대응 (0-15분)
```bash
# 1. 장애 확인 및 알림
echo "P0 장애 발생 - $(date)" | slack-notify #incident

# 2. 전체 서비스 상태 확인
aws ecs describe-services --cluster petclinic-dev-cluster --services petclinic-dev-app
aws rds describe-db-clusters --db-cluster-identifier petclinic-dev-aurora
aws elbv2 describe-target-health --target-group-arn <TARGET_GROUP_ARN>

# 3. 로드밸런서 헬스체크 확인
curl -f http://$(aws elbv2 describe-load-balancers --names petclinic-dev-alb --query 'LoadBalancers[0].DNSName' --output text)/actuator/health
```

#### 2. 원인 분석 (15-30분)
```bash
# ECS 서비스 로그 확인
aws logs tail /ecs/petclinic-dev-app --since 30m

# Aurora 이벤트 확인
aws rds describe-events --source-identifier petclinic-dev-aurora --source-type db-cluster

# CloudWatch 알람 상태 확인
aws cloudwatch describe-alarms --state-value ALARM
```

#### 3. 복구 작업 (30분 이내)
```bash
# ECS 서비스 재시작
aws ecs update-service --cluster petclinic-dev-cluster --service petclinic-dev-app --force-new-deployment

# Aurora 장애 조치 (필요시)
aws rds failover-db-cluster --db-cluster-identifier petclinic-dev-aurora

# 긴급 스케일링 (필요시)
aws ecs update-service --cluster petclinic-dev-cluster --service petclinic-dev-app --desired-count 4
```

### P1 - High 장애 대응

#### 데이터베이스 연결 실패
```bash
# 1. Aurora 클러스터 상태 확인
aws rds describe-db-clusters --db-cluster-identifier petclinic-dev-aurora

# 2. 연결 수 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBClusterIdentifier,Value=petclinic-dev-aurora \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Maximum

# 3. 보안 그룹 확인
aws ec2 describe-security-groups --group-ids <AURORA_SG_ID>

# 4. 연결 풀 재시작 (애플리케이션 재배포)
aws ecs update-service --cluster petclinic-dev-cluster --service petclinic-dev-app --force-new-deployment
```

#### ECS 서비스 불안정
```bash
# 1. 태스크 상태 확인
aws ecs list-tasks --cluster petclinic-dev-cluster --service-name petclinic-dev-app
aws ecs describe-tasks --cluster petclinic-dev-cluster --tasks <TASK_ARN>

# 2. 리소스 사용량 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=petclinic-dev-app

# 3. Auto Scaling 조정
aws application-autoscaling put-scaling-policy \
  --policy-name petclinic-dev-app-scale-up \
  --service-namespace ecs \
  --resource-id service/petclinic-dev-cluster/petclinic-dev-app \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-type TargetTrackingScaling
```

### P2 - Medium 장애 대응

#### API 응답 지연
```bash
# 1. ALB 메트릭 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=app/petclinic-dev-alb/xxx

# 2. 데이터베이스 성능 확인
aws rds describe-db-cluster-performance-insights \
  --db-cluster-identifier petclinic-dev-aurora

# 3. 슬로우 쿼리 분석
# Performance Insights 콘솔에서 확인
```

## 📊 모니터링 및 알람

### 핵심 메트릭

#### ECS 서비스 메트릭
```bash
# CPU 사용률 알람 (80% 초과)
aws cloudwatch put-metric-alarm \
  --alarm-name "ECS-CPU-High" \
  --alarm-description "ECS CPU utilization is too high" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2

# 메모리 사용률 알람 (80% 초과)
aws cloudwatch put-metric-alarm \
  --alarm-name "ECS-Memory-High" \
  --alarm-description "ECS Memory utilization is too high" \
  --metric-name MemoryUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

#### Aurora 메트릭
```bash
# 연결 수 알람 (80개 초과)
aws cloudwatch put-metric-alarm \
  --alarm-name "Aurora-Connections-High" \
  --alarm-description "Aurora connection count is too high" \
  --metric-name DatabaseConnections \
  --namespace AWS/RDS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2

# CPU 사용률 알람 (80% 초과)
aws cloudwatch put-metric-alarm \
  --alarm-name "Aurora-CPU-High" \
  --alarm-description "Aurora CPU utilization is too high" \
  --metric-name CPUUtilization \
  --namespace AWS/RDS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

#### ALB 메트릭
```bash
# 5xx 에러 알람 (5% 초과)
aws cloudwatch put-metric-alarm \
  --alarm-name "ALB-5xx-High" \
  --alarm-description "ALB 5xx error rate is too high" \
  --metric-name HTTPCode_Target_5XX_Count \
  --namespace AWS/ApplicationELB \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2

# 응답 시간 알람 (1초 초과)
aws cloudwatch put-metric-alarm \
  --alarm-name "ALB-ResponseTime-High" \
  --alarm-description "ALB response time is too high" \
  --metric-name TargetResponseTime \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

### 대시보드 설정

#### CloudWatch 대시보드 생성
```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ECS", "CPUUtilization", "ServiceName", "petclinic-dev-app"],
          [".", "MemoryUtilization", ".", "."]
        ],
        "period": 300,
        "stat": "Average",
        "region": "ap-northeast-2",
        "title": "ECS Resource Utilization"
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", "petclinic-dev-aurora"],
          [".", "CPUUtilization", ".", "."]
        ],
        "period": 300,
        "stat": "Average",
        "region": "ap-northeast-2",
        "title": "Aurora Performance"
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "app/petclinic-dev-alb/xxx"],
          [".", "TargetResponseTime", ".", "."]
        ],
        "period": 300,
        "stat": "Average",
        "region": "ap-northeast-2",
        "title": "ALB Performance"
      }
    }
  ]
}
```

## 🔧 유지보수 절차

### 정기 유지보수

#### 월간 유지보수 (매월 첫째 주 일요일 02:00-04:00)
```bash
# 1. Aurora 메이저 버전 업그레이드 (필요시)
aws rds modify-db-cluster \
  --db-cluster-identifier petclinic-dev-aurora \
  --engine-version 8.0.mysql_aurora.3.05.2 \
  --apply-immediately

# 2. ECS 플랫폼 버전 업데이트
aws ecs update-service \
  --cluster petclinic-dev-cluster \
  --service petclinic-dev-app \
  --platform-version LATEST

# 3. 불필요한 로그 정리
aws logs delete-log-group --log-group-name /ecs/old-service-logs
```

#### 분기별 유지보수 (분기 첫째 주 일요일)
```bash
# 1. 보안 패치 적용
# ECR 이미지 재빌드 및 배포

# 2. 용량 계획 검토
# 리소스 사용량 트렌드 분석
# Auto Scaling 정책 조정

# 3. 재해 복구 테스트
# 백업 복원 테스트
# Failover 테스트
```

### 애플리케이션 배포

#### 무중단 배포 절차
```bash
# 1. 새 이미지 빌드 및 푸시
docker build -t petclinic-app:v2.1.0 .
docker tag petclinic-app:v2.1.0 <ECR_URI>:v2.1.0
docker push <ECR_URI>:v2.1.0

# 2. 태스크 정의 업데이트
aws ecs register-task-definition \
  --family petclinic-dev-app \
  --task-role-arn <TASK_ROLE_ARN> \
  --execution-role-arn <EXECUTION_ROLE_ARN> \
  --network-mode awsvpc \
  --requires-compatibilities FARGATE \
  --cpu 256 \
  --memory 512 \
  --container-definitions file://container-definitions.json

# 3. 서비스 업데이트 (롤링 배포)
aws ecs update-service \
  --cluster petclinic-dev-cluster \
  --service petclinic-dev-app \
  --task-definition petclinic-dev-app:LATEST

# 4. 배포 상태 모니터링
aws ecs wait services-stable \
  --cluster petclinic-dev-cluster \
  --services petclinic-dev-app
```

#### 롤백 절차
```bash
# 1. 이전 태스크 정의로 롤백
aws ecs update-service \
  --cluster petclinic-dev-cluster \
  --service petclinic-dev-app \
  --task-definition petclinic-dev-app:<PREVIOUS_REVISION>

# 2. 롤백 완료 확인
aws ecs describe-services \
  --cluster petclinic-dev-cluster \
  --services petclinic-dev-app \
  --query 'services[0].deployments'
```

## 📈 성능 최적화

### ECS 최적화
```bash
# 1. 적절한 리소스 할당
# CPU: 256-512 (일반적인 웹 애플리케이션)
# Memory: 512-1024 (JVM 힙 크기 고려)

# 2. Auto Scaling 정책 최적화
aws application-autoscaling put-scaling-policy \
  --policy-name petclinic-cpu-scaling \
  --service-namespace ecs \
  --resource-id service/petclinic-dev-cluster/petclinic-dev-app \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 70.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
    },
    "ScaleOutCooldown": 300,
    "ScaleInCooldown": 300
  }'
```

### Aurora 최적화
```bash
# 1. 연결 풀 최적화
# 애플리케이션에서 HikariCP 설정 조정
# maximum-pool-size: 20-30
# minimum-idle: 5-10

# 2. 읽기 전용 엔드포인트 활용
# 읽기 쿼리는 Reader 엔드포인트 사용
# 쓰기 쿼리는 Writer 엔드포인트 사용

# 3. Performance Insights 활용
aws rds describe-db-cluster-performance-insights \
  --db-cluster-identifier petclinic-dev-aurora
```

## 📞 연락처 및 에스컬레이션

### 운영팀 연락처
- **Primary On-call**: Slack @oncall-primary
- **Secondary On-call**: Slack @oncall-secondary
- **Manager**: Slack @team-manager

### 에스컬레이션 매트릭스
| 시간 | P0 | P1 | P2 | P3 |
|------|----|----|----|----|
| **0-15분** | Primary On-call | Primary On-call | Primary On-call | - |
| **15-30분** | + Secondary On-call | Primary On-call | Primary On-call | Primary On-call |
| **30-60분** | + Manager | + Secondary On-call | Primary On-call | Primary On-call |
| **1시간+** | + Director | + Manager | + Secondary On-call | Primary On-call |

### 외부 지원
- **AWS Support**: Enterprise Support Plan
- **Terraform Support**: Community + HashiCorp Documentation
- **Application Support**: Development Team

---

**이 가이드는 정기적으로 업데이트되어야 하며, 실제 운영 경험을 바탕으로 개선되어야 합니다.**