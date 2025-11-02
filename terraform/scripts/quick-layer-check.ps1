# Quick Layer Status Check Script
param(
    [string]$Environment = "dev"
)

$layers = @(
    "07-application",
    "08-api-gateway", 
    "09-aws-native",
    "10-monitoring",
    "11-frontend"
)

Write-Host "=== Quick Layer Status Check ===" -ForegroundColor Green
Write-Host ""

foreach ($layer in $layers) {
    $layerPath = "terraform/layers/$layer"
    
    Write-Host "Checking Layer: $layer" -ForegroundColor Cyan
    
    if (-not (Test-Path $layerPath)) {
        Write-Host "  [MISSING] Directory does not exist" -ForegroundColor Red
        continue
    }
    
    Push-Location $layerPath
    
    try {
        # Quick init check
        if (-not (Test-Path ".terraform")) {
            Write-Host "  [NOT_INIT] Terraform not initialized" -ForegroundColor Yellow
            Pop-Location
            continue
        }
        
        # Quick validate check
        $validateResult = terraform validate 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [INVALID] Configuration errors found" -ForegroundColor Red
            Write-Host "    Error: $($validateResult -join ' ')" -ForegroundColor Gray
            Pop-Location
            continue
        }
        
        # Quick plan check (with timeout)
        $job = Start-Job -ScriptBlock {
            param($layerPath, $env)
            Set-Location $layerPath
            terraform plan -detailed-exitcode -var-file="../../envs/$env.tfvars" 2>&1
        } -ArgumentList $layerPath, $Environment
        
        $timeout = 30 # 30 seconds timeout
        $completed = Wait-Job $job -Timeout $timeout
        
        if ($completed) {
            $planOutput = Receive-Job $job
            $exitCode = $job.State
            
            if ($planOutput -match "No changes") {
                Write-Host "  [CLEAN] No changes detected" -ForegroundColor Green
            }
            elseif ($planOutput -match "will be created|will be updated|will be destroyed") {
                $changes = ($planOutput | Select-String "will be created|will be updated|will be destroyed").Count
                Write-Host "  [DRIFT] $changes changes detected" -ForegroundColor Yellow
            }
            elseif ($planOutput -match "Error") {
                Write-Host "  [ERROR] Terraform errors found" -ForegroundColor Red
                $errorLines = $planOutput | Select-String "Error" | Select-Object -First 2
                foreach ($error in $errorLines) {
                    Write-Host "    $error" -ForegroundColor Gray
                }
            }
            else {
                Write-Host "  [UNKNOWN] Unable to determine status" -ForegroundColor Magenta
            }
        }
        else {
            Write-Host "  [TIMEOUT] Plan execution timed out (>30s)" -ForegroundColor Red
        }
        
        Remove-Job $job -Force
        
    }
    catch {
        Write-Host "  [EXCEPTION] $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        Pop-Location
    }
    
    Write-Host ""
}

Write-Host "=== Quick Check Complete ===" -ForegroundColor Green