# 배포 상태 확인 스크립트
# 신입 클라우드 엔지니어를 위한 간단한 상태 체크

param(
    [string]$Environment = "dev",
    [string]$Region = "ap-northeast-1"
)

Write-Host "🔍 PetClinic 배포 상태 확인" -ForegroundColor Cyan
Write-Host "환경: $Environment" -ForegroundColor Blue
Write-Host "리전: $Region" -ForegroundColor Blue
Write-Host "=" * 50

# 1. 기본 테스트: Terraform 상태 확인
Write-Host "`n📋 1. Terraform 기본 검증" -ForegroundColor Yellow

try {
    $TerraformVersion = terraform version | Select-Object -First 1
    Write-Host "✅ Terraform: $TerraformVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Terraform이 설치되지 않았습니다" -ForegroundColor Red
    exit 1
}

# 2. AWS 연결 테스트
Write-Host "`n🔗 2. AWS 연결 테스트" -ForegroundColor Yellow

try {
    $CallerIdentity = aws sts get-caller-identity --profile petclinic-dev 2>$null | ConvertFrom-Json
    if ($CallerIdentity) {
        Write-Host "✅ AWS 연결 성공" -ForegroundColor Green
        Write-Host "   계정: $($CallerIdentity.Account)" -ForegroundColor Gray
        Write-Host "   사용자: $($CallerIdentity.Arn)" -ForegroundColor Gray
    }
} catch {
    Write-Host "⚠️ AWS 자격 증명을 확인할 수 없습니다" -ForegroundColor Yellow
}

# 3. 인프라 상태 확인 (간단한 리소스 체크)
Write-Host "`n🏗️ 3. 인프라 상태 확인" -ForegroundColor Yellow

$InfraStatus = @{
    VPC = $false
    ECS = $false
    RDS = $false
    ALB = $false
}

try {
    # VPC 확인
    $VPCs = aws ec2 describe-vpcs --filters "Name=tag:Name,Values=petclinic-dev-vpc" --region $Region 2>$null | ConvertFrom-Json
    if ($VPCs.Vpcs.Count -gt 0) {
        $InfraStatus.VPC = $true
        Write-Host "✅ VPC: 배포됨" -ForegroundColor Green
    } else {
        Write-Host "❌ VPC: 배포되지 않음" -ForegroundColor Red
    }

    # ECS 클러스터 확인
    $ECSClusters = aws ecs describe-clusters --clusters "petclinic-cluster-$Environment" --region $Region 2>$null | ConvertFrom-Json
    if ($ECSClusters.clusters.Count -gt 0 -and $ECSClusters.clusters[0].status -eq "ACTIVE") {
        $InfraStatus.ECS = $true
        Write-Host "✅ ECS 클러스터: 활성" -ForegroundColor Green
    } else {
        Write-Host "❌ ECS 클러스터: 비활성 또는 없음" -ForegroundColor Red
    }

    # RDS 확인
    $RDSClusters = aws rds describe-db-clusters --region $Region 2>$null | ConvertFrom-Json
    $PetClinicDB = $RDSClusters.DBClusters | Where-Object { $_.DBClusterIdentifier -like "*petclinic*" }
    if ($PetClinicDB) {
        $InfraStatus.RDS = $true
        Write-Host "✅ RDS Aurora: 배포됨 ($($PetClinicDB.Status))" -ForegroundColor Green
    } else {
        Write-Host "❌ RDS Aurora: 배포되지 않음" -ForegroundColor Red
    }

    # ALB 확인
    $ALBs = aws elbv2 describe-load-balancers --region $Region 2>$null | ConvertFrom-Json
    $PetClinicALB = $ALBs.LoadBalancers | Where-Object { $_.LoadBalancerName -like "*petclinic*" }
    if ($PetClinicALB) {
        $InfraStatus.ALB = $true
        Write-Host "✅ ALB: 배포됨 ($($PetClinicALB.State.Code))" -ForegroundColor Green
    } else {
        Write-Host "❌ ALB: 배포되지 않음" -ForegroundColor Red
    }

} catch {
    Write-Host "⚠️ 인프라 상태를 확인할 수 없습니다 (권한 또는 연결 문제)" -ForegroundColor Yellow
}

# 4. 애플리케이션 상태 확인
Write-Host "`n🚀 4. 애플리케이션 상태 확인" -ForegroundColor Yellow

$Services = @("api-gateway", "customers-service", "vets-service", "visits-service", "admin-server")
$RunningServices = 0

foreach ($Service in $Services) {
    try {
        $ServiceName = "petclinic-$Service-$Environment"
        $ECSService = aws ecs describe-services --cluster "petclinic-cluster-$Environment" --services $ServiceName --region $Region 2>$null | ConvertFrom-Json
        
        if ($ECSService.services.Count -gt 0) {
            $ServiceInfo = $ECSService.services[0]
            $RunningCount = $ServiceInfo.runningCount
            $DesiredCount = $ServiceInfo.desiredCount
            
            if ($RunningCount -eq $DesiredCount -and $RunningCount -gt 0) {
                Write-Host "✅ $Service`: $RunningCount/$DesiredCount 실행 중" -ForegroundColor Green
                $RunningServices++
            } else {
                Write-Host "⚠️ $Service`: $RunningCount/$DesiredCount (불안정)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "❌ $Service`: 서비스 없음" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ $Service`: 상태 확인 실패" -ForegroundColor Red
    }
}

# 5. 전체 상태 요약
Write-Host "`n📊 5. 배포 상태 요약" -ForegroundColor Yellow
Write-Host "=" * 50

$InfraScore = ($InfraStatus.Values | Where-Object { $_ -eq $true }).Count
$AppScore = $RunningServices

Write-Host "인프라 상태: $InfraScore/4 구성 요소 배포됨" -ForegroundColor $(if($InfraScore -ge 3){"Green"}else{"Yellow"})
Write-Host "애플리케이션 상태: $AppScore/$($Services.Count) 서비스 실행 중" -ForegroundColor $(if($AppScore -ge 3){"Green"}else{"Yellow"})

if ($InfraScore -ge 3 -and $AppScore -ge 3) {
    Write-Host "`n🎉 배포 상태: 양호 (프로덕션 준비)" -ForegroundColor Green
} elseif ($InfraScore -ge 2 -or $AppScore -ge 2) {
    Write-Host "`n⚠️ 배포 상태: 부분적 (일부 구성 요소 누락)" -ForegroundColor Yellow
} else {
    Write-Host "`n❌ 배포 상태: 불량 (대부분 구성 요소 누락)" -ForegroundColor Red
}

# 6. 다음 단계 제안
Write-Host "`n💡 다음 단계 제안:" -ForegroundColor Cyan

if ($InfraScore -lt 4) {
    Write-Host "1. 인프라 배포: terraform/scripts/apply-all.ps1 실행" -ForegroundColor Blue
}

if ($AppScore -lt $Services.Count) {
    Write-Host "2. 애플리케이션 배포: GitHub Actions 워크플로우 실행" -ForegroundColor Blue
}

if ($InfraScore -ge 3 -and $AppScore -ge 3) {
    Write-Host "1. CloudWatch 대시보드에서 모니터링 확인" -ForegroundColor Blue
    Write-Host "2. ALB DNS로 애플리케이션 접속 테스트" -ForegroundColor Blue
    Write-Host "3. 로그 확인 및 성능 모니터링" -ForegroundColor Blue
}

Write-Host "`n✅ 배포 상태 확인 완료!" -ForegroundColor Green