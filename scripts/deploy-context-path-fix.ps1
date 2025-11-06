# Context Path 수정사항 배포 스크립트
# 
# 수정 내용:
# 1. Spring Boot context-path 추가 (/api/customers, /api/vets, /api/visits)
# 2. Admin 클라이언트 URL을 베이스 URL로 변경 (context-path 자동 추가)
# 3. Terraform 헬스 체크 경로 업데이트

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Context Path 수정사항 배포" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$services = @("customers", "vets", "visits")
$region = "us-west-2"
$cluster = "petclinic-dev-cluster"
$accountId = (aws sts get-caller-identity --query Account --output text)

Write-Host "1단계: Terraform 인프라 업데이트" -ForegroundColor Yellow
Write-Host "   타겟 그룹 헬스 체크 경로 변경" -ForegroundColor Gray
Write-Host "   보안 그룹 규칙 추가" -ForegroundColor Gray
Write-Host ""
Write-Host "   cd terraform/layers/07-application" -ForegroundColor Gray
Write-Host "   terraform plan" -ForegroundColor Gray
Write-Host "   terraform apply" -ForegroundColor Gray
Write-Host ""
Read-Host "Terraform apply 완료 후 Enter를 눌러 계속..."

Write-Host ""
Write-Host "2단계: Docker 이미지 빌드 및 ECR 푸시" -ForegroundColor Yellow
Write-Host ""

foreach ($service in $services) {
    Write-Host "[$service] 빌드 중..." -ForegroundColor Cyan
    
    $servicePath = "spring-petclinic-$service-service"
    $ecrRepo = "petclinic-dev-$service"
    $ecrUri = "$accountId.dkr.ecr.$region.amazonaws.com/$ecrRepo"
    
    # ECR 로그인 (첫 번째에만)
    if ($service -eq "customers") {
        Write-Host "  ECR 로그인 중..." -ForegroundColor Gray
        aws ecr get-login-password --region $region | docker login --username AWS --password-stdin "$accountId.dkr.ecr.$region.amazonaws.com"
    }
    
    # Docker 빌드
    Write-Host "  Docker 이미지 빌드 중..." -ForegroundColor Gray
    docker build -t $ecrRepo $servicePath
    
    # 태그 추가
    Write-Host "  이미지 태깅 중..." -ForegroundColor Gray
    docker tag "${ecrRepo}:latest" "${ecrUri}:latest"
    docker tag "${ecrRepo}:latest" "${ecrUri}:context-path-fix"
    
    # ECR 푸시
    Write-Host "  ECR에 푸시 중..." -ForegroundColor Gray
    docker push "${ecrUri}:latest"
    docker push "${ecrUri}:context-path-fix"
    
    Write-Host "  ✓ $service 빌드 완료" -ForegroundColor Green
    Write-Host ""
}

Write-Host "3단계: ECS 서비스 재배포" -ForegroundColor Yellow
Write-Host ""

foreach ($service in $services) {
    Write-Host "[$service] 재배포 중..." -ForegroundColor Cyan
    
    aws ecs update-service `
        --cluster $cluster `
        --service "petclinic-dev-$service" `
        --force-new-deployment `
        --region $region `
        --no-cli-pager
    
    Write-Host "  ✓ $service 재배포 명령 완료" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "배포 완료!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "서비스가 재시작되는 동안 대기하세요 (약 2-3분 소요)" -ForegroundColor Yellow
Write-Host ""
Write-Host "배포 상태 확인:" -ForegroundColor Cyan
Write-Host "  aws ecs describe-services --cluster $cluster --services petclinic-dev-customers --region $region" -ForegroundColor Gray
Write-Host ""
Write-Host "Admin UI 확인:" -ForegroundColor Cyan
Write-Host "  http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/admin" -ForegroundColor Gray