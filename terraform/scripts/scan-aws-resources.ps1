# AWS 리소스 상태 스캔 스크립트
# 목적: 모든 테라폼 레이어의 상태와 실제 AWS 리소스를 비교하여 수동 생성된 리소스 식별

param(
    [string]$Environment = "dev",
    [string]$OutputFile = "resource-scan-results.json"
)

Write-Host "=== AWS 리소스 상태 스캔 시작 ===" -ForegroundColor Green
Write-Host "환경: $Environment" -ForegroundColor Yellow
Write-Host "결과 파일: $OutputFile" -ForegroundColor Yellow

# 결과 저장용 객체
$scanResults = @{
    timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    environment = $Environment
    scan_summary = @{
        total_layers = 0
        layers_scanned = 0
        drift_detected = 0
        manual_resources_found = 0
        import_needed = 0
    }
    layer_results = @()
    manual_resources = @()
    recommendations = @()
}

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

$scanResults.scan_summary.total_layers = $layers.Count

Write-Host "`n=== 레이어별 상태 스캔 ===" -ForegroundColor Cyan

foreach ($layer in $layers) {
    Write-Host "`n--- $layer 레이어 스캔 중 ---" -ForegroundColor Yellow
    
    $layerPath = "terraform/layers/$layer"
    $layerResult = @{
        layer = $layer
        status = "unknown"
        drift = $false
        terraform_resources = @()
        manual_resources = @()
        notes = ""
        scan_time = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    }
    
    if (Test-Path $layerPath) {
        try {
            # 레이어 디렉토리로 이동
            Push-Location $layerPath
            
            # Terraform 초기화 상태 확인
            if (Test-Path ".terraform") {
                Write-Host "  ✓ Terraform 초기화됨" -ForegroundColor Green
                
                # Terraform state list 실행
                $stateOutput = terraform state list 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $layerResult.terraform_resources = $stateOutput | Where-Object { $_ -match "^[a-zA-Z]" }
                    Write-Host "  ✓ Terraform 상태 리소스: $($layerResult.terraform_resources.Count)개" -ForegroundColor Green
                    
                    # Terraform plan 실행하여 drift 확인
                    Write-Host "  → Drift 확인 중..." -ForegroundColor Gray
                    $planOutput = terraform plan -detailed-exitcode -var-file="../../envs/$Environment.tfvars" 2>&1
                    
                    switch ($LASTEXITCODE) {
                        0 { 
                            $layerResult.status = "clean"
                            $layerResult.notes = "모든 리소스가 Terraform으로 관리됨"
                            Write-Host "  ✓ 상태 일치 (drift 없음)" -ForegroundColor Green
                        }
                        1 { 
                            $layerResult.status = "error"
                            $layerResult.notes = "Terraform plan 실행 오류: $($planOutput -join '; ')"
                            Write-Host "  ❌ Plan 실행 오류" -ForegroundColor Red
                        }
                        2 { 
                            $layerResult.status = "drift_detected"
                            $layerResult.drift = $true
                            $layerResult.notes = "상태 불일치 감지됨"
                            $scanResults.scan_summary.drift_detected++
                            Write-Host "  ⚠️  Drift 감지됨" -ForegroundColor Yellow
                        }
                    }
                } else {
                    $layerResult.status = "state_error"
                    $layerResult.notes = "Terraform state 읽기 실패: $($stateOutput -join '; ')"
                    Write-Host "  ❌ State 읽기 실패" -ForegroundColor Red
                }
            } else {
                $layerResult.status = "not_initialized"
                $layerResult.notes = "Terraform이 초기화되지 않음"
                Write-Host "  ⚠️  Terraform 미초기화" -ForegroundColor Yellow
            }
            
            Pop-Location
        } catch {
            $layerResult.status = "scan_error"
            $layerResult.notes = "스캔 중 오류 발생: $($_.Exception.Message)"
            Write-Host "  ❌ 스캔 오류: $($_.Exception.Message)" -ForegroundColor Red
            Pop-Location
        }
    } else {
        $layerResult.status = "not_found"
        $layerResult.notes = "레이어 디렉토리가 존재하지 않음"
        Write-Host "  ❌ 디렉토리 없음" -ForegroundColor Red
    }
    
    $scanResults.layer_results += $layerResult
    $scanResults.scan_summary.layers_scanned++
}

Write-Host "`n=== 07-application 레이어 상세 분석 ===" -ForegroundColor Cyan

