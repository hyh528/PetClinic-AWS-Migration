# Comprehensive AWS Resource State Scan Script
# Compare Terraform state with actual AWS resources across all layers

param(
    [string]$Region = "us-west-2",
    [string]$Profile = "petclinic-dev",
    [switch]$Detailed = $false
)

Write-Host "=== Starting Comprehensive AWS Resource State Scan ===" -ForegroundColor Green
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host "Profile: $Profile" -ForegroundColor Yellow
Write-Host ""

# Result storage arrays
$scanResults = @()
$layerOrder = @(
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

# Layer scanning function
function Scan-Layer {
    param(
        [string]$LayerName,
        [string]$LayerPath
    )
    
    Write-Host "--- Scanning Layer $LayerName ---" -ForegroundColor Cyan
    
    $result = @{
        Layer = $LayerName
        Status = "unknown"
        TerraformResources = @()
        DriftDetected = $false
        ManualResources = @()
        Notes = ""
    }
    
    if (-not (Test-Path $LayerPath)) {
        $result.Status = "not_found"
        $result.Notes = "Layer directory does not exist"
        return $result
    }
    
    Push-Location $LayerPath
    
    try {
        # Check Terraform initialization
        if (-not (Test-Path ".terraform")) {
            Write-Host "  Terraform initialization needed" -ForegroundColor Yellow
            terraform init -backend-config=backend.config 2>$null
        }
        
        # Get Terraform state list
        $terraformState = terraform state list 2>$null
        if ($LASTEXITCODE -eq 0 -and $terraformState) {
            $result.TerraformResources = $terraformState
            Write-Host "  Terraform managed resources: $($terraformState.Count)" -ForegroundColor Green
        } else {
            Write-Host "  No Terraform state or error" -ForegroundColor Yellow
        }
        
        # Check drift with Terraform Plan
        Write-Host "  Checking for drift..." -ForegroundColor Yellow
        $planOutput = terraform plan -detailed-exitcode -var-file=../../envs/dev.tfvars 2>&1
        
        switch ($LASTEXITCODE) {
            0 { 
                $result.Status = "clean"
                $result.DriftDetected = $false
                Write-Host "  ✅ No changes detected (state matches)" -ForegroundColor Green
            }
            1 { 
                $result.Status = "error"
                $result.Notes = "Terraform plan execution error"
                Write-Host "  ❌ Terraform plan error" -ForegroundColor Red
            }
            2 { 
                $result.Status = "drift_detected"
                $result.DriftDetected = $true
                Write-Host "  ⚠️  Drift detected (manual changes exist)" -ForegroundColor Yellow
                
                # Extract changes from plan output
                if ($Detailed) {
                    $result.Notes = $planOutput -join "`n"
                }
            }
        }
        
    } catch {
        $result.Status = "error"
        $result.Notes = "Error during scan: $($_.Exception.Message)"
        Write-Host "  ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        Pop-Location
    }
    
    return $result
}

# Direct AWS resource scanning function (focused on 07-application layer)
function Scan-AWS-Resources {
    Write-Host "--- Direct AWS Resource Scan ---" -ForegroundColor Cyan
    
    $awsResources = @{
        SecurityGroups = @()
        IAMRoles = @()
        KeyPairs = @()
        ECSServices = @()
        ALBs = @()
        Parameters = @()
    }
    
    try {
        # Security Groups scan
        Write-Host "  Scanning Security Groups..." -ForegroundColor Yellow
        $sgs = aws ec2 describe-security-groups --region $Region --profile $Profile --query 'SecurityGroups[?contains(GroupName, `petclinic`) || contains(Description, `petclinic`)].[GroupId,GroupName,Description]' --output json 2>$null
        if ($sgs) {
            $awsResources.SecurityGroups = $sgs | ConvertFrom-Json
            Write-Host "    PetClinic related Security Groups: $($awsResources.SecurityGroups.Count)" -ForegroundColor Green
        }
        
        # IAM Roles scan
        Write-Host "  Scanning IAM Roles..." -ForegroundColor Yellow
        $roles = aws iam list-roles --region $Region --profile $Profile --query 'Roles[?contains(RoleName, `petclinic`) || contains(RoleName, `ecs`)].[RoleName,Arn]' --output json 2>$null
        if ($roles) {
            $awsResources.IAMRoles = $roles | ConvertFrom-Json
            Write-Host "    PetClinic/ECS related IAM Roles: $($awsResources.IAMRoles.Count)" -ForegroundColor Green
        }
        
        # EC2 Key Pairs scan
        Write-Host "  Scanning EC2 Key Pairs..." -ForegroundColor Yellow
        $keyPairs = aws ec2 describe-key-pairs --region $Region --profile $Profile --query 'KeyPairs[?contains(KeyName, `petclinic`) || contains(KeyName, `debug`)].[KeyName,KeyPairId]' --output json 2>$null
        if ($keyPairs) {
            $awsResources.KeyPairs = $keyPairs | ConvertFrom-Json
            Write-Host "    PetClinic/Debug related Key Pairs: $($awsResources.KeyPairs.Count)" -ForegroundColor Green
        }
        
        # ECS Services scan
        Write-Host "  Scanning ECS Services..." -ForegroundColor Yellow
        $clusters = aws ecs list-clusters --region $Region --profile $Profile --query 'clusterArns[?contains(@, `petclinic`)]' --output json 2>$null
        if ($clusters) {
            $clusterArns = $clusters | ConvertFrom-Json
            foreach ($clusterArn in $clusterArns) {
                $services = aws ecs list-services --cluster $clusterArn --region $Region --profile $Profile --query 'serviceArns' --output json 2>$null
                if ($services) {
                    $serviceArns = $services | ConvertFrom-Json
                    $awsResources.ECSServices += $serviceArns
                }
            }
            Write-Host "    ECS Services: $($awsResources.ECSServices.Count)" -ForegroundColor Green
        }
        
        # Parameter Store scan
        Write-Host "  Scanning Parameter Store..." -ForegroundColor Yellow
        $parameters = aws ssm describe-parameters --region $Region --profile $Profile --query 'Parameters[?contains(Name, `petclinic`)].[Name,Type]' --output json 2>$null
        if ($parameters) {
            $awsResources.Parameters = $parameters | ConvertFrom-Json
            Write-Host "    PetClinic related Parameters: $($awsResources.Parameters.Count)" -ForegroundColor Green
        }
        
    } catch {
        Write-Host "  ❌ AWS resource scan error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return $awsResources
}

# Main scan execution
Write-Host "1. Layer-by-layer Terraform State Scan" -ForegroundColor Magenta
Write-Host ""

foreach ($layer in $layerOrder) {
    $layerPath = "terraform/layers/$layer"
    $result = Scan-Layer -LayerName $layer -LayerPath $layerPath
    $scanResults += $result
    Write-Host ""
}

Write-Host "2. Direct AWS Resource Scan" -ForegroundColor Magenta
Write-Host ""
$awsResources = Scan-AWS-Resources
Write-Host ""

# Results summary
Write-Host "=== Scan Results Summary ===" -ForegroundColor Green
Write-Host ""

Write-Host "Layer Status:" -ForegroundColor Yellow
foreach ($result in $scanResults) {
    $statusColor = switch ($result.Status) {
        "clean" { "Green" }
        "drift_detected" { "Yellow" }
        "error" { "Red" }
        default { "Gray" }
    }
    
    $driftIcon = if ($result.DriftDetected) { "⚠️ " } else { "✅ " }
    Write-Host "  $driftIcon$($result.Layer): $($result.Status)" -ForegroundColor $statusColor
    
    if ($result.TerraformResources.Count -gt 0) {
        Write-Host "    - Terraform resources: $($result.TerraformResources.Count)" -ForegroundColor Gray
    }
    
    if ($result.Notes -and -not $Detailed) {
        Write-Host "    - Notes: $($result.Notes)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Import Priority Analysis:" -ForegroundColor Yellow

# High Priority: Security/Network related
$highPriorityLayers = $scanResults | Where-Object { 
    $_.Layer -in @("01-network", "02-security", "07-application") -and $_.DriftDetected 
}

if ($highPriorityLayers.Count -gt 0) {
    Write-Host "  🔴 High Priority (Security/Network):" -ForegroundColor Red
    foreach ($layer in $highPriorityLayers) {
        Write-Host "    - $($layer.Layer): Manual changes need review" -ForegroundColor Red
    }
} else {
    Write-Host "  ✅ High Priority: No issues" -ForegroundColor Green
}

# Medium Priority: IAM, Database related
$mediumPriorityLayers = $scanResults | Where-Object { 
    $_.Layer -in @("03-database", "04-parameter-store") -and $_.DriftDetected 
}

if ($mediumPriorityLayers.Count -gt 0) {
    Write-Host "  🟡 Medium Priority (IAM/Database):" -ForegroundColor Yellow
    foreach ($layer in $mediumPriorityLayers) {
        Write-Host "    - $($layer.Layer): Review needed" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ✅ Medium Priority: No issues" -ForegroundColor Green
}

# Low Priority: Others
$lowPriorityLayers = $scanResults | Where-Object { 
    $_.Layer -notin @("01-network", "02-security", "07-application", "03-database", "04-parameter-store") -and $_.DriftDetected 
}

if ($lowPriorityLayers.Count -gt 0) {
    Write-Host "  🟢 Low Priority (Others):" -ForegroundColor Cyan
    foreach ($layer in $lowPriorityLayers) {
        Write-Host "    - $($layer.Layer): Review if needed" -ForegroundColor Cyan
    }
} else {
    Write-Host "  ✅ Low Priority: No issues" -ForegroundColor Green
}

Write-Host ""
Write-Host "AWS Resource Status:" -ForegroundColor Yellow
Write-Host "  - Security Groups: $($awsResources.SecurityGroups.Count)" -ForegroundColor Gray
Write-Host "  - IAM Roles: $($awsResources.IAMRoles.Count)" -ForegroundColor Gray
Write-Host "  - EC2 Key Pairs: $($awsResources.KeyPairs.Count)" -ForegroundColor Gray
Write-Host "  - ECS Services: $($awsResources.ECSServices.Count)" -ForegroundColor Gray
Write-Host "  - Parameter Store: $($awsResources.Parameters.Count)" -ForegroundColor Gray

# Generate JSON results file
$fullResults = @{
    ScanTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Region = $Region
    Profile = $Profile
    LayerResults = $scanResults
    AWSResources = $awsResources
    Summary = @{
        TotalLayers = $scanResults.Count
        LayersWithDrift = ($scanResults | Where-Object { $_.DriftDetected }).Count
        HighPriorityIssues = $highPriorityLayers.Count
        MediumPriorityIssues = $mediumPriorityLayers.Count
        LowPriorityIssues = $lowPriorityLayers.Count
    }
}

$resultFile = "terraform/resource-scan-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$fullResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $resultFile -Encoding UTF8

Write-Host ""
Write-Host "=== Scan Complete ===" -ForegroundColor Green
Write-Host "Detailed results saved to: $resultFile" -ForegroundColor Cyan
Write-Host ""

# Next steps guidance
if ($highPriorityLayers.Count -gt 0 -or $mediumPriorityLayers.Count -gt 0) {
    Write-Host "Next Steps:" -ForegroundColor Magenta
    Write-Host "1. Perform detailed analysis of High/Medium Priority layers" -ForegroundColor Yellow
    Write-Host "2. Identify manually created resources and plan imports" -ForegroundColor Yellow
    Write-Host "3. Execute import scripts" -ForegroundColor Yellow
} else {
    Write-Host "🎉 All layers are in good state!" -ForegroundColor Green
    Write-Host "Additional import work may not be necessary." -ForegroundColor Green
}