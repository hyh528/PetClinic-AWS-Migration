# 01. Network

## AWS 콘솔 확인 방법

1. **VPC** (VPC > Your VPCs):
    - `petclinic-dev-vpc`
2. **Subnets** (VPC > Subnets):
    - `petclinic-dev-public-1`
    - `petclinic-dev-public-2`
    - `petclinic-dev-private-app-1`
    - `petclinic-dev-private-app-2`
    - `petclinic-dev-private-db-1`
    - `petclinic-dev-private-db-2`
3. **Internet Gateway** (VPC > Internet Gateways):
    - `petclinic-dev-igw`
4. **NAT Gateways** (VPC > NAT Gateways):
    - `petclinic-dev-nat-public-1`
    - `petclinic-dev-nat-public-2`
5. **Route Tables** (VPC > Route Tables):
    - `petclinic-dev-public-rt`
    - `petclinic-dev-private-app-rt`
    - `petclinic-dev-private-db-rt`
6. **VPC Endpoints** (VPC > Endpoints):
    - `petclinic-dev-s3-gateway`
    - `petclinic-dev-dynamodb-gateway`
    - `petclinic-dev-ecr-api`
    - `petclinic-dev-ecr-dkr`
    - `petclinic-dev-logs`
    - `petclinic-dev-secretsmanager`
    - `petclinic-dev-ssm`

## AWS CLI로 확인 방법

```bash
# VPC 확인
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=petclinic-dev-vpc" --region ap-northeast-2 --query "Vpcs[*].[VpcId,CidrBlock,State]" --output table

# 서브넷 확인
aws ec2 describe-subnets --filters "Name=tag:Environment,Values=dev" "Name=tag:Project,Values=petclinic" --region ap-northeast-2 --query "Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,Tags[?Key=='Name'].Value|[0]]" --output table

# 인터넷 게이트웨이 확인
aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=petclinic-dev-igw" --region ap-northeast-2 --query "InternetGateways[*].[InternetGatewayId,Attachments[0].VpcId]" --output table

# NAT 게이트웨이 확인
aws ec2 describe-nat-gateways --filter "Name=tag:Environment,Values=dev" "Name=tag:Project,Values=petclinic" --region ap-northeast-2 --query "NatGateways[*].[NatGatewayId,SubnetId,State]" --output table

# 라우팅 테이블 확인
aws ec2 describe-route-tables --filters "Name=tag:Environment,Values=dev" "Name=tag:Project,Values=petclinic" --region ap-northeast-2 --query "RouteTables[*].[RouteTableId,Tags[?Key=='Name'].Value|[0]]" --output table

# VPC 엔드포인트 확인
aws ec2 describe-vpc-endpoints --filters "Name=tag:Environment,Values=dev" "Name=tag:Project,Values=petclinic" --region ap-northeast-2 --query "VpcEndpoints[*].[VpcEndpointId,ServiceName,VpcEndpointType,State]" --output table

# 상태 파일 확인
cd terraform/layers/01-network && terraform state list

data.terraform_remote_state.common
module.common
module.vpc
module.vpc_endpoints

# output 확인
cd terraform/layers/01-network && terraform output

private_app_route_table_ids = [
  "rtb-0123456789abcdef0",
  "rtb-0123456789abcdef1",
]
private_app_subnet_ids = [
  "subnet-0123456789abcdef0",
  "subnet-0123456789abcdef1",
]
private_db_route_table_ids = [
  "rtb-0123456789abcdef2",
  "rtb-0123456789abcdef3",
]
private_db_subnet_ids = [
  "subnet-0123456789abcdef2",
  "subnet-0123456789abcdef3",
]
public_route_table_id = "rtb-0123456789abcdef4"
public_subnet_ids = [
  "subnet-0123456789abcdef4",
  "subnet-0123456789abcdef5",
]
vpc_cidr = "10.0.0.0/16"
vpc_id = "vpc-0123456789abcdef0"