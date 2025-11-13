# 모니터링 아키텍처 다이어그램

## Draw.io Import용 Mermaid 코드

```mermaid
graph TD
    %% 사용자 요청 흐름
    subgraph "사용자 요청"
        U[👤 User]
    end

    subgraph "인프라 컴포넌트"
        DNS[🌐 Route 53<br/>DNS 헬스체크]
        CF[🌐 CloudFront<br/>접속 로그<br/>캐시 통계]
        WAF[🛡️ WAF<br/>공격 차단 통계]
        ALB[⚖️ ALB<br/>요청 수<br/>응답 시간<br/>HTTP 상태]
        ECS[🐳 ECS Services<br/>CPU/메모리<br/>작업 수]
        RDS[💾 RDS Aurora<br/>연결 수<br/>쿼리 성능]
        CACHE[🔄 ElastiCache<br/>캐시 적중률]
    end

    subgraph "모니터링 수집"
        CW[📊 CloudWatch<br/>통합 모니터링]
        CI[🔍 Container Insights<br/>작업별 상세 메트릭]
        XRAY[🎯 AWS X-Ray<br/>분산 추적]
        CT[📋 CloudTrail<br/>감사 로그]
    end

    subgraph "분석 및 시각화"
        DASH[📈 대시보드<br/>6개 위젯<br/>실시간 모니터링]
        LOGS[📝 로그 분석<br/>Logs Insights<br/>에러 패턴 분석]
    end

    subgraph "알림 및 대응"
        ALARMS[🚨 알람 시스템<br/>20개 알람<br/>자동 임계치 모니터링]
        SNS[📢 SNS 알림<br/>이메일/SMS/Slack]
        AUTO[🔄 자동화<br/>Lambda 복구<br/>Auto Scaling]
    end

    %% 데이터 흐름
    U --> DNS
    DNS --> CF
    CF --> WAF
    WAF --> ALB
    ALB --> ECS
    ECS --> RDS
    ECS --> CACHE

    %% 모니터링 데이터 수집
    DNS -.->|헬스체크| CW
    CF -.->|접속 로그| CW
    WAF -.->|차단 통계| CW
    ALB -.->|요청/응답| CW
    ECS -.->|CPU/메모리| CW
    ECS -.->|상세 메트릭| CI
    RDS -.->|DB 메트릭| CW
    CACHE -.->|캐시 메트릭| CW

    ECS -.->|분산 추적| XRAY
    ALB -.->|감사 로그| CT

    %% 분석 및 시각화
    CW --> DASH
    CI --> DASH
    CW --> LOGS

    %% 알림 및 대응
    CW --> ALARMS
    ALARMS --> SNS
    ALARMS --> AUTO

    %% 스타일 설정
    classDef infra fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef monitor fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef analysis fill:#e8f5e8,stroke:#388e3c,stroke-width:2px
    classDef alert fill:#fff3e0,stroke:#f57c00,stroke-width:2px

    class DNS,CF,WAF,ALB,ECS,RDS,CACHE infra
    class CW,CI,XRAY,CT monitor
    class DASH,LOGS analysis
    class ALARMS,SNS,AUTO alert
```

## Draw.io로 Import하는 방법

1. [draw.io](https://app.diagrams.net/) 웹사이트 열기
2. **File → Import → Mermaid...** 선택
3. 위의 Mermaid 코드를 복사해서 붙여넣기
4. **Import** 버튼 클릭
5. 다이어그램이 자동으로 생성됨

## 다이어그램 설명

### 🔵 파란색 (Infra): 인프라 컴포넌트
- 실제 AWS 서비스들
- 모니터링 데이터의 소스

### 🟣 보라색 (Monitor): 모니터링 수집
- CloudWatch, Container Insights 등
- 메트릭과 로그를 수집하는 서비스들

### 🟢 초록색 (Analysis): 분석 및 시각화
- 대시보드와 로그 분석
- 사람이 데이터를 이해하는 인터페이스

### 🟠 주황색 (Alert): 알림 및 대응
- 알람과 자동화 시스템
- 문제가 발생했을 때의 대응 메커니즘

## 주요 모니터링 메트릭

| 컴포넌트 | 주요 메트릭 | 임계치 알람 |
|---------|-------------|-------------|
| **ECS** | CPUUtilization, MemoryUtilization | >80% (5분) |
| **ALB** | RequestCount, TargetResponseTime | >3초 (5분) |
| **RDS** | DatabaseConnections, CPUUtilization | >80 (5분) |
| **WAF** | BlockedRequests, AllowedRequests | 공격 패턴 |

## 비용 구조

```
월간 모니터링 비용: $7.80
├── 알람 (20개): $2.00
├── 로그 수집 (5GB): $2.50
├── 로그 스토리지 (10GB): $0.30
└── Container Insights (6개): $3.00