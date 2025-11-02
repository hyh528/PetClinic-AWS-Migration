# AWS 리소스 상태 간단 스캔 스크립트
param(
    [string]$Environment = "dev"
)

Write-Host "=== AWS 리소스 상태 스캔 시작 ===" -ForegroundColor Green

# 테라폼 레이어 목록
$layers = @(
    "01-network",
    "02-security", 
    "03-database",
    "04-parameter-store",
    "05-cloud-map",
    "06-lambda-genai",
    "07-application",
    "08-api-gateway",
    "09-aws-native",
    "10-monitoring",
    "11-frontend"
)

$results = @()

foreach ($layer in $layers) {
    Write-Host "`n--- $layer 레이어 스캔 ---" -ForegroundColor Yellow
    
    $layerPath = "terraform/layers/$layer"
    
    if (Test-Path $layerPath) {
        Push-Location $layerPath
        
        try {
            if (Test-Path ".terraform") {
                Write-Host "  Terraform 초기화됨" -ForegroundColor Green
                
                # State list 실행
                $stateOutput = terraform state list 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $resourceCount = ($stateOutput | Where-Object { $_ -match "^[a-zA-Z]" }).Count
                    Write-Host "  Terraform 관리 리소스: $resourceCount 개" -ForegroundColor Green
                    
                    # Plan 실행
                    Write-Host "  Drift 확인 중..." -ForegroundColor Gray
                    $planOutput = terraform plan -detailed-exitcode -var-file="../../envs/$Environment.tfvars" 2>&1
                    
                    switch ($LASTEXITCODE) {
                        0 { 
                            Write-Host "  ✓ 상태 일치 (drift 없음)" -ForegroundColor Green
                            $status = "clean"
                        }
                        1 { 
                            Write-Host "  ❌ Plan 실행 오류" -ForegroundColor Red
                            $status = "error"
                        }
                        2 { 
                            Write-Host "  ⚠️  Drift 감지됨" -ForegroundColor Yellow
                            $status = "drift"
                        }
                    }
                } else {
                    Write-Host "  ❌ State 읽기 실패" -ForegroundColor Red
                    $status = "state_error"
                    $resourceCount = 0
                }
            } else {
                Write-Host "  ⚠️  Terraform 미초기화" -ForegroundColor Yellow
                $status = "not_initialized"
                $resourceCount = 0
            }
        } catch {
            Write-Host "  ❌ 스캔 오류: $($_.Exception.Message)" -ForegroundColor Red
            $status = "scan_error"
            $resourceCount = 0
        }
        
        Pop-Location
    } else {
        Write-Host "  ❌ 디렉토리 없음" -ForegroundColor Red
        $status = "not_found"
        $resourceCount = 0
    }
    
    $results += @{
        layer = $layer
        status = $status
        resource_count = $resourceCount
    }
}

Write-Host "`n=== 스캔 결과 요약 ===" -ForegroundColor Cyan
foreach ($result in $results) {
    $statusColor = switch ($result.status) {
        "clean" { "Green" }
        "drift" { "Yellow" }
        "error" { "Red" }
        "state_error" { "Red" }
        "not_initialized" { "Yellow" }
        "not_found" { "Red" }
        default { "Gray" }
    }
    Write-Host "$($result.layer): $($result.status) ($($result.resource_count) 리소스)" -ForegroundColor $statusColor
}

Write-Host "`n=== 07-application 레이어 상세 분석 ===" -ForegroundColor Cyan
$appLayer = $results | Where-Object { $_.layer -eq "07-application" }
if ($appLayer -and $appLayer.status -eq "drift") {
    Write-Host "07-application 레이어에서 drift가 감지되었습니다." -ForegroundColor Yellow
    Write-Host "수동 생성된 리소스가 있을 가능성이 높습니다." -ForegroundColor Yellow
    Write-Host "다음 단계: check-manual-resources.ps1 실행하여 상세 확인" -ForegroundColor Cyan
}

Write-Host "`n=== 스캔 완료 ===" -ForegroundColor Green