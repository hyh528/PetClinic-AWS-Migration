# 이 데이터 소스는 aws_rds_cluster 리소스가 자동으로 생성한 
# 마스터 비밀번호의 최신 버전을 Secrets Manager에서 읽어옵니다.
data "aws_secretsmanager_secret_version" "master_password" {
  secret_id = aws_rds_cluster.petclinic_aurora_cluster.master_user_secret[0].secret_arn
}

locals {
  # 모든 서비스가 공통으로 사용할 DB 관련 파라미터
  db_parameters = {
    "database.url"      = "jdbc:mysql://${aws_rds_cluster.petclinic_aurora_cluster.endpoint}:3306/${var.db_name}"
    "database.username" = jsondecode(data.aws_secretsmanager_secret_version.master_password.secret_string)["username"]
  }

  # 기타 공통 파라미터
  other_common_parameters = {
    "spring.profiles.active"                 = "mysql,aws",
    "spring.datasource.initialization-mode"  = "always",
    "spring.jpa.hibernate.ddl-auto"          = "update", # 'ddl' 보다 안전한 'update' 옵션 사용
    "spring.jpa.show-sql"                    = "true",
    "eureka.client.serviceUrl.defaultZone"   = "http://discovery-server:8761/eureka/"
  }

  # 각 서비스별 포트 번호
  service_ports = {
    "admin"     = "9090",
    "customers" = "8081", # 포트 충돌 방지를 위해 변경
    "vets"      = "8082",
    "visits"    = "8083",
    "gateway"   = "8080"
  }
}

# /petclinic/common/ 경로에 모든 공통 파라미터를 생성합니다.
resource "aws_ssm_parameter" "common" {
  for_each  = merge(local.db_parameters, local.other_common_parameters)
  name      = "/petclinic/common/${each.key}"
  type      = "String"
  value     = each.value
  overwrite = true # 이미 존재하면 덮어쓰기
  tags = {
    Category = "common"
  }
}

# /petclinic/dev/{서비스명}/ 경로에 각 서비스의 포트 번호 파라미터를 생성합니다.
resource "aws_ssm_parameter" "server_port" {
  for_each  = local.service_ports
  name      = "/petclinic/${var.environment}/${each.key}/server.port"
  type      = "String"
  value     = each.value
  overwrite = true # 이미 존재하면 덮어쓰기
  tags = {
    Service = each.key
  }
}
