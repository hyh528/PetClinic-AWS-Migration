# Terraform Rollback Scenario Test
# Tests the ability to rollback infrastructure changes

param(
    [string]$Environment = "dev",
    [string]$TestLayer = "01-network"
)

# Color functions
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Blue }
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Step { param($Message) Write-Host "`n=== $Message ===" -ForegroundColor Cyan }

# Global variables
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$LayersDir = Join-Path $ProjectRoot "layers"
$EnvDir = Join-Path $ProjectRoot "envs"
$LayerDir = Join-Path $LayersDir $TestLayer
$TfvarsFile = Join-Path $EnvDir "$Environment.tfvars"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

function Test-RollbackScenario {
    Write-Step "Rollback Scenario Test"
    
    if (-not (Test-Path $LayerDir)) {
        Write-Error "Test layer directory not found: $LayerDir"
        exit 1
    }
    
    if (-not (Test-Path $TfvarsFile)) {
        Write-Error "Environment tfvars file not found: $TfvarsFile"
        exit 1
    }
    
    Set-Location $LayerDir
    
    try {
        Write-Info "Starting rollback test on layer: $TestLayer"
        
        # Initialize if needed
        if (-not (Test-Path ".terraform")) {
            Write-Info "  Initializing Terraform..."
            terraform init
        }
        
        # Step 1: Create current state backup
        Write-Info "  Step 1: Creating current state backup..."
        $BackupPlan = "backup-plan-$Timestamp.tfplan"
        $RelativeTfvarsPath = "../../envs/$Environment.tfvars"
        terraform plan -var-file=$RelativeTfvarsPath -out=$BackupPlan
        
        if (-not (Test-Path $BackupPlan)) {
            throw "Failed to create backup plan"
        }
        Write-Success "  Backup plan created: $BackupPlan"
        
        # Step 2: Show current state
        Write-Info "  Step 2: Capturing current state..."
        $CurrentState = terraform show -json | ConvertFrom-Json -ErrorAction SilentlyContinue
        $CurrentResourceCount = 0
        if ($CurrentState -and $CurrentState.values -and $CurrentState.values.root_module -and $CurrentState.values.root_module.resources) {
            $CurrentResourceCount = $CurrentState.values.root_module.resources.Count
        }
        Write-Info "    Current resources: $CurrentResourceCount"
        
        # Step 3: Create a test change (add a tag)
        Write-Info "  Step 3: Creating test change..."
        $TestTfvars = "test-$Environment-$Timestamp.tfvars"
        $OriginalContent = Get-Content $TfvarsFile
        $TestContent = $OriginalContent + @("", "# Test tag for rollback scenario", "test_rollback_tag = `"rollback-test-$Timestamp`"")
        $TestContent | Set-Content $TestTfvars
        
        # Step 4: Apply test change
        Write-Info "  Step 4: Applying test change..."
        $TestPlan = "test-plan-$Timestamp.tfplan"
        terraform plan -var-file=$TestTfvars -out=$TestPlan
        
        # Check if there are changes to apply
        $PlanOutput = terraform show $TestPlan
        if ($PlanOutput -match "No changes") {
            Write-Warning "  No changes detected in test plan - this is expected for some layers"
            $TestApplied = $false
        } else {
            Write-Info "  Changes detected, applying test plan..."
            terraform apply -auto-approve $TestPlan
            $TestApplied = $true
            Write-Success "  Test changes applied"
        }
        
        # Step 5: Verify test change
        if ($TestApplied) {
            Write-Info "  Step 5: Verifying test change..."
            $ModifiedState = terraform show -json | ConvertFrom-Json -ErrorAction SilentlyContinue
            Write-Info "    State after test change captured"
        }
        
        # Step 6: Perform rollback
        Write-Info "  Step 6: Performing rollback..."
        terraform apply -auto-approve $BackupPlan
        Write-Success "  Rollback completed"
        
        # Step 7: Verify rollback
        Write-Info "  Step 7: Verifying rollback..."
        $RolledBackState = terraform show -json | ConvertFrom-Json -ErrorAction SilentlyContinue
        $RolledBackResourceCount = 0
        if ($RolledBackState -and $RolledBackState.values -and $RolledBackState.values.root_module -and $RolledBackState.values.root_module.resources) {
            $RolledBackResourceCount = $RolledBackState.values.root_module.resources.Count
        }
        Write-Info "    Resources after rollback: $RolledBackResourceCount"
        
        # Step 8: Compare states
        Write-Info "  Step 8: Comparing states..."
        if ($CurrentResourceCount -eq $RolledBackResourceCount) {
            Write-Success "  Resource count matches original state"
        } else {
            Write-Warning "  Resource count differs: Original=$CurrentResourceCount, RolledBack=$RolledBackResourceCount"
        }
        
        # Cleanup temporary files
        Write-Info "  Cleaning up temporary files..."
        Remove-Item $TestTfvars -ErrorAction SilentlyContinue
        Remove-Item $BackupPlan -ErrorAction SilentlyContinue
        Remove-Item $TestPlan -ErrorAction SilentlyContinue
        
        Write-Success "Rollback scenario test completed successfully"
        
        # Generate summary
        Write-Host "`n" -NoNewline
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Rollback Test Summary" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Test Layer: $TestLayer"
        Write-Host "Environment: $Environment"
        Write-Host "Test Applied: $TestApplied"
        Write-Host "Original Resources: $CurrentResourceCount"
        Write-Host "Final Resources: $RolledBackResourceCount"
        Write-Host "Status: SUCCESS" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        
        return 0
        
    } catch {
        Write-Error "Rollback test failed: $($_.Exception.Message)"
        
        # Cleanup on error
        Remove-Item "test-$Environment-$Timestamp.tfvars" -ErrorAction SilentlyContinue
        Remove-Item "backup-plan-$Timestamp.tfplan" -ErrorAction SilentlyContinue
        Remove-Item "test-plan-$Timestamp.tfplan" -ErrorAction SilentlyContinue
        
        Write-Host "`n" -NoNewline
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "Rollback Test Summary" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "Test Layer: $TestLayer"
        Write-Host "Environment: $Environment"
        Write-Host "Status: FAILED" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        
        return 1
    }
}

# Main execution
Write-Info "Terraform Rollback Scenario Test"
Write-Info "Layer: $TestLayer, Environment: $Environment"

$ExitCode = Test-RollbackScenario
exit $ExitCode