# AWS CLI를 사용하여 수동 생성된 리소스 확인 스크립트

Write-Host "=== 수동 생성 리소스 검사 ===" -ForegroundColor Green
Write-Host ""

# 1. VPC 확인
Write-Host "1. VPC 리소스 확인" -ForegroundColor Cyan
$vpcs = aws ec2 describe-vpcs --query 'Vpcs[?Tags[?Key==`Project` && Value==`petclinic`]].[VpcId,Tags[?Key==`Name`].Value|[0],Tags[?Key==`ManagedBy`].Value|[0]]' --output table
Write-Host $vpcs

# 2. 서브넷 확인
Write-Host "`n2. 서브넷 리소스 확인" -ForegroundColor Cyan
$subnets = aws ec2 describe-subnets --query 'Subnets[?Tags[?Key==`Project` && Value==`petclinic`]].[SubnetId,Tags[?Key==`Name`].Value|[0],Tags[?Key==`ManagedBy`].Value|[0],Tags[?Key==`Tier`].Value|[0]]' --output table
Write-Host $subnets

# 3. 보안 그룹 확인
Write-Host "`n3. 보안 그룹 확인" -ForegroundColor Cyan
$sgs = aws ec2 describe-security-groups --query 'SecurityGroups[?Tags[?Key==`Project` && Value==`petclinic`]].[GroupId,GroupName,Tags[?Key==`ManagedBy`].Value|[0]]' --output table
Write-Host $sgs

# 4. ECS 클러스터 확인
Write-Host "`n4. ECS 클러스터 확인" -ForegroundColor Cyan
try {
    $clusters = aws ecs list-clusters --query 'clusterArns' --output table
    Write-Host $clusters
    
    if ($clusters -match "petclinic") {
        Write-Host "ECS 클러스터 상세 정보:" -ForegroundColor Yellow
        $clusterDetails = aws ecs describe-clusters --clusters petclinic-dev-cluster --include TAGS --query 'clusters[0].[clusterName,status,tags]' --output table
        Write-Host $clusterDetails
    }
} catch {
    Write-Host "ECS 클러스터 정보 조회 실패: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. ALB 확인
Write-Host "`n5. Application Load Balancer 확인" -ForegroundColor Cyan
try {
    $albs = aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName,`petclinic`)].[LoadBalancerName,State.Code,Type]' --output table
    Write-Host $albs
} catch {
    Write-Host "ALB 정보 조회 실패: $($_.Exception.Message)" -ForegroundColor Red
}

# 6. RDS/Aurora 확인
Write-Host "`n6. RDS/Aurora 클러스터 확인" -ForegroundColor Cyan
try {
    $rds = aws rds describe-db-clusters --query 'DBClusters[?contains(DBClusterIdentifier,`petclinic`)].[DBClusterIdentifier,Status,Engine]' --output table
    Write-Host $rds
} catch {
    Write-Host "RDS 정보 조회 실패: $($_.Exception.Message)" -ForegroundColor Red
}

# 7. Lambda 함수 확인
Write-Host "`n7. Lambda 함수 확인" -ForegroundColor Cyan
try {
    $lambdas = aws lambda list-functions --query 'Functions[?contains(FunctionName,`petclinic`)].[FunctionName,Runtime,LastModified]' --output table
    Write-Host $lambdas
} catch {
    Write-Host "Lambda 정보 조회 실패: $($_.Exception.Message)" -ForegroundColor Red
}

# 8. API Gateway 확인
Write-Host "`n8. API Gateway 확인" -ForegroundColor Cyan
try {
    $apis = aws apigateway get-rest-apis --query 'items[?contains(name,`petclinic`)].[id,name,createdDate]' --output table
    Write-Host $apis
} catch {
    Write-Host "API Gateway 정보 조회 실패: $($_.Exception.Message)" -ForegroundColor Red
}

# 9. S3 버킷 확인
Write-Host "`n9. S3 버킷 확인" -ForegroundColor Cyan
try {
    $buckets = aws s3api list-buckets --query 'Buckets[?contains(Name,`petclinic`)].[Name,CreationDate]' --output table
    Write-Host $buckets
} catch {
    Write-Host "S3 정보 조회 실패: $($_.Exception.Message)" -ForegroundColor Red
}

# 10. CloudWatch 로그 그룹 확인
Write-Host "`n10. CloudWatch 로그 그룹 확인" -ForegroundColor Cyan
try {
    $logs = aws logs describe-log-groups --query 'logGroups[?contains(logGroupName,`petclinic`)].[logGroupName,creationTime]' --output table
    Write-Host $logs
} catch {
    Write-Host "CloudWatch Logs 정보 조회 실패: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== 검사 완료 ===" -ForegroundColor Green
Write-Host "위 결과에서 'ManagedBy' 태그가 'terraform'이 아닌 리소스들이 수동 생성된 리소스입니다." -ForegroundColor Yellow