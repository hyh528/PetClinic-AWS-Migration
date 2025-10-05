# ==========================================
# Terraform 원격 백엔드 설정 검증 스크립트 (PowerShell)
# ==========================================
# 목적: 모든 레이어의 원격 백엔드 설정이 올바른지 검증
# 작성자: 영현
# 날짜: 2025-10-05

param(
    [switch]$DryRun = $false,
    [string]$Profile = "petclinic-yeonghyeon"
)

# 색상 함수들
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# 변수 설정
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$TerraformDir = Join-Path $ProjectRoot "terraform"
$DevEnvDir = Join-Path $TerraformDir "envs\dev"

# Bootstrap 설정
$TfstateBucket = "petclinic-tfstate-team-jungsu-kopo"
$DynamoDbTable = "petclinic-tf-locks-jungsu-kopo"
$AwsRegion = "ap-northeast-2"
$AwsProfile = $Profile

# 검증 결과 저장
$ValidationResults = @()
$TotalLayers = 0
$ValidLayers = 0
$InvalidLayers = 0

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Terraform Remote Backend Configuration Validation" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Validation start time: $(Get-Date)"
Write-Host "Project root: $ProjectRoot"
Write-Host "Target environment: dev"
Write-Host "AWS profile: $AwsProfile"
if ($DryRun) {
    Write-Host "Mode: Dry run (no actual changes)" -ForegroundColor Yellow
}
Write-Host ""

# 1. Bootstrap 인프라 검증
Write-Info "1. Validating Bootstrap infrastructure..."

try {
    # S3 버킷 존재 확인
    $s3Result = aws s3 ls "s3://$TfstateBucket" --profile $AwsProfile 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "S3 버킷 '$TfstateBucket' 존재 확인"
    } else {
        Write-Error "S3 bucket '$TfstateBucket' does not exist"
        Write-Host "Error details: $s3Result" -ForegroundColor Red
        exit 1
    }

    # DynamoDB 테이블 존재 확인
    $dynamoResult = aws dynamodb describe-table --table-name $DynamoDbTable --region $AwsRegion --profile $AwsProfile 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "DynamoDB 테이블 '$DynamoDbTable' 존재 확인"
    } else {
        Write-Error "DynamoDB table '$DynamoDbTable' does not exist"
        Write-Host "Error details: $dynamoResult" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Error "Error occurred during Bootstrap infrastructure validation: $_"
    exit 1
}

Write-Host ""

# 2. 각 레이어의 backend.tf 파일 검증
Write-Info "2. Validating backend.tf files for each layer..."

# 레이어 목록 (디렉토리 기반으로 자동 탐지)
$Layers = Get-ChildItem -Path $DevEnvDir -Directory | Select-Object -ExpandProperty Name | Sort-Object

foreach ($layer in $Layers) {
    $TotalLayers++
    $layerDir = Join-Path $DevEnvDir $layer
    $backendFile = Join-Path $layerDir "backend.tf"
    
    Write-Info "Validating: $layer layer"
    
    # backend.tf 파일 존재 확인
    if (-not (Test-Path $backendFile)) {
        Write-Error "  ERROR backend.tf file does not exist: $backendFile"
        $ValidationResults += "$layer`: backend.tf file missing"
        $InvalidLayers++
        Write-Host ""
        continue
    }
    
    # backend.tf 파일 내용 읽기
    $backendContent = Get-Content $backendFile -Raw
    
    # backend.tf 파일 내용 검증
    $hasS3Backend = $backendContent -match 'backend\s+"s3"'
    $hasBucket = $backendContent -match "bucket\s*=\s*`"$TfstateBucket`""
    $hasDynamoDb = $backendContent -match "dynamodb_table\s*=\s*`"$DynamoDbTable`""
    $hasRegion = $backendContent -match "region\s*=\s*`"$AwsRegion`""
    $hasEncrypt = $backendContent -match "encrypt\s*=\s*true"
    
    if ($hasS3Backend -and $hasBucket -and $hasDynamoDb -and $hasRegion -and $hasEncrypt) {
        # key 값 추출 및 검증
        if ($backendContent -match 'key\s*=\s*"([^"]*)"') {
            $keyValue = $matches[1]
            $expectedKey = "dev/$layer/terraform.tfstate"
            
            # 특별한 케이스들 처리 (팀원별 디렉토리 구조)
            switch ($layer) {
                "network" { $expectedKey = "dev/yeonghyeon/network/terraform.tfstate" }
                "security" { $expectedKey = "dev/hwigwon/security/terraform.tfstate" }
                "database" { $expectedKey = "dev/junje/database/terraform.tfstate" }
                "application" { $expectedKey = "dev/seokgyeom/application/terraform.tfstate" }
            }
            
            if ($keyValue -eq $expectedKey) {
                Write-Success "  OK backend.tf configuration is correct (key: $keyValue)"
                $ValidationResults += "$layer`: Configuration OK"
                $ValidLayers++
            } else {
                Write-Warning "  WARNING key value differs from expected (actual: $keyValue, expected: $expectedKey)"
                $ValidationResults += "$layer`: Key mismatch"
                $ValidLayers++  # Works but with warning
            }
        } else {
            Write-Error "  ERROR key value not found"
            $ValidationResults += "$layer`: Key missing"
            $InvalidLayers++
        }
    } else {
        Write-Error "  ERROR backend.tf configuration is incorrect"
        $ValidationResults += "$layer`: Configuration error"
        $InvalidLayers++
    }
    
    Write-Host ""
}

# 3. S3 버킷 내 상태 파일 확인
Write-Info "3. Checking state files in S3 bucket..."

try {
    $stateFiles = aws s3 ls "s3://$TfstateBucket/dev/" --recursive --profile $AwsProfile 2>&1
    if ($LASTEXITCODE -eq 0 -and $stateFiles) {
        Write-Success "Found state files:"
        $stateFiles | ForEach-Object {
            if ($_ -match '\s+(\S+\.tfstate)$') {
                Write-Host "  - $($matches[1])"
            }
        }
    } else {
        Write-Warning "No state files in S3 bucket (terraform apply may not have been executed yet)"
    }
} catch {
    Write-Warning "Error checking S3 state files: $_"
}

Write-Host ""

# 4. 검증 결과 요약
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Validation Results Summary" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Total layers: $TotalLayers"
Write-Host "Valid configurations: $ValidLayers"
Write-Host "Invalid configurations: $InvalidLayers"
Write-Host ""

if ($InvalidLayers -eq 0) {
    Write-Success "SUCCESS All layer remote backend configurations are correct!"
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Run 'terraform init' in each layer to migrate to remote backend"
    Write-Host "2. Run 'terraform plan' to verify configuration"
    Write-Host "3. Run 'terraform apply' to deploy infrastructure"
} else {
    Write-Error "ERROR $InvalidLayers layers have issues."
    Write-Host ""
    Write-Host "Problematic layers:" -ForegroundColor Red
    foreach ($result in $ValidationResults) {
        if ($result -like "*missing*" -or $result -like "*error*") {
            Write-Host "  - $result"
        }
    }
}

Write-Host ""
Write-Host "Validation completion time: $(Get-Date)"
Write-Host "==========================================" -ForegroundColor Cyan

# 종료 코드 설정
if ($InvalidLayers -eq 0) {
    exit 0
} else {
    exit 1
}