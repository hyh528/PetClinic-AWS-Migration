# 영현님용 Admin 프로파일 설정 스크립트 (PowerShell)
# 기존 팀원별 프로파일은 그대로 두고, admin 프로파일만 추가

param(
    [string]$AdminProfile = "petclinic-dev-admin"
)

Write-Host "🔧 영현님용 Admin 프로파일 설정을 시작합니다..." -ForegroundColor Blue

# 현재 디렉토리 확인
if (-not (Test-Path "envs/dev")) {
    Write-Host "❌ terraform 디렉토리에서 실행하세요" -ForegroundColor Red
    exit 1
}

Write-Host "`n📍 현재 AWS 자격 증명 확인 중..." -ForegroundColor Yellow

# 현재 AWS 설정 확인
try {
    $currentIdentity = aws sts get-caller-identity | ConvertFrom-Json
    Write-Host "✅ 현재 AWS 계정: $($currentIdentity.Account)" -ForegroundColor Green
}
catch {
    Write-Host "❌ AWS 자격 증명이 설정되지 않았습니다" -ForegroundColor Red
    exit 1
}

# Admin 프로파일 생성
Write-Host "`n🔍 Admin 프로파일 '$AdminProfile' 생성 중..." -ForegroundColor Yellow

try {
    aws configure list --profile $AdminProfile | Out-Null
    Write-Host "✅ 프로파일 '$AdminProfile'이 이미 존재합니다" -ForegroundColor Green
}
catch {
    Write-Host "📝 Admin 프로파일 '$AdminProfile' 생성 중..." -ForegroundColor Blue
    
    # 기본 프로파일 설정 복사
    $defaultAccessKey = aws configure get aws_access_key_id
    $defaultSecretKey = aws configure get aws_secret_access_key
    $defaultRegion = aws configure get region
    
    if (-not $defaultRegion) {
        $defaultRegion = "ap-northeast-2"
    }
    
    if ($defaultAccessKey -and $defaultSecretKey) {
        aws configure set aws_access_key_id $defaultAccessKey --profile $AdminProfile
        aws configure set aws_secret_access_key $defaultSecretKey --profile $AdminProfile
        aws configure set region $defaultRegion --profile $AdminProfile
        
        Write-Host "✅ 프로파일 '$AdminProfile' 생성 완료" -ForegroundColor Green
    }
    else {
        Write-Host "❌ 기본 프로파일에서 자격 증명을 가져올 수 없습니다" -ForegroundColor Red
        exit 1
    }
}

# 프로파일 테스트
Write-Host "`n🧪 Admin 프로파일 테스트 중..." -ForegroundColor Yellow
try {
    aws sts get-caller-identity --profile $AdminProfile | Out-Null
    Write-Host "✅ 프로파일 '$AdminProfile' 정상 작동" -ForegroundColor Green
}
catch {
    Write-Host "❌ 프로파일 '$AdminProfile' 테스트 실패" -ForegroundColor Red
    exit 1
}

# 환경 변수 설정
Write-Host "`n🌍 영현님용 환경 변수 설정..." -ForegroundColor Yellow

# 현재 세션에 환경 변수 설정
$env:AWS_PROFILE = $AdminProfile
Write-Host "✅ 현재 세션에 AWS_PROFILE=$AdminProfile 설정됨" -ForegroundColor Green

# 사용자 환경 변수에 영구 설정
[Environment]::SetEnvironmentVariable("AWS_PROFILE", $AdminProfile, "User")
Write-Host "✅ 사용자 환경 변수에 AWS_PROFILE=$AdminProfile 설정됨" -ForegroundColor Green

# 사용법 안내 파일 생성
$usageContent = @"
# Admin 프로파일 사용법 (영현님용)

## 🎯 목적
영현님이 모든 레이어를 확인할 수 있도록 admin 프로파일을 생성했습니다.
팀원들의 기존 프로파일은 그대로 유지됩니다.

## 🔧 사용 방법

