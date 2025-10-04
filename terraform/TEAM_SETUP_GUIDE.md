# 팀원용 Terraform 설정 가이드

## 🚨 현재 상황 요약

**발견된 주요 이슈:**
1. **AWS 프로파일 불일치**: 각 팀원별로 다른 프로파일 사용 중
2. **Application 레이어 오류**: ECS 모듈 task_role_arn 속성 문제  
3. **상태 파일 분산**: 로컬 상태 파일로 관리 중 (원격 상태 필요)

## ⚡ 5분 빠른 해결 방법

### 1단계: AWS 프로파일 통일

현재 각자 다른 프로파일을 사용하고 있어서 오류가 발생합니다.

**해결 방법 A: 기본 프로파일 사용 (권장)**
```bash
# 현재 기본 프로파일 확인
aws sts get-caller-identity

# 기본 프로파일로 설정 (필요시)
aws configure
```

**해결 방법 B: 개인 프로파일 생성**
```bash
# 개인 프로파일 생성 (이름은 자유롭게)
aws configure --profile petclinic-[본인이름]

# 환경 변수로 설정
export AWS_PROFILE=petclinic-[본인이름]  # Linux/Mac
$env:AWS_PROFILE="petclinic-[본인이름]"  # PowerShell
```

### 2단계: 빠른 검증 스크립트 실행

PowerShell에서 실행:
```powershell
# terraform 디렉토리로 이동
cd terraform

# 검증 스크립트 실행
.\validate-quick.ps1
```

### 3단계: 발견된 문제 해결

**Application 레이어 오류 해결:**
```bash
cd envs/dev/application
Remove-Item -Recurse -Force .terraform -ErrorAction SilentlyContinue
terraform init
terraform validate
```

## 🛠️ PowerShell 빠른 검증 스크립트

아래 내용을 `terraform/validate-quick.ps1`로 저장하고 실행하세요:

```powershell
Write-Host "=== Terraform 인프라 검증 시작 ===" -ForegroundColor Blue

# 1. 사전 검증
Write-Host "`n1. 사전 검증 중..." -ForegroundColor Yellow

# Terraform 버전 확인
try {
    $terraformVersion = terraform version
    Write-Host "✅ Terraform: $($terraformVersion.Split("`n")[0])" -ForegroundColor Green
} catch {
    Write-Host "❌ Terraform이 설치되지 않았습니다" -ForegroundColor Red
    exit 1
}

# AWS 자격 증명 확인
try {
    $awsIdentity = aws sts get-caller-identity | ConvertFrom-Json
    Write-Host "✅ AWS 계정: $($awsIdentity.Account)" -ForegroundColor Green
} catch {
    Write-Host "❌ AWS 자격 증명 오류" -ForegroundColor Red
    Write-Host "해결방법: aws configure 실행" -ForegroundColor Yellow
    exit 1
}

# 2. 레이어별 검증
Write-Host "`n2. 레이어별 검증 중..." -ForegroundColor Yellow

$layers = @("network", "security", "database", "application", "monitoring")
$errors = 0

foreach ($layer in $layers) {
    $layerPath = "envs/dev/$layer"
    
    if (Test-Path $layerPath) {
        Write-Host "`n--- $layer 레이어 ---" -ForegroundColor Cyan
        
        Push-Location $layerPath
        
        # 상태 파일 확인
        if (Test-Path "terraform.tfstate") {
            try {
                $stateContent = Get-Content "terraform.tfstate" | ConvertFrom-Json
                $resourceCount = if ($stateContent.resources) { $stateContent.resources.Count } else { 0 }
                Write-Host "  📊 로컬 상태: $resourceCount 리소스" -ForegroundColor Blue
            } catch {
                Write-Host "  📊 로컬 상태: 파일 손상" -ForegroundColor Red
            }
        } else {
            Write-Host "  📊 로컬 상태: 없음" -ForegroundColor Gray
        }
        
        # 문법 검증 (간단히)
        if (Test-Path "main.tf") {
            Write-Host "  ✅ main.tf 존재" -ForegroundColor Green
        } else {
            Write-Host "  ❌ main.tf 누락" -ForegroundColor Red
            $errors++
        }
        
        Pop-Location
    } else {
        Write-Host "⚠️  $layer 레이어 디렉토리 없음" -ForegroundColor Yellow
    }
}

# 3. 결과 요약
Write-Host "`n=== 검증 결과 ===" -ForegroundColor Blue

if ($errors -eq 0) {
    Write-Host "🎉 기본 검증 통과!" -ForegroundColor Green
    Write-Host "`n다음 단계:" -ForegroundColor Yellow
    Write-Host "1. AWS 프로파일 통일"
    Write-Host "2. terraform validate 개별 실행"
    Write-Host "3. 팀 회의에서 배포 계획 논의"
} else {
    Write-Host "❌ $errors 개 문제 발견" -ForegroundColor Red
    Write-Host "`n해결 방법:" -ForegroundColor Yellow
    Write-Host "1. 누락된 파일 확인"
    Write-Host "2. 팀에 도움 요청"
}

Write-Host "`n=== 검증 완료 ===" -ForegroundColor Blue
```

## 📋 팀원별 역할 및 현재 상태

| 팀원 | 담당 레이어 | AWS 프로파일 | 상태 |
|------|-------------|--------------|------|
| 영현 | Network | petclinic-yeonghyeon | ✅ 정상 |
| 휘권 | Security | petclinic-hwigwon | ⚠️ 프로파일 이슈 |
| 준제 | Database | petclinic-jungsu | ⚠️ 확인 필요 |
| 석겸 | Application | petclinic-seokgyeom | ⚠️ ECS 모듈 이슈 |

## 🚀 권장 작업 순서

### 오늘 (긴급)
1. **모든 팀원**: AWS 프로파일 통일
2. **영현**: 상태 관리 인프라 검토 및 배포 준비
3. **석겸**: Application 레이어 오류 수정

### 이번 주
1. **전체**: 원격 상태 마이그레이션
2. **각자**: 담당 레이어 terraform plan 검증
3. **팀 회의**: 배포 계획 및 순서 결정

### 다음 주  
1. **단계별 배포**: Network → Security → Database → Application
2. **모니터링 설정**: CloudWatch 대시보드 구성
3. **문서화**: 운영 가이드 작성

## 🆘 문제 발생 시 대응

### 즉시 중단 상황
- 💰 예상치 못한 비용 발생 알림
- 🗑️ 기존 리소스 삭제 계획 감지
- 🔒 보안 설정 변경 감지

### 연락처
- **Slack**: #devops-terraform
- **긴급**: 영현 (인프라 총괄)
- **이메일**: team@petclinic.com

## 📚 필수 문서

1. **[QUICK_START.md](./QUICK_START.md)** - 5분 빠른 시작
2. **[VALIDATION_GUIDE.md](./VALIDATION_GUIDE.md)** - 상세 검증 가이드  
3. **[CURRENT_ISSUES.md](./CURRENT_ISSUES.md)** - 알려진 이슈 및 해결방안

---

**💡 중요**: 확실하지 않으면 팀에 먼저 문의하세요. 인프라는 신중하게!