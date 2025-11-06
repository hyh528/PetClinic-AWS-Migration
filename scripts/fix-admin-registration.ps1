# Admin UI 등록 수정 스크립트
# 문제: ALB는 /api/service/* 패턴으로 라우팅하지만, 서비스는 context path 없이 실행됨

$adminUrl = "http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/admin"
$albDns = "petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Admin UI 등록 수정 중..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 기존 인스턴스 조회
Write-Host "기존 등록된 서비스 조회 중..." -ForegroundColor Yellow
$instances = Invoke-RestMethod -Uri "$adminUrl/instances" -Method Get

Write-Host "등록된 서비스 수: $($instances.Count)" -ForegroundColor Gray
Write-Host ""

# 기존 인스턴스 삭제
foreach ($instance in $instances) {
    $instanceId = $instance.id
    $serviceName = $instance.registration.name
    
    Write-Host "삭제 중: $serviceName (ID: $instanceId)" -ForegroundColor Yellow
    
    try {
        Invoke-RestMethod -Uri "$adminUrl/instances/$instanceId" -Method Delete -ErrorAction Stop
        Write-Host "  ✓ 삭제 완료" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ 삭제 실패: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "올바른 URL로 재등록 중..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 서비스 정의 (올바른 URL 사용)
# ALB Target Group의 헬스 체크는 /actuator/health를 사용하므로
# 서비스 URL도 루트 경로를 사용해야 함
$services = @(
    @{
        name = "customers-service"
        # ALB를 통하지 않고 직접 타겟 그룹의 헬스 체크 경로 사용
        # 또는 context path 없는 경로 사용
        baseUrl = "http://$albDns"
    },
    @{
        name = "vets-service"
        baseUrl = "http://$albDns"
    },
    @{
        name = "visits-service"
        baseUrl = "http://$albDns"
    }
)

$registeredCount = 0
$failedCount = 0

foreach ($service in $services) {
    Write-Host "등록 중: $($service.name)..." -ForegroundColor Yellow
    
    # 올바른 URL로 페이로드 생성
    $payload = @{
        name = $service.name
        managementUrl = "$($service.baseUrl)/actuator"
        healthUrl = "$($service.baseUrl)/actuator/health"
        serviceUrl = "$($service.baseUrl)/"
    } | ConvertTo-Json
    
    Write-Host "  Payload: $payload" -ForegroundColor Gray
    
    try {
        $response = Invoke-RestMethod -Uri "$adminUrl/instances" `
            -Method Post `
            -Body $payload `
            -ContentType "application/json" `
            -ErrorAction Stop
        
        Write-Host "  ✓ 등록 성공: $($service.name)" -ForegroundColor Green
        Write-Host "    Instance ID: $($response.id)" -ForegroundColor Gray
        $registeredCount++
    }
    catch {
        Write-Host "  ✗ 등록 실패: $($service.name)" -ForegroundColor Red
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
        $failedCount++
    }
    
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "요약:" -ForegroundColor Cyan
Write-Host "  성공: $registeredCount" -ForegroundColor $(if ($registeredCount -gt 0) { "Green" } else { "Gray" })
Write-Host "  실패: $failedCount" -ForegroundColor $(if ($failedCount -gt 0) { "Red" } else { "Gray" })
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "참고: 이 방법도 작동하지 않으면 ALB 라우팅 설정을 수정해야 합니다." -ForegroundColor Yellow
Write-Host "Admin UI: $adminUrl" -ForegroundColor Cyan