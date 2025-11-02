# Remove unnecessary manual security group rules
# Remove ports 8081, 8082, 8083 that are not actually used

param(
    [string]$Region = "us-west-2",
    [string]$Profile = "petclinic-dev",
    [switch]$DryRun = $false
)

Write-Host "=== Removing Unnecessary Security Group Rules ===" -ForegroundColor Green
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host "Profile: $Profile" -ForegroundColor Yellow
Write-Host "Dry Run: $DryRun" -ForegroundColor Yellow
Write-Host ""

# Security group IDs from analysis
$ecsSecurityGroupId = "sg-02ead082980491162"
$albSecurityGroupId = "sg-0db313ea8f417da74"

# Rules to remove (ports that are not actually used)
$rulesToRemove = @(
    @{
        Port = 8081
        Description = "Unused port - customers service uses 8080"
    },
    @{
        Port = 8082
        Description = "Unused port - visits service uses 8080"
    },
    @{
        Port = 8083
        Description = "Unused port - vets service uses 8080"
    }
)

Write-Host "Current Security Group Rules Analysis:" -ForegroundColor Magenta
Write-Host ""

# Check current rules
Write-Host "Checking current ECS security group rules..." -ForegroundColor Yellow
$currentRules = aws ec2 describe-security-groups --group-ids $ecsSecurityGroupId --region $Region --profile $Profile --query 'SecurityGroups[0].IpPermissions' --output json 2>$null

if ($currentRules) {
    $rules = $currentRules | ConvertFrom-Json
    
    Write-Host "Current ingress rules:" -ForegroundColor Cyan
    foreach ($rule in $rules) {
        $fromPort = $rule.FromPort
        $toPort = $rule.ToPort
        $protocol = $rule.IpProtocol
        
        if ($rule.UserIdGroupPairs) {
            foreach ($group in $rule.UserIdGroupPairs) {
                $sourceGroup = $group.GroupId
                $status = if ($fromPort -in @(8081, 8082, 8083)) { "❌ REMOVE" } elseif ($fromPort -eq 8080) { "✅ KEEP" } else { "ℹ️  OTHER" }
                Write-Host "  - Port $fromPort-$toPort ($protocol) from $sourceGroup $status" -ForegroundColor Gray
            }
        }
    }
} else {
    Write-Host "❌ Failed to retrieve security group rules" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Rules to Remove:" -ForegroundColor Red

foreach ($rule in $rulesToRemove) {
    Write-Host "  ❌ Port $($rule.Port): $($rule.Description)" -ForegroundColor Red
}

Write-Host ""

if ($DryRun) {
    Write-Host "🔍 DRY RUN MODE - No actual changes will be made" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Would execute the following commands:" -ForegroundColor Yellow
    
    foreach ($rule in $rulesToRemove) {
        $port = $rule.Port
        Write-Host "aws ec2 revoke-security-group-ingress --group-id $ecsSecurityGroupId --protocol tcp --port $port --source-group $albSecurityGroupId --region $Region --profile $Profile" -ForegroundColor Gray
    }
    
} else {
    Write-Host "🚀 Executing removal commands..." -ForegroundColor Yellow
    Write-Host ""
    
    $successCount = 0
    $errorCount = 0
    
    foreach ($rule in $rulesToRemove) {
        $port = $rule.Port
        Write-Host "Removing rule for port $port..." -ForegroundColor Yellow
        
        try {
            $result = aws ec2 revoke-security-group-ingress --group-id $ecsSecurityGroupId --protocol tcp --port $port --source-group $albSecurityGroupId --region $Region --profile $Profile 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ Successfully removed port $port rule" -ForegroundColor Green
                $successCount++
            } else {
                Write-Host "  ❌ Failed to remove port $port rule: $result" -ForegroundColor Red
                $errorCount++
            }
        } catch {
            Write-Host "  ❌ Error removing port $port rule: $($_.Exception.Message)" -ForegroundColor Red
            $errorCount++
        }
    }
    
    Write-Host ""
    Write-Host "=== Removal Summary ===" -ForegroundColor Magenta
    Write-Host "✅ Successfully removed: $successCount rules" -ForegroundColor Green
    Write-Host "❌ Failed to remove: $errorCount rules" -ForegroundColor Red
    
    if ($successCount -gt 0) {
        Write-Host ""
        Write-Host "🎉 Security cleanup completed!" -ForegroundColor Green
        Write-Host "The ECS security group now only allows necessary port 8080 traffic." -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "1. Verify services are still working normally" -ForegroundColor Gray
        Write-Host "2. Run terraform plan to ensure no drift" -ForegroundColor Gray
        Write-Host "3. Document this cleanup in your infrastructure notes" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=== Cleanup Complete ===" -ForegroundColor Green