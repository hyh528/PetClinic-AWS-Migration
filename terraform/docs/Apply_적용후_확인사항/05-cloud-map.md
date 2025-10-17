# 05. Cloud Map

## AWS 콘솔 확인 방법

1. **Cloud Map > Namespaces**:
    - `petclinic.local`
2. **Cloud Map > Services**:
    - `customers.petclinic.local`
    - `vets.petclinic.local`
    - `visits.petclinic.local`
    - `admin.petclinic.local`

## AWS CLI로 확인 방법

```bash
# Cloud Map 네임스페이스 확인
aws servicediscovery list-namespaces --region ap-northeast-2 --query "Namespaces[?Name=='petclinic.local'].[Name,Id,Type]" --output table

# Cloud Map 서비스 확인
aws servicediscovery list-services --region ap-northeast-2 --query "Services[?Name | contains(@, 'petclinic')].[Name,Id,Description]" --output table

# 특정 서비스 세부 정보 확인 (예: customers)
aws servicediscovery get-service --id $(aws servicediscovery list-services --region ap-northeast-2 --query "Services[?Name=='customers.petclinic.local'].Id" --output text) --region ap-northeast-2

# 서비스 인스턴스 확인
aws servicediscovery list-instances --service-id $(aws servicediscovery list-services --region ap-northeast-2 --query "Services[?Name=='customers.petclinic.local'].Id" --output text) --region ap-northeast-2

# 상태 파일 확인
cd terraform/layers/05-cloud-map && terraform state list

data.terraform_remote_state.network
module.cloud_map.aws_service_discovery_private_dns_namespace.petclinic
module.cloud_map.aws_service_discovery_service.services["admin"]
module.cloud_map.aws_service_discovery_service.services["customers"]
module.cloud_map.aws_service_discovery_service.services["vets"]
module.cloud_map.aws_service_discovery_service.services["visits"]

# output 확인
cd terraform/layers/05-cloud-map && terraform output

cloud_map_namespace_arn = "arn:aws:servicediscovery:ap-northeast-2:897722691159:namespace/ns-xxxxxxxxxxxxxxxxx"
cloud_map_namespace_id = "ns-xxxxxxxxxxxxxxxxx"
cloud_map_namespace_name = "petclinic.local"
service_arns = {
  "admin" = "arn:aws:servicediscovery:ap-northeast-2:897722691159:service/srv-xxxxxxxxxxxxxxxxx"
  "customers" = "arn:aws:servicediscovery:ap-northeast-2:897722691159:service/srv-xxxxxxxxxxxxxxxxx"
  "vets" = "arn:aws:servicediscovery:ap-northeast-2:897722691159:service/srv-xxxxxxxxxxxxxxxxx"
  "visits" = "arn:aws:servicediscovery:ap-northeast-2:897722691159:service/srv-xxxxxxxxxxxxxxxxx"
}
service_ids = {
  "admin" = "srv-xxxxxxxxxxxxxxxxx"
  "customers" = "srv-xxxxxxxxxxxxxxxxx"
  "vets" = "srv-xxxxxxxxxxxxxxxxx"
  "visits" = "srv-xxxxxxxxxxxxxxxxx"
}