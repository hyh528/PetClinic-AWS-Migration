# Spring PetClinic CI/CD Pipeline Architecture

## 🚀 CI/CD 파이프라인 개요

```
┌─────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   👨‍💻 Dev    │────▶│   📋 Git Push      │────▶│   🔄 GitHub Actions │
│             │     │   (main branch)   │     │   워크플로우 트리거  │
└─────────────┘     └─────────────────┘     └─────────────────┘
                                                         │
                                                         ▼
┌─────────────────────────────────────────────────────────┐
│                🔄 GitHub Actions 워크플로우                 │
├─────────────────────────────────────────────────────────┤
│ 1. 📋 Checkout Code                                   │
│ 2. 🏗️ Setup Java 17                                    │
│ 3. 📦 Build JAR (Maven)                               │
│ 4. 🐳 Build Docker Image                              │
│ 5. 📤 Push to ECR                                     │
│ 6. 🚀 Update ECS Service                              │
│ 7. 🩺 Health Check                                    │
│ 8. 📊 Notifications                                   │
└─────────────────────────────────────────────────────────┘
```

## 📋 상세 CI/CD 흐름도

### **Phase 1: 트리거 (Trigger)**
```
👨‍💻 Developer
    │
    ├── 📝 Code Changes
    ├── 🧪 Tests Added
    └── 📚 Documentation Updated
    │
    ▼
🔄 Git Push (main/master branch)
    │
    ▼
🎣 GitHub Actions Webhook
    │
    ▼
▶️ Workflow Started
```

### **Phase 2: 테스트 및 빌드 (Test & Build)**
```
▶️ Workflow Started
    │
    ├── 📋 Checkout Repository
    │   └── 🔑 GitHub Token Authentication
    │
    ├── 🏗️ Setup Environment
    │   ├── ☕ Java 17 JDK
    │   ├── 🐳 Docker Engine
    │   └── ☁️ AWS CLI
    │
    ├── 🧪 Testing Phase
    │   ├── 🔧 Maven Compile
    │   ├── 🧪 Unit Tests (JUnit)
    │   ├── 📊 Code Coverage (JaCoCo)
    │   ├── 🔍 Static Analysis (SonarQube)
    │   ├── 🐳 Docker Image Security (Trivy)
    │   └── 📋 Test Reports Generation
    │
    ├── 📦 Application Build
    │   ├── 🔧 Maven Package (skip tests)
    │   └── 📦 JAR Packaging
    │
    └── 🐳 Docker Build
        ├── 📋 Dockerfile
        ├── 📦 JAR Copy
        └── 🏷️ Image Tagging
```

### **Phase 3: 배포 (Deploy)**
```
🐳 Docker Image Built
    │
    ▼
📤 Push to Amazon ECR
    │
    ├── 🔐 AWS Credentials (OIDC)
    ├── 🏷️ Image Tag: latest/v1.0.0
    └── 📍 Repository: petclinic-dev-*
    │
    ▼
🚀 Update ECS Service
    │
    ├── 📋 Task Definition Update
    │   └── 🏷️ New Image URI
    │
    ├── 🔄 Rolling Deployment
    │   ├── 📊 Desired Count: 2-4
    │   └── 🔄 Minimum Healthy: 50%
    │
    └── 🩺 Health Checks
        ├── 🌐 ALB Target Group
        ├── 💓 Application Health (/actuator/health)
        └── ⏱️ Timeout: 300s
```

### **Phase 4: 검증 및 알림 (Verification & Notification)**
```
🩺 Health Checks Passed
    │
    ▼
📊 Monitoring & Notifications
    │
    ├── ✅ Success Notification
    │   ├── 💬 Slack Channel
    │   └── 📧 Email Alerts
    │
    ├── 📈 Metrics Collection
    │   ├── ⏱️ Deployment Duration
    │   ├── 📊 Success Rate
    │   └── 🔍 Error Logs
    │
    └── 🔄 Rollback Ready
        └── ↩️ Previous Version Available
```

## 🛠️ 기술 스택 및 도구

### **버전 관리:**
- **Git**: 분산 버전 관리
- **GitHub**: 리포지토리 호스팅
- **GitHub Actions**: CI/CD 플랫폼

### **빌드 도구:**
- **Java 17**: 런타임 환경
- **Maven**: 의존성 관리 및 빌드
- **Docker**: 컨테이너화

### **컨테이너 레지스트리:**
- **Amazon ECR**: 프라이빗 컨테이너 레지스트리
- **Multi-Architecture**: AMD64 지원

