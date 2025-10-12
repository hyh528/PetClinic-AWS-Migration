# PowerShell 버전의 AWS ECR에 마이크로서비스 이미지 푸시 스크립트
# ==========================================
# 실제 Spring Boot 애플리케이션 빌드 및 ECR 푸시
# Maven 빌드 + Docker 이미지 빌드 + ECR 푸시

param(
    [string]$AwsRegion = "ap-northeast-1",
    [string]$Version = "latest",
    [string]$AwsProfile = "petclinic-dev"
)

# 환경 변수 설정
$env:AWS_REGION = $AwsRegion
$env:AWS_PROFILE = $AwsProfile
$env:JAVA_HOME = "C:\Program Files\Java\jdk-17"

# 마이크로서비스 목록 (실제 배포할 서비스들)
$services = @(
    "spring-petclinic-visits-service",     # ECS Fargate에 배포
    "spring-petclinic-vets-service",       # ECS Fargate에 배포
    "spring-petclinic-customers-service",  # ECS Fargate에 배포
    "spring-petclinic-admin-server"        # ECS Fargate에 배포 + CloudWatch
)

Write-Host "AWS ECR에 마이크로서비스 이미지 푸시 시작"
Write-Host "리전: $AwsRegion"
Write-Host "버전: $Version"
Write-Host "서비스 개수: $($services.Count)"

# ==========================================
# 1. AWS ECR 로그인
# ==========================================
Write-Host ""
Write-Host "AWS ECR에 로그인 중..."
try {
    $accountId = aws sts get-caller-identity --query Account --output text
    aws ecr get-login-password --region $AwsRegion | docker login --username AWS --password-stdin "$accountId.dkr.ecr.$AwsRegion.amazonaws.com"
    Write-Host "✅ ECR 로그인 성공"
} catch {
    Write-Host "❌ ECR 로그인 실패!"
    exit 1
}

# ==========================================
# 2. ECR 리포지토리 URL 구성
# ==========================================
$ecrRegistry = "$accountId.dkr.ecr.$AwsRegion.amazonaws.com"

# ==========================================
# 3. 서비스별 이미지 빌드 및 푸시
# ==========================================
foreach ($service in $services) {
    Write-Host ""
    Write-Host "🔄 [$service] 이미지 빌드 중..."

    # ECR 리포지토리 이름 (환경 변수 또는 기본값 사용)
    $ecrRepoName = if ($env:ECR_REPO_PREFIX) {
        "$($env:ECR_REPO_PREFIX)-$($service -replace 'spring-petclinic-', '' -replace '-service', '')"
    } else {
        "petclinic-dev-$($service -replace 'spring-petclinic-', '' -replace '-service', '')"
    }

    $ecrRepoUrl = "$ecrRegistry/$ecrRepoName"

    # 서비스 디렉토리로 이동
    $serviceDir = $service
    if (!(Test-Path $serviceDir)) {
        Write-Host "❌ $serviceDir 디렉토리가 존재하지 않습니다. 건너뜁니다."
        continue
    }

    Push-Location $serviceDir

    # Maven 빌드 (프로덕션 JAR 생성)
    Write-Host "📦 [$service] Maven 빌드 중..."
    try {
        & "..\..\mvnw.cmd" clean package -DskipTests -am
        Write-Host "✅ [$service] Maven 빌드 성공"
    } catch {
        Write-Host "❌ [$service] Maven 빌드 실패!"
        Pop-Location
        exit 1
    }

    # Docker 이미지 빌드
    Write-Host "🐳 [$service] Docker 이미지 빌드 중..."
    try {
        docker build -t "$service" .
        Write-Host "✅ [$service] Docker 빌드 성공"
    } catch {
        Write-Host "❌ [$service] Docker 빌드 실패!"
        Pop-Location
        exit 1
    }

    # ECR에 태그하고 푸시
    Write-Host "📤 [$service] ECR 푸시 중..."
    try {
        docker tag "$service" "$ecrRepoUrl"
        docker push "$ecrRepoUrl"
        Write-Host "✅ [$service] ECR 푸시 성공: $ecrRepoUrl"
    } catch {
        Write-Host "❌ [$service] ECR 푸시 실패!"
        Pop-Location
        exit 1
    }

    Pop-Location
}

# ==========================================
# 4. 완료 요약
# ==========================================
Write-Host ""
Write-Host "📋 푸시된 이미지들:"
foreach ($service in $services) {
    $ecrRepoName = if ($env:ECR_REPO_PREFIX) {
        "$($env:ECR_REPO_PREFIX)-$($service -replace 'spring-petclinic-', '' -replace '-service', '')"
    } else {
        "petclinic-dev-$($service -replace 'spring-petclinic-', '' -replace '-service', '')"
    }
    $ecrRepoUrl = "$ecrRegistry/$ecrRepoName"
    Write-Host "  - $ecrRepoUrl"
}

Write-Host ""
Write-Host "🎉 모든 이미지 푸시 완료!"