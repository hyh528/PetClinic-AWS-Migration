# 07-application Layer Detailed Analysis Script
# Identify manually created resources and plan imports

param(
    [string]$Region = "us-west-2",
    [string]$Profile = "petclinic-dev"
)

Write-Host "=== 07-application Layer Detailed Analysis ===" -ForegroundColor Green
Write-Host ""

# Check Terraform state for 07-application layer
Write-Host "1. Terraform State Analysis" -ForegroundColor Magenta
Push-Location "terraform/layers/07-application"

try {
    Write-Host "  Terraform State List:" -ForegroundColor Yellow
    $terraformState = terraform state list 2>$null
    if ($terraformState) {
        $terraformState | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        Write-Host "  Total $($terraformState.Count) resources managed by Terraform" -ForegroundColor Green
    }
} catch {
    Write-Host "  Error reading Terraform state: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Pop-Location
}

Write-Host ""

# Direct AWS resource analysis
Write-Host "2. Direct AWS Resource Analysis" -ForegroundColor Magenta

# Security Group detailed analysis
Write-Host "  Security Group Rules Analysis:" -ForegroundColor Yellow

# Aurora Security Group analysis
Write-Host "    Aurora Security Group (sg-063f135e0be9152d5):" -ForegroundColor Cyan
$auroraSgRules = aws ec2 describe-security-groups --group-ids "sg-063f135e0be9152d5" --region $Region --profile $Profile --query 'SecurityGroups[0].IpPermissions' --output json 2>$null
if ($auroraSgRules) {
    $rules = $auroraSgRules | ConvertFrom-Json
    foreach ($rule in $rules) {
        Write-Host "      - Port $($rule.FromPort)-$($rule.ToPort) ($($rule.IpProtocol))" -ForegroundColor Gray
        if ($rule.UserIdGroupPairs) {
            foreach ($group in $rule.UserIdGroupPairs) {
                Write-Host "        From SG: $($group.GroupId)" -ForegroundColor Gray
            }
        }
        if ($rule.IpRanges) {
            foreach ($ip in $rule.IpRanges) {
                Write-Host "        From IP: $($ip.CidrIp)" -ForegroundColor Gray
            }
        }
    }
}

# ECS Security Group analysis
Write-Host "    ECS Security Group (sg-02ead082980491162):" -ForegroundColor Cyan
$ecsSgRules = aws ec2 describe-security-groups --group-ids "sg-02ead082980491162" --region $Region --profile $Profile --query 'SecurityGroups[0].IpPermissions' --output json 2>$null
if ($ecsSgRules) {
    $rules = $ecsSgRules | ConvertFrom-Json
    foreach ($rule in $rules) {
        Write-Host "      - Port $($rule.FromPort)-$($rule.ToPort) ($($rule.IpProtocol))" -ForegroundColor Gray
        if ($rule.UserIdGroupPairs) {
            foreach ($group in $rule.UserIdGroupPairs) {
                Write-Host "        From SG: $($group.GroupId)" -ForegroundColor Gray
            }
        }
    }
}

# ALB Security Group analysis
Write-Host "    ALB Security Group (sg-0db313ea8f417da74):" -ForegroundColor Cyan
$albSgRules = aws ec2 describe-security-groups --group-ids "sg-0db313ea8f417da74" --region $Region --profile $Profile --query 'SecurityGroups[0].IpPermissions' --output json 2>$null
if ($albSgRules) {
    $rules = $albSgRules | ConvertFrom-Json
    foreach ($rule in $rules) {
        Write-Host "      - Port $($rule.FromPort)-$($rule.ToPort) ($($rule.IpProtocol))" -ForegroundColor Gray
        if ($rule.UserIdGroupPairs) {
            foreach ($group in $rule.UserIdGroupPairs) {
                Write-Host "        From SG: $($group.GroupId)" -ForegroundColor Gray
            }
        }
        if ($rule.IpRanges) {
            foreach ($ip in $rule.IpRanges) {
                Write-Host "        From IP: $($ip.CidrIp)" -ForegroundColor Gray
            }
        }
    }
}

Write-Host ""

# IAM Role analysis
Write-Host "  IAM Role Analysis:" -ForegroundColor Yellow

# Check ECS task execution roles
$ecsRoles = @(
    "ecsTaskExecutionRole",
    "petclinic-ecs-task-execution-role", 
    "petclinic-ecs-task-execution-role-v2"
)