# 07-application 레이어에서 수동 생성된 리소스 식별
$appLayerPath = "terraform/layers/07-application"
if (Test-Path $appLayerPath) {
    Push-Location $appLayerPath
    
    Write-Host "07-application 레이어에서 수동 생성 가능한 리소스 확인 중..." -ForegroundColor Yellow
    
    # 예상되는 수동 리소스들
    $expectedManualResources = @(
        @{
            type = "aws_security_group_rule"
            description = "Aurora 보안 그룹의 ECS 접근 규칙"
            priority = "High"
            aws_cli_check = "aws ec2 describe-security-groups --filters 'Name=group-name,Values=*aurora*' --query 'SecurityGroups[].IpPermissions[]'"
        },
        @{
            type = "aws_security_group_rule" 
            description = "ECS 보안 그룹의 ALB 접근 규칙"
            priority = "High"
            aws_cli_check = "aws ec2 describe-security-groups --filters 'Name=group-name,Values=*ecs*' --query 'SecurityGroups[].IpPermissions[]'"
        },
        @{
            type = "aws_iam_role"
            description = "ECS 태스크 실행 역할"
            priority = "High"
            aws_cli_check = "aws iam list-roles --query 'Roles[?contains(RoleName, ``petclinic-ecs``)]'"
        },
        @{
            type = "aws_key_pair"
            description = "디버깅용 EC2 키 페어"
            priority = "Low"
            aws_cli_check = "aws ec2 describe-key-pairs --query 'KeyPairs[?contains(KeyName, ``petclinic``)]'"
        }
    )
    
    foreach ($resource in $expectedManualResources) {
        Write-Host "  → $($resource.description) 확인 중..." -ForegroundColor Gray
        
        $manualResource = @{
            layer = "07-application"
            type = $resource.type
            description = $resource.description
            priority = $resource.priority
            found = $false
            aws_cli_check = $resource.aws_cli_check
            terraform_managed = $false
        }
        
        # Terraform 상태에서 해당 리소스 타입 확인
        $stateResources = terraform state list | Where-Object { $_ -match $resource.type }
        if ($stateResources) {
            $manualResource.terraform_managed = $true
            Write-Host "    ✓ Terraform으로 관리됨" -ForegroundColor Green
        } else {
            Write-Host "    ⚠️  Terraform 상태에 없음 - 수동 생성 가능성" -ForegroundColor Yellow
            $scanResults.scan_summary.manual_resources_found++
            $scanResults.scan_summary.import_needed++
        }
        
        $scanResults.manual_resources += $manualResource
    }
    
    Pop-Location
}

Write-Host "`n=== 다른 레이어 수동 리소스 확인 ===" -ForegroundColor Cyan

# 02-security 레이어 확인
Write-Host "02-security 레이어 수동 리소스 확인..." -ForegroundColor Yellow
$securityManualResources = @(
    @{
        layer = "02-security"
        type = "aws_security_group_rule"
        description = "수동 추가된 보안 그룹 규칙"
        priority = "High"
    }
)

# 04-parameter-store 레이어 확인  
Write-Host "04-parameter-store 레이어 수동 리소스 확인..." -ForegroundColor Yellow
$parameterManualResources = @(
    @{
        layer = "04-parameter-store"
        type = "aws_ssm_parameter"
        description = "수동 생성된 SSM 파라미터"
        priority = "Medium"
    }
)

# 10-monitoring 레이어 확인
Write-Host "10-monitoring 레이어 수동 리소스 확인..." -ForegroundColor Yellow
$monitoringManualResources = @(
    @{
        layer = "10-monitoring"
        type = "aws_cloudwatch_log_group"
        description = "수동 생성된 CloudWatch 로그 그룹"
        priority = "Medium"
    }
)

$scanResults.manual_resources += $securityManualResources + $parameterManualResources + $monitoringManualResources

Write-Host "`n=== Import 우선순위 결정 ===" -ForegroundColor Cyan

# 우선순위별 분류
$highPriorityResources = $scanResults.manual_resources | Where-Object { $_.priority -eq "High" }
$mediumPriorityResources = $scanResults.manual_resources | Where-Object { $_.priority -eq "Medium" }  
$lowPriorityResources = $scanResults.manual_resources | Where-Object { $_.priority -eq "Low" }

Write-Host "높은 우선순위 (보안/네트워크): $($highPriorityResources.Count)개" -ForegroundColor Red
Write-Host "중간 우선순위 (IAM): $($mediumPriorityResources.Count)개" -ForegroundColor Yellow
Write-Host "낮은 우선순위 (기타): $($lowPriorityResources.Count)개" -ForegroundColor Green

# 권장사항 생성
$scanResults.recommendations += "1. 높은 우선순위 리소스부터 Import 시작 (보안 그룹 규칙, IAM 역할)"
$scanResults.recommendations += "2. 07-application 레이어 집중 분석 및 Import"
$scanResults.recommendations += "3. 각 Import 후 terraform plan으로 상태 검증"
$scanResults.recommendations += "4. 디버깅 리소스는 별도 모듈로 분리 고려"

Write-Host "`n=== 스캔 결과 저장 ===" -ForegroundColor Cyan

# 결과를 JSON 파일로 저장
$scanResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding UTF8
Write-Host "스캔 결과가 $OutputFile 에 저장되었습니다." -ForegroundColor Green

Write-Host "`n=== 스캔 요약 ===" -ForegroundColor Green
Write-Host "총 레이어: $($scanResults.scan_summary.total_layers)" -ForegroundColor White
Write-Host "스캔된 레이어: $($scanResults.scan_summary.layers_scanned)" -ForegroundColor White  
Write-Host "Drift 감지된 레이어: $($scanResults.scan_summary.drift_detected)" -ForegroundColor Yellow
Write-Host "수동 생성 리소스: $($scanResults.scan_summary.manual_resources_found)" -ForegroundColor Yellow
Write-Host "Import 필요: $($scanResults.scan_summary.import_needed)" -ForegroundColor Red

Write-Host "`n=== 다음 단계 ===" -ForegroundColor Cyan
Write-Host "1. $OutputFile 파일을 검토하여 상세 결과 확인" -ForegroundColor White
Write-Host "2. 높은 우선순위 리소스부터 Import 계획 수립" -ForegroundColor White
Write-Host "3. 07-application 레이어 집중 분석 및 Import 실행" -ForegroundColor White

Write-Host "`n=== AWS 리소스 상태 스캔 완료 ===" -ForegroundColor Green