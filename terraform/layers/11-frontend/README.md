# 11-frontend 레이어 🎨

## 목차
- [개요](#개요)
- [S3 + CloudFront 기초 개념](#s3--cloudfront-기초-개념)
- [우리가 만드는 프론트엔드 호스팅 구조](#우리가-만드는-프론트엔드-호스팅-구조)
- [배포 방법](#배포-방법)
- [GitHub Actions 자동 배포](#github-actions-자동-배포)
- [코드 구조](#코드-구조)
- [문제 해결](#문제-해결)

---

## 개요

**11-frontend 레이어**는 Spring PetClinic 프론트엔드를 **S3 + CloudFront**로 호스팅하는 레이어입니다.

### 이 레이어가 하는 일
- ✅ **S3 정적 웹사이트 호스팅**: HTML, CSS, JS 파일 저장
- ✅ **CloudFront CDN**: 전 세계 빠른 콘텐츠 전송
- ✅ **OAI (Origin Access Identity)**: S3 직접 접근 차단
- ✅ **SPA 라우팅**: React/Vue 등 SPA 지원
- ✅ **GitHub Actions 자동 배포**: Push 시 자동 배포

### 다른 레이어와의 관계
```
08-api-gateway (API Gateway)
    ↓ (API URL 참조)
11-frontend (이 레이어) 🎨
    ↓
    ├─→ S3 Bucket (정적 파일 저장)
    └─→ CloudFront (CDN 배포)
        ↓
        Client (브라우저)
```

### 왜 S3 + CloudFront인가요?

**기존 방식 (ECS 웹 서버)**:
```
Client → ALB → ECS (Nginx) → 정적 파일
❌ 비용 높음 (ECS 컨테이너 실행)
❌ 확장성 제한 (Auto Scaling 필요)
❌ 느림 (단일 리전)
```

**새 방식 (S3 + CloudFront)**:
```
Client → CloudFront (CDN) → S3 (정적 파일)
✅ 비용 저렴 (스토리지 + 데이터 전송만)
✅ 무한 확장 (AWS 자동 처리)
✅ 빠름 (글로벌 엣지 로케이션)
```

---

## S3 + CloudFront 기초 개념

### 1. S3 정적 웹사이트 호스팅 🗄️

**S3 (Simple Storage Service)**: 파일 저장 서비스

**정적 웹사이트**: 서버 없이 브라우저에서 직접 실행되는 웹사이트
```
정적 파일:
- HTML (.html)
- CSS (.css)
- JavaScript (.js)
- 이미지 (.png, .jpg)
- 폰트 (.woff, .ttf)
```

**S3 웹사이트 호스팅 설정**:
```hcl
# S3 버킷 생성
bucket_name = "petclinic-dev-frontend-dev"

# 정적 웹사이트 호스팅 활성화
website {
  index_document = "index.html"
  error_document = "error.html"
}
```

**동작 원리**:
```
1. 브라우저 요청
   GET http://petclinic-dev-frontend-dev.s3-website-us-west-2.amazonaws.com/

2. S3 응답
   → index.html 반환

3. 브라우저 렌더링
   → HTML 파싱 → CSS/JS 로드 → 화면 표시
```

---

### 2. CloudFront CDN 🌍

**CDN (Content Delivery Network)**: 전 세계에 콘텐츠를 **빠르게 전송**하는 네트워크

**CloudFront 동작 원리**:
```
사용자 위치: 서울
Origin (S3): us-west-2 (오레곤)

CloudFront 없이:
Client (서울) → S3 (오레곤)  # 10,000km, 200ms 지연

CloudFront 있으면:
Client (서울) → CloudFront Edge (서울) → S3 (오레곤)
                     ↑ 캐시 히트!       # 1ms 지연
```

**Edge Location (엣지 로케이션)**:
```
CloudFront는 전 세계 400+ 엣지 로케이션 보유:
- 서울 (4개)
- 도쿄 (19개)
- 싱가포르 (4개)
- 미국 (70+개)
- 유럽 (50+개)
```

**캐싱 동작**:
```
1. 첫 번째 요청 (서울 사용자)
   Client → CloudFront 서울 → S3 오레곤 (200ms)
   → CloudFront 서울에 캐시 저장

2. 두 번째 요청 (서울 사용자)
   Client → CloudFront 서울 (캐시 히트!) (1ms)
   → S3 접근 불필요!

3. 다른 사용자 (도쿄)
   Client → CloudFront 도쿄 → S3 오레곤 (150ms)
   → CloudFront 도쿄에 캐시 저장
```

---

### 3. OAI (Origin Access Identity) 🔒

**문제**: S3를 Public으로 설정하면 누구나 직접 접근 가능
```
악의적 사용자:
http://petclinic-dev-frontend-dev.s3.amazonaws.com/secret.html
→ 직접 접근 가능! (CloudFront 우회)
```

**해결**: OAI로 CloudFront만 S3 접근 허용
```
S3 Bucket Policy:
{
  "Principal": {
    "AWS": "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity E..."
  },
  "Action": "s3:GetObject",
  "Effect": "Allow"
}
```

**결과**:
```
✅ CloudFront → S3: 허용
❌ 직접 접근 → S3: 거부 (403 Forbidden)
```

---

### 4. SPA 라우팅 (Single Page Application) ⚛️

**SPA**: React, Vue, Angular 등 **단일 HTML로 동작**하는 앱

**SPA 라우팅 문제**:
```
SPA URL:
https://petclinic.example.com/
https://petclinic.example.com/customers
https://petclinic.example.com/vets

S3 파일 구조:
- index.html  (있음)
- /customers  (없음! → 404 에러)
- /vets       (없음! → 404 에러)
```

**해결**: CloudFront Custom Error Response
```hcl
# 404 에러 발생 시 index.html 반환
custom_error_response {
  error_code         = 404
  response_code      = 200
  response_page_path = "/index.html"
}
```

**동작**:
```
1. 사용자 요청
   GET /customers

2. S3 확인
   /customers 파일 없음 → 404

3. CloudFront 처리
   404 → index.html 반환 (200 OK)

4. React Router 처리
   index.html 로드 → /customers 라우팅
```

---

## 우리가 만드는 프론트엔드 호스팅 구조

### 전체 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Internet                                    │
│  ┌──────────────┐                                                   │
│  │  Client      │  (브라우저)                                        │
│  └──────┬───────┘                                                   │
└─────────┼───────────────────────────────────────────────────────────┘
          │
          │ HTTPS
          ↓
┌─────────────────────────────────────────────────────────────────────┐
│  ╔═══════════════════════════════════════════════════════════════╗  │
│  ║  CloudFront Distribution                                      ║  │
│  ║  https://d123abc456xyz.cloudfront.net                         ║  │
│  ║                                                                ║  │
│  ║  ┌──────────────────────────────────────────────────────┐    ║  │
│  ║  │  Edge Location (서울)                                 │    ║  │
│  ║  │  - 캐시: index.html, app.js, styles.css              │    ║  │
│  ║  │  - TTL: 86400초 (24시간)                             │    ║  │
│  ║  └──────────────────────────────────────────────────────┘    ║  │
│  ║                                                                ║  │
│  ║  ┌──────────────────────────────────────────────────────┐    ║  │
│  ║  │  Custom Error Response                                │    ║  │
│  ║  │  - 404 → index.html (SPA 라우팅)                      │    ║  │
│  ║  └──────────────────────────────────────────────────────┘    ║  │
│  ╚═══════════════════════════════════════════════════════════════╝  │
│                          │                                           │
│                          │ OAI (Origin Access Identity)              │
│                          ↓                                           │
│  ╔═══════════════════════════════════════════════════════════════╗  │
│  ║  S3 Bucket (정적 웹사이트)                                     ║  │
│  ║  petclinic-dev-frontend-dev                                   ║  │
│  ║                                                                ║  │
│  ║  파일 구조:                                                     ║  │
│  ║  - index.html                                                 ║  │
│  ║  - /static/                                                   ║  │
│  ║      - css/                                                   ║  │
│  ║          - app.css                                            ║  │
│  ║      - js/                                                    ║  │
│  ║          - app.js                                             ║  │
│  ║      - images/                                                ║  │
│  ║          - logo.png                                           ║  │
│  ║                                                                ║  │
│  ║  버킷 정책:                                                     ║  │
│  ║  - CloudFront OAI만 접근 허용                                  ║  │
│  ║  - 직접 Public 접근 차단                                       ║  │
│  ╚═══════════════════════════════════════════════════════════════╝  │
└─────────────────────────────────────────────────────────────────────┘

외부 통합:
┌────────────────────────────┐
│  API Gateway               │  ← 프론트엔드에서 API 호출
│  /api/customers            │
│  /api/vets                 │
│  /api/visits               │
└────────────────────────────┘
```

---

## 배포 방법

### 방법 1: GitHub Actions 자동 배포 (권장) 🤖

#### 1단계: 인프라 배포
```bash
cd terraform/layers/11-frontend
terraform init -backend-config=../../backend.hcl -backend-config=backend.config
terraform apply -var-file=../../envs/dev.tfvars
```

#### 2단계: GitHub Secrets 설정
```bash
# GitHub Repository → Settings → Secrets and variables → Actions

# 추가할 Secrets:
AWS_ACCESS_KEY_ID: AKIAI...
AWS_SECRET_ACCESS_KEY: wJalr...
CLOUDFRONT_DISTRIBUTION_DEV: E1A2B3C4D5E6F7  # terraform output에서 확인
```

#### 3단계: 프론트엔드 파일 변경 및 Push
```bash
# 프론트엔드 파일 수정
echo "Updated" >> spring-petclinic-api-gateway/src/main/resources/static/index.html

# Git 커밋 및 Push
git add .
git commit -m "Update frontend"
git push origin main

# → GitHub Actions 자동 실행!
```

#### 4단계: 배포 확인
```bash
# GitHub Actions 탭에서 실시간 모니터링
# 또는 CloudFront URL 접속
open "https://$(terraform output -raw cloudfront_distribution_domain_name)"
```

---

### 방법 2: 수동 배포 📦

#### 1단계: 로컬 파일 확인
```bash
# 프론트엔드 파일 위치
ls -la spring-petclinic-api-gateway/src/main/resources/static/

# 출력:
# index.html
# /static/css/
# /static/js/
```

#### 2단계: S3 업로드
```bash
# 버킷 이름 확인
BUCKET_NAME=$(terraform output -raw s3_bucket_name)
echo $BUCKET_NAME
# petclinic-dev-frontend-dev

# 파일 동기화
aws s3 sync \
  spring-petclinic-api-gateway/src/main/resources/static/ \
  s3://${BUCKET_NAME}/ \
  --delete \
  --exclude ".git/*"

# --delete: S3에 있지만 로컬에 없는 파일 삭제
# --exclude: 특정 파일/폴더 제외
```

#### 3단계: CloudFront 캐시 무효화
```bash
# Distribution ID 확인
DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id)
echo $DISTRIBUTION_ID
# E1A2B3C4D5E6F7

# 전체 캐시 무효화
aws cloudfront create-invalidation \
  --distribution-id ${DISTRIBUTION_ID} \
  --paths '/*'

# 특정 파일만 무효화
aws cloudfront create-invalidation \
  --distribution-id ${DISTRIBUTION_ID} \
  --paths '/index.html' '/static/css/*'
```

#### 4단계: 무효화 완료 확인
```bash
# 무효화 상태 확인
aws cloudfront get-invalidation \
  --distribution-id ${DISTRIBUTION_ID} \
  --id I1A2B3C4D5E6F7

# Status: "Completed" 확인 (최대 15분 소요)
```

---

## GitHub Actions 자동 배포

### Workflow 파일 위치
```
.github/workflows/deploy-frontend.yml
```

### Workflow 구성

```yaml
name: Deploy Frontend

on:
  push:
    branches: [ main ]
    paths:
      - 'spring-petclinic-api-gateway/src/main/resources/static/**'
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-west-2
      
      - name: Sync to S3
        run: |
          aws s3 sync \
            spring-petclinic-api-gateway/src/main/resources/static/ \
            s3://petclinic-dev-frontend-dev/ \
            --delete
      
      - name: Invalidate CloudFront cache
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_DEV }} \
            --paths '/*'
```

### 트리거 조건

1. **Push 트리거**: `main` 브랜치에 `static/` 폴더 변경 시
2. **수동 트리거**: GitHub Actions 탭에서 "Run workflow" 버튼

### 배포 프로세스

```
1. 코드 Checkout
   ↓
2. AWS 인증 (Secrets)
   ↓
3. S3 동기화 (변경된 파일만)
   ↓
4. CloudFront 캐시 무효화
   ↓
5. 배포 완료 (2-3분)
   ↓
6. 캐시 전파 (최대 15분)
```

---

## 코드 구조

### 파일 구성

```
11-frontend/
├── main.tf              # S3, CloudFront 모듈 호출
├── data.tf              # API Gateway 참조
├── variables.tf         # 변수 정의
├── outputs.tf           # 출력값 (URL, 버킷 이름 등)
├── backend.tf           # Terraform 상태 저장
├── backend.config       # 백엔드 키 설정
├── ../../envs/dev.tfvars     # 실제 값 입력
└── README.md            # 이 문서
```

---

### main.tf 주요 구성

```hcl
# S3 프론트엔드 호스팅
module "s3_frontend" {
  source = "../../modules/s3-frontend"

  name_prefix = "petclinic"
  environment = "dev"
  tags        = local.common_tags

  enable_versioning     = true
  enable_access_logging = false
  log_retention_days    = 30
  enable_cors           = true
}

# CloudFront CDN
module "cloudfront" {
  source = "../../modules/cloudfront"

  name_prefix = "petclinic"
  environment = "dev"
  tags        = local.common_tags

  # S3 연결
  s3_bucket_name                 = module.s3_frontend.bucket_name
  s3_bucket_regional_domain_name = module.s3_frontend.bucket_regional_domain_name
  cloudfront_oai_path            = module.s3_frontend.cloudfront_oai_path

  # API Gateway 통합
  enable_api_gateway_integration = true
  api_gateway_domain_name        = local.api_gateway_domain_name

  # 기본 설정
  price_class             = "PriceClass_100"
  enable_spa_routing      = true
  enable_cors_headers     = false
  use_default_certificate = true
  acm_certificate_arn     = null
  enable_logging          = false
  log_bucket_domain_name  = module.s3_frontend.bucket_regional_domain_name
  log_prefix              = "cloudfront/"
  web_acl_arn             = null
  enable_monitoring       = true
  error_4xx_threshold     = 5
  error_5xx_threshold     = 2
  alarm_actions           = ["arn:aws:sns:us-west-2:123456789012:petclinic-dev-alerts"]
}
```

---

## 문제 해결

### 문제 1: CloudFront에서 404 에러
```
https://d123abc.cloudfront.net/customers
→ 404 Not Found
```

**원인**: SPA 라우팅 미설정

**해결**:
```hcl
# CloudFront Custom Error Response 확인
enable_spa_routing = true

# 수동 확인
aws cloudfront get-distribution-config \
  --id E1A2B3C4D5E6F7 \
  --query 'DistributionConfig.CustomErrorResponses'

# 출력:
# ErrorCode: 404
# ResponseCode: 200
# ResponsePagePath: /index.html
```

---

### 문제 2: 캐시가 업데이트되지 않음
```
파일 업데이트했는데 이전 버전 표시됨
```

**원인**: CloudFront 캐시 TTL (24시간)

**해결**:
```bash
# 즉시 캐시 무효화
aws cloudfront create-invalidation \
  --distribution-id E1A2B3C4D5E6F7 \
  --paths '/*'

# 또는 특정 파일만
aws cloudfront create-invalidation \
  --distribution-id E1A2B3C4D5E6F7 \
  --paths '/index.html' '/static/js/app.js'

# 무효화 비용: 1000개 경로까지 무료, 이후 $0.005/개
```

**예방**:
```html
<!-- HTML에서 캐시 무효화 (Cache Busting) -->
<script src="/static/js/app.js?v=1.0.1"></script>
<link rel="stylesheet" href="/static/css/app.css?v=1.0.1">
```

---

### 문제 3: S3 직접 접근 가능
```
http://petclinic-dev-frontend-dev.s3.amazonaws.com/index.html
→ 접근 가능 (보안 위험!)
```

**원인**: S3 Public 설정

**해결**:
```bash
# S3 Bucket Policy 확인
aws s3api get-bucket-policy \
  --bucket petclinic-dev-frontend-dev \
  --query 'Policy' --output text | jq '.'

# OAI만 허용하는지 확인
# Principal: "AWS": "arn:aws:iam::cloudfront:user/..."
# Effect: "Allow"
# Action: "s3:GetObject"
```

---

### 문제 4: GitHub Actions 실패
```
Error: Access Denied
```

**디버깅**:

1. **AWS 인증 확인**
```bash
# 로컬에서 테스트
aws sts get-caller-identity
# 출력: UserId, Account, Arn
```

2. **S3 권한 확인**
```bash
aws s3 ls s3://petclinic-dev-frontend-dev/
# 출력: 파일 목록
```

3. **CloudFront 권한 확인**
```bash
aws cloudfront list-distributions \
  --query 'DistributionList.Items[?Id==`E1A2B3C4D5E6F7`]'
```

---

### 디버깅 명령어

```bash
# S3 버킷 파일 목록
aws s3 ls s3://petclinic-dev-frontend-dev/ --recursive

# CloudFront Distribution 상태
aws cloudfront get-distribution --id E1A2B3C4D5E6F7

# 캐시 무효화 목록
aws cloudfront list-invalidations --distribution-id E1A2B3C4D5E6F7

# CloudFront 액세스 로그
aws s3 ls s3://petclinic-dev-frontend-dev/cloudfront-logs/ --recursive

# S3 버전 목록 (버전 관리 활성화 시)
aws s3api list-object-versions \
  --bucket petclinic-dev-frontend-dev \
  --prefix index.html
```

---

## 비용 예상

### 주요 비용 요소

| 구성 요소 | 사양 | 월 비용 (USD) |
|----------|------|---------------|
| **S3 스토리지** | 1GB | $0.023 |
| **S3 요청** | 1만 GET 요청 | $0.004 |
| **CloudFront 데이터 전송** | 10GB (북미, 유럽) | $0.85 ($0.085/GB) |
| **CloudFront 요청** | 1만 요청 | $0.01 |
| **CloudFront 캐시 무효화** | 월 100회 | $0.00 (1000회까지 무료) |
| **합계** | - | **$0.89** |

**비용 최적화 팁**:
- Price Class: PriceClass_100 (북미, 유럽만) → 비용 30% 절감
- 캐시 TTL: 24시간 이상 → 요청 수 감소
- 압축: Gzip 활성화 → 데이터 전송량 60% 절감

---

## 베스트 프랙티스

### 1. 배포 전략
```bash
# Feature 브랜치 작업
git checkout -b feature/frontend-update
# 변경사항 커밋
git commit -m "Update landing page"

# Dev 환경 테스트
git push origin feature/frontend-update
# Pull Request 생성 → dev 배포

# 테스트 통과 후 main 병합
git checkout main
git merge feature/frontend-update
git push origin main
# → Production 배포
```

### 2. 캐시 전략
```
파일 타입별 TTL:
- HTML: 0초 (즉시 반영)
- CSS/JS: 86400초 (24시간)
- 이미지: 604800초 (7일)
```

### 3. 모니터링
```bash
# CloudWatch 메트릭
- CloudFront Requests
- CloudFront Bytes Downloaded
- CloudFront 4XX/5XX Error Rate
- S3 Bucket Size
```

### 4. 보안
```
✅ S3 Public Access 차단
✅ OAI로 CloudFront만 허용
✅ HTTPS 강제 (HTTP → HTTPS 리다이렉트)
✅ WAF 통합 (선택)
```

---

## 요약

### 핵심 개념 정리
- ✅ **S3**: 정적 파일 저장 (HTML, CSS, JS)
- ✅ **CloudFront**: 전 세계 빠른 콘텐츠 전송 (CDN)
- ✅ **OAI**: CloudFront만 S3 접근 허용
- ✅ **SPA 라우팅**: 404 → index.html 리다이렉트
- ✅ **GitHub Actions**: Push 시 자동 배포

### 생성되는 주요 리소스
- S3 Bucket 1개 (정적 웹사이트)
- CloudFront Distribution 1개
- CloudFront OAI 1개

### 배포 흐름
```bash
# 자동 배포
코드 변경 → Git Push → GitHub Actions → S3 동기화 → CloudFront 캐시 무효화 → 완료

# 수동 배포
aws s3 sync → aws cloudfront create-invalidation → 완료
```

### 접속 URL
```bash
# CloudFront URL
https://d123abc456xyz.cloudfront.net

# 커스텀 도메인 (선택)
https://petclinic.example.com
```

---

**작성일**: 2025-11-09  
**작성자**: 황영현 
**버전**: 2.0