### 영현님 사용 시
``````powershell
# 환경 변수 설정 (자동으로 설정됨)
`$env:AWS_PROFILE = "petclinic-dev-admin"

# 모든 레이어 확인 가능
cd envs/dev/network; terraform plan
cd envs/dev/security; terraform plan
cd envs/dev/database; terraform plan
cd envs/dev/application; terraform plan
``````

### 팀원들 사용 시 (기존 방식 유지)
``````powershell
# 휘권 (보안)
`$env:AWS_PROFILE = "petclinic-hwigwon"
cd envs/dev/security; terraform plan

# 석겸 (애플리케이션)  
`$env:AWS_PROFILE = "petclinic-seokgyeom"
cd envs/dev/application; terraform plan

# 준제 (데이터베이스)
`$env:AWS_PROFILE = "petclinic-jungsu"
cd envs/dev/database; terraform plan

# 영현 (네트워크) - 기존 프로파일도 사용 가능
`$env:AWS_PROFILE = "petclinic-yeonghyeon"
cd envs/dev/network; terraform plan
``````

## 📋 프로파일 목록

| 팀원 | 역할 | 프로파일 | 접근 레이어 |
|------|------|----------|-------------|
| 영현 | 인프라 총괄 | petclinic-dev-admin | 모든 레이어 |
| 영현 | 네트워크 | petclinic-yeonghyeon | network |
| 휘권 | 보안 | petclinic-hwigwon | security |
| 석겸 | 애플리케이션 | petclinic-seokgyeom | application |
| 준제 | 데이터베이스 | petclinic-jungsu | database |

## 🔄 프로파일 전환

``````powershell
# Admin 모드 (영현님 전체 확인용)
`$env:AWS_PROFILE = "petclinic-dev-admin"

# 개별 작업 모드 (기존 방식)
`$env:AWS_PROFILE = "petclinic-yeonghyeon"

# 현재 프로파일 확인
aws sts get-caller-identity
``````

## 💡 팁

1. **전체 확인 시**: admin 프로파일 사용
2. **개별 작업 시**: 기존 개인 프로파일 사용  
3. **팀원들**: 기존 방식 그대로 사용
4. **문제 발생 시**: admin 프로파일로 디버깅

## 🚀 빠른 테스트

``````powershell
# 모든 레이어 빠른 검증
`$layers = @("network", "security", "database", "application")
foreach (`$layer in `$layers) {
    Write-Host "=== `$layer 레이어 ===" -ForegroundColor Cyan
    cd "envs/dev/`$layer"
    terraform init -backend=false
    terraform validate
    cd "../../.."
}
``````
"@

Set-Content "ADMIN_PROFILE_USAGE.md" $usageContent
Write-Host "✅ 사용법 가이드가 ADMIN_PROFILE_USAGE.md에 생성되었습니다" -ForegroundColor Green

# 결과 요약
Write-Host "`n=== 설정 완료 요약 ===" -ForegroundColor Blue
Write-Host "🔧 Admin 프로파일: $AdminProfile (영현님용)"
Write-Host "🌍 환경 변수: AWS_PROFILE=$AdminProfile"
Write-Host "📋 기존 팀원 프로파일: 그대로 유지"

# 검증
Write-Host "`n🔍 설정 검증 중..." -ForegroundColor Yellow
try {
    $finalIdentity = aws sts get-caller-identity | ConvertFrom-Json
    Write-Host "✅ AWS 연결 정상: $($finalIdentity.Account)" -ForegroundColor Green
}
catch {
    Write-Host "❌ AWS 연결 실패" -ForegroundColor Red
}

# 다음 단계 안내
Write-Host "`n=== 사용 방법 ===" -ForegroundColor Blue
Write-Host "1. 전체 확인 시 (영현님):"
Write-Host "   `$env:AWS_PROFILE = 'petclinic-dev-admin'"
Write-Host ""
Write-Host "2. 개별 작업 시:"
Write-Host "   `$env:AWS_PROFILE = 'petclinic-yeonghyeon'  # 기존 방식"
Write-Host ""
Write-Host "3. 팀원들:"
Write-Host "   기존 프로파일 그대로 사용 (변경 없음)"

Write-Host "`n🎉 Admin 프로파일 설정이 완료되었습니다!" -ForegroundColor Green
Write-Host "📖 자세한 사용법은 ADMIN_PROFILE_USAGE.md를 참고하세요" -ForegroundColor Cyan