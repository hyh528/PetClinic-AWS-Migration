# Terraform Infrastructure Validation Script
param(
    [string]$Environment = "dev"
)

# Color functions
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Blue }
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

# Global variables
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$EnvDir = Join-Path $ProjectRoot "envs\$Environment"
$Errors = 0
$Warnings = 0

Write-Info "Starting Terraform infrastructure validation..."
Write-Info "Environment: $Environment"
Write-Info "Working directory: $EnvDir"

# Step 1: Prerequisites Check
Write-Info "=== Step 1: Prerequisites Check ==="

try {
    $TerraformVersion = terraform version | Select-Object -First 1
    Write-Success "Terraform found: $TerraformVersion"
} catch {
    Write-Error "Terraform is not installed."
    exit 1
}

if (-not (Test-Path $EnvDir)) {
    Write-Error "Environment directory does not exist: $EnvDir"
    exit 1
}

Write-Success "Environment directory found: $EnvDir"

# Step 2: Terraform Formatting Check
Write-Info "=== Step 2: Terraform Formatting Check ==="

Set-Location $ProjectRoot

try {
    $null = terraform fmt -check -recursive 2>&1
    Write-Success "Terraform formatting is correct"
} catch {
    Write-Warning "Terraform formatting needed - applying automatically..."
    terraform fmt -recursive
    Write-Success "Terraform formatting completed"
    $Warnings++
}

# Step 3: Layer-by-Layer Validation
Write-Info "=== Step 3: Layer-by-Layer Validation ==="

# Layer definitions
$Layers = @(
    "01-network",
    "02-security", 
    "03-database",
    "04-parameter-store",
    "05-cloud-map",
    "06-lambda-genai",
    "07-application",
    "08-api-gateway",
    "09-monitoring",
    "10-aws-native"
)

$LayerDescriptions = @{
    "01-network" = "Basic network infrastructure (VPC, subnets, gateways)"
    "02-security" = "Security settings (Security Groups, IAM, VPC Endpoints)"
    "03-database" = "Database (Aurora cluster)"
    "04-parameter-store" = "Parameter Store (replaces Spring Cloud Config)"
    "05-cloud-map" = "Cloud Map (replaces Eureka)"
    "06-lambda-genai" = "Lambda GenAI (serverless AI service)"
    "07-application" = "Application infrastructure (ECS, ALB, ECR)"
    "08-api-gateway" = "API Gateway (replaces Spring Cloud Gateway)"
    "09-monitoring" = "Monitoring (CloudWatch integration)"
    "10-aws-native" = "AWS Native Services Integration"

}

$SuccessLayers = @()
$FailedLayers = @()

foreach ($Layer in $Layers) {
    $LayerDir = Join-Path $EnvDir $Layer
    
    if (-not (Test-Path $LayerDir)) {
        Write-Warning "Layer directory not found: $Layer (skipping)"
        $Warnings++
        continue
    }
    
    Write-Info "=========================================="
    Write-Info "Validating layer: $Layer"
    Write-Info "Description: $($LayerDescriptions[$Layer])"
    Write-Info "=========================================="
    
    Set-Location $LayerDir
    
    # Check required files
    $RequiredFiles = @("main.tf", "variables.tf", "outputs.tf")
    foreach ($File in $RequiredFiles) {
        if (Test-Path $File) {
            Write-Success "  ✅ $File exists"
        } else {
            Write-Warning "  ⚠️  $File missing"
            $Warnings++
        }
    }
    
    # Terraform init
    Write-Info "  🔧 Initializing Terraform..."
    try {
        $null = terraform init -input=false -upgrade 2>&1
        Write-Success "  ✅ Initialization successful"
    } catch {
        Write-Error "  ❌ Initialization failed"
        terraform init -input=false -upgrade
        $FailedLayers += $Layer
        $Errors++
        continue
    }
    
    # Terraform validate
    Write-Info "  🔍 Validating Terraform..."
    try {
        $null = terraform validate 2>&1
        Write-Success "  ✅ Validation passed"
    } catch {
        Write-Error "  ❌ Validation failed"
        terraform validate
        $FailedLayers += $Layer
        $Errors++
        continue
    }
    
    # Terraform plan (if tfvars file exists)
    $TfvarsFile = "$Environment.tfvars"
    if (Test-Path $TfvarsFile) {
        Write-Info "  📋 Creating Terraform plan..."
        try {
            $null = terraform plan -var-file=$TfvarsFile -input=false 2>&1
            Write-Success "  ✅ Plan creation successful"
        } catch {
            Write-Error "  ❌ Plan creation failed"
            terraform plan -var-file=$TfvarsFile -input=false
            $FailedLayers += $Layer
            $Errors++
            continue
        }
    } else {
        Write-Warning "  ⚠️  tfvars file not found: $TfvarsFile"
        $Warnings++
    }
    
    $SuccessLayers += $Layer
    Write-Success "Layer validation completed: $Layer"
    Write-Host ""
}

# Results Summary
Write-Info "=== Validation Results Summary ==="

Write-Host "=========================================="
Write-Host "📊 Validation Statistics:"
Write-Host "   - Total layers: $($Layers.Count)"
Write-Host "   - Successful: $($SuccessLayers.Count)"
Write-Host "   - Failed: $($FailedLayers.Count)"
Write-Host "   - Errors: $Errors"
Write-Host "   - Warnings: $Warnings"
Write-Host "=========================================="

if ($SuccessLayers.Count -gt 0) {
    Write-Success "Successful layers:"
    foreach ($Layer in $SuccessLayers) {
        Write-Success "  ✓ $Layer - $($LayerDescriptions[$Layer])"
    }
}

if ($FailedLayers.Count -gt 0) {
    Write-Error "Failed layers:"
    foreach ($Layer in $FailedLayers) {
        Write-Error "  ✗ $Layer - $($LayerDescriptions[$Layer])"
    }
}

Write-Host ""

if ($Errors -eq 0 -and $Warnings -eq 0) {
    Write-Success "🎉 All validations passed!"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "1. .\scripts\plan-all.sh $Environment  # Check deployment plan"
    Write-Host "2. .\scripts\apply-all.sh $Environment # Execute deployment"
    
} elseif ($Errors -eq 0) {
    Write-Warning "⚠️  Warnings found but deployment is possible."
    Write-Host ""
    Write-Host "Recommendations:"
    Write-Host "1. Review and fix warnings"
    Write-Host "2. .\scripts\plan-all.sh $Environment"
    
} else {
    Write-Error "❌ Errors found. Fix required before deployment."
    Write-Host ""
    Write-Host "Solutions:"
    Write-Host "1. Check error messages above"
    Write-Host "2. Fix terraform files in failed layers"
    Write-Host "3. Run validation again"
    
    exit 1
}

Write-Success "Validation script completed!"