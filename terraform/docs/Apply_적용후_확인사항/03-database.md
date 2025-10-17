# 03. Database

## Aurora 클러스터 생성이 오래 걸리는 이유
Aurora 클러스터 생성 과정에서 다음과 같은 순서로 리소스가 생성됩니다:

- Aurora 클러스터 (aws_rds_cluster) - 먼저 클러스터가 생성
- Aurora 클러스터 인스턴스들 (aws_rds_cluster_instance) - 클러스터가 생성된 후에 인스턴스들이 생성됩니다.

이 과정이 오래 걸리는 이유는:

- 클러스터 생성: Aurora 클러스터 자체를 생성하는 데 10-15분 정도 걸림
- 인스턴스 생성: 각 인스턴스(Writer/Reader)가 생성되는 데 추가로 10-15분씩 걸림
- 총 소요시간: 클러스터 + 2개의 인스턴스 = 약 30-45분 정도 걸릴 수 있습니다.

특히 Aurora MySQL의 경우:

- 스토리지 프로비저닝
- 클러스터 초기화
- 백업 설정
- 암호화 설정 (KMS 키)
- 네트워크 설정 등
- 이 모든 과정이 완료되어야 클러스터가 "available" 상태가 됩니다.

## AWS 콘솔 확인 방법

1. **RDS Clusters** (RDS > Databases):
    - `petclinic-dev-aurora-cluster`
2. **RDS Instances** (RDS > Databases):
    - `petclinic-dev-aurora-instance-1`
3. **Parameter Groups** (RDS > Parameter Groups):
    - 기본 파라미터 그룹 사용 (`default.aurora-mysql8.0`)
4. **Subnet Groups** (RDS > Subnet Groups):
    - `petclinic-dev-aurora-subnet-group`
5. **Secrets Manager** (Secrets Manager > Secrets):
    - `petclinic-dev/aurora/master-password`

## AWS CLI로 확인 방법

```bash
# Aurora 클러스터 확인
aws rds describe-db-clusters --db-cluster-identifier petclinic-dev-aurora-cluster --region ap-northeast-2 --query "DBClusters[*].[DBClusterIdentifier,Status,Engine,EngineVersion]" --output table

# RDS 인스턴스 확인
aws rds describe-db-instances --filters "Name=db-cluster-id,Values=petclinic-dev-aurora-cluster" --region ap-northeast-2 --query "DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,DBInstanceClass,Engine]" --output table

# 파라미터 그룹 확인
aws rds describe-db-cluster-parameter-groups --db-cluster-parameter-group-name default.aurora-mysql8.0 --region ap-northeast-2 --query "DBClusterParameterGroups[*].[DBClusterParameterGroupName,Description,Family]" --output table

# 서브넷 그룹 확인
aws rds describe-db-subnet-groups --db-subnet-group-name petclinic-dev-aurora-subnet-group --region ap-northeast-2 --query "DBSubnetGroups[*].[DBSubnetGroupName,Subnets[0].SubnetIdentifier,Subnets[1].SubnetIdentifier]" --output table

# Secrets Manager 확인
aws secretsmanager list-secrets --include-planned-deletion --region ap-northeast-2 --query "SecretList[?Name | contains(@, 'petclinic-dev/aurora')].[Name,ARN,PrimaryRegion]" --output table

# 상태 파일 확인
cd terraform/layers/03-database && terraform state list

data.terraform_remote_state.network
data.terraform_remote_state.security
module.aurora_cluster.aws_db_subnet_group.aurora
module.aurora_cluster.aws_rds_cluster.aurora_cluster
module.aurora_cluster.aws_rds_cluster_instance.aurora_instances
# 파라미터 그룹은 기본값 사용 (커스텀 파라미터 그룹 없음)
module.aurora_cluster.aws_secretsmanager_secret.aurora_master_password
module.aurora_cluster.aws_secretsmanager_secret_version.aurora_master_password

# output 확인
cd terraform/layers/03-database && terraform output

aurora_cluster_endpoint = "petclinic-dev-aurora-cluster.cluster-xxxxxxxxxxxx.ap-northeast-2.rds.amazonaws.com"
aurora_cluster_identifier = "petclinic-dev-aurora-cluster"
aurora_cluster_port = 3306
aurora_cluster_reader_endpoint = "petclinic-dev-aurora-cluster.cluster-ro-xxxxxxxxxxxx.ap-northeast-2.rds.amazonaws.com"
aurora_master_password_secret_arn = "arn:aws:secretsmanager:ap-northeast-2:<ACCOUNT_ID>:secret:petclinic-dev/aurora/master-password-xxxxxx"
aurora_master_username = "admin"