foreach ($roleName in $ecsRoles) {
    Write-Host "    Role: $roleName" -ForegroundColor Cyan
    
    # Check role policies
    $attachedPolicies = aws iam list-attached-role-policies --role-name $roleName --region $Region --profile $Profile --query 'AttachedPolicies[].PolicyArn' --output json 2>$null
    if ($attachedPolicies) {
        $policies = $attachedPolicies | ConvertFrom-Json
        foreach ($policy in $policies) {
            Write-Host "      - Attached Policy: $policy" -ForegroundColor Gray
        }
    }
    
    # Check inline policies
    $inlinePolicies = aws iam list-role-policies --role-name $roleName --region $Region --profile $Profile --query 'PolicyNames' --output json 2>$null
    if ($inlinePolicies) {
        $policies = $inlinePolicies | ConvertFrom-Json
        foreach ($policy in $policies) {
            Write-Host "      - Inline Policy: $policy" -ForegroundColor Gray
        }
    }
}

Write-Host ""

# ECS Service detailed analysis
Write-Host "  ECS Service Analysis:" -ForegroundColor Yellow
$ecsServices = @(
    "petclinic-dev-customers",
    "petclinic-dev-vets", 
    "petclinic-dev-visits",
    "petclinic-dev-admin"
)

foreach ($serviceName in $ecsServices) {
    Write-Host "    Service: $serviceName" -ForegroundColor Cyan
    
    # Service details
    $serviceDetails = aws ecs describe-services --cluster "petclinic-dev-cluster" --services $serviceName --region $Region --profile $Profile --query 'services[0].[serviceName,taskDefinition,desiredCount,runningCount]' --output json 2>$null
    if ($serviceDetails) {
        $details = $serviceDetails | ConvertFrom-Json
        Write-Host "      - Task Definition: $($details[1])" -ForegroundColor Gray
        Write-Host "      - Desired/Running: $($details[2])/$($details[3])" -ForegroundColor Gray
    }
}

Write-Host ""

# EC2 Instance analysis (debugging resources)
Write-Host "  EC2 Debugging Instance Analysis:" -ForegroundColor Yellow
$ec2Instances = aws ec2 describe-instances --region $Region --profile $Profile --filters "Name=tag:Name,Values=*petclinic*" "Name=instance-state-name,Values=running,stopped" --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name,InstanceType]' --output json 2>$null
if ($ec2Instances) {
    $instances = $ec2Instances | ConvertFrom-Json
    foreach ($instance in $instances) {
        Write-Host "    Instance: $($instance[0]) ($($instance[1]))" -ForegroundColor Cyan
        Write-Host "      - State: $($instance[2])" -ForegroundColor Gray
        Write-Host "      - Type: $($instance[3])" -ForegroundColor Gray
    }
} else {
    Write-Host "    No debugging EC2 instances found" -ForegroundColor Gray
}

Write-Host ""

# Import priority analysis
Write-Host "3. Import Priority Analysis" -ForegroundColor Magenta

Write-Host "  High Priority (Core Production Resources):" -ForegroundColor Red
Write-Host "    1. Aurora Security Group Rules (ECS Access)" -ForegroundColor Yellow
Write-Host "       - Port 3306 access from sg-02ead082980491162 to sg-063f135e0be9152d5" -ForegroundColor Gray
Write-Host "    2. ECS Security Group Rules (ALB Access)" -ForegroundColor Yellow  
Write-Host "       - Port 8080 access from sg-0db313ea8f417da74 to sg-02ead082980491162" -ForegroundColor Gray
Write-Host "    3. ECS Task Execution Role Policies" -ForegroundColor Yellow
Write-Host "       - Secrets Manager, Parameter Store access policies" -ForegroundColor Gray

Write-Host ""
Write-Host "  Medium Priority (Debug/Development Resources):" -ForegroundColor Yellow
Write-Host "    1. EC2 Key Pair (petclinic-debug)" -ForegroundColor Cyan
Write-Host "    2. Debug Security Group Rules" -ForegroundColor Cyan
Write-Host "    3. Debug EC2 Instances (if any)" -ForegroundColor Cyan

Write-Host ""

# Next steps recommendation
Write-Host "4. Next Steps Recommendation" -ForegroundColor Magenta
Write-Host "  1. Start importing High Priority resources" -ForegroundColor Yellow
Write-Host "  2. Verify state with terraform plan after each import" -ForegroundColor Yellow
Write-Host "  3. Review Medium Priority resources for modularization" -ForegroundColor Yellow
Write-Host "  4. Re-check drift across all layers" -ForegroundColor Yellow

Write-Host ""
Write-Host "=== Analysis Complete ===" -ForegroundColor Green