### **오케스트레이션:**
- **Amazon ECS**: 컨테이너 오케스트레이션
- **Fargate**: 서버리스 컨테이너
- **Application Load Balancer**: 트래픽 분산

### **모니터링:**
- **CloudWatch**: 로그 및 메트릭
- **X-Ray**: 분산 트레이싱
- **Health Checks**: 애플리케이션 상태 확인

## 🔄 워크플로우 파일 구조

```
.github/workflows/
├── 🚀 deploy-backend.yml          # 백엔드 배포
├── 🎨 deploy-frontend.yml         # 프론트엔드 배포
└── 🔧 terraform-checks.yml        # 인프라 검증
```

### **테스트 전략:**

#### **1. 단위 테스트 (Unit Tests)**
- **프레임워크**: JUnit 5 + Mockito
- **커버리지**: JaCoCo (80% 이상 목표)
- **실행**: `./mvnw test`
- **보고서**: `target/site/jacoco/index.html`

#### **2. 통합 테스트 (Integration Tests)**
- **환경**: TestContainers + LocalStack
- **데이터베이스**: H2/MySQL 테스트
- **API 테스트**: SpringBootTest
- **실행**: `./mvnw verify`

#### **3. 정적 분석 (Static Analysis)**
- **도구**: SonarQube/SonarCloud
- **품질 게이트**: 버그 차단, 취약점 0개
- **커버리지**: 80% 이상

#### **4. 보안 스캔 (Security Scanning)**
- **컨테이너**: Trivy (취약점 스캔)
- **의존성**: OWASP Dependency Check
- **코드**: Snyk/CodeQL

#### **5. 성능 테스트 (Performance Tests)**
- **도구**: JMeter/Gatling
- **임계값**: 응답시간 <500ms, 에러율 <1%

### **deploy-backend.yml 주요 단계:**
```yaml
name: Deploy Backend
on:
  push:
    branches: [main]
    paths: ['spring-petclinic-*/**']

jobs:
  test-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Run Tests
        run: mvn clean test

      - name: Generate Coverage Report
        run: mvn jacoco:report

      - name: SonarQube Analysis
        uses: sonarsource/sonarqube-scan-action@v2
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}

      - name: Security Scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'

      - name: Build with Maven
        run: mvn clean package -DskipTests

      - name: Build Docker Image
        run: |
          docker build -t petclinic-${{ env.SERVICE_NAME }} .
          docker tag petclinic-${{ env.SERVICE_NAME }}:latest ${{ env.ECR_URI }}:latest

      - name: Scan Docker Image
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'image'
          scan-ref: ${{ env.ECR_URI }}:latest

      - name: Push to ECR
        run: |
          aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin ${{ env.ECR_URI }}
          docker push ${{ env.ECR_URI }}:latest

      - name: Deploy to ECS
        run: |
          aws ecs update-service --cluster petclinic-dev-cluster --service ${{ env.SERVICE_NAME }} --force-new-deployment

      - name: Health Check
        run: |
          # ALB 헬스체크 대기 (300초 타임아웃)
          aws elbv2 wait target-in-service --target-group-arn ${{ env.TARGET_GROUP_ARN }} --targets ${{ env.TASK_ID }}

          # 애플리케이션 헬스체크 확인
          curl -f ${{ env.HEALTH_CHECK_URL }} || exit 1
```

## 📊 배포 메트릭

### **일반적인 배포 시간:**
- **코드 푸시 → 배포 완료**: 10-15분
- **빌드 시간**: 3-5분
- **ECR 푸시**: 2-3분
- **ECS 롤링 업데이트**: 3-5분
- **헬스체크**: 2-3분

### **품질 지표:**
- **테스트 커버리지**: 80%+
- **코드 품질**: A등급 (SonarQube)
- **보안 취약점**: 0개
- **빌드 성공률**: 95%+
- **배포 성공률**: 98%+
- **롤백 빈도**: <5%

## 🚨 장애 대응

### **배포 실패 시:**
1. **알림 전송**: Slack/Email
2. **로그 분석**: CloudWatch Logs
3. **롤백 실행**: 이전 안정 버전으로
4. **원인 분석**: X-Ray 트레이싱

### **헬스체크 실패 시:**
1. **자동 롤백**: 이전 태스크로
2. **알람 발생**: CloudWatch 알람
3. **조사 시작**: 로그/메트릭 분석

---

**CI/CD 버전**: 2.0
**마지막 업데이트**: 2025-11-13
**플랫폼**: GitHub Actions
**대상**: Amazon ECS Fargate