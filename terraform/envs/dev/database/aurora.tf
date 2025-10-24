
# RDS Aurora MySQL 클러스터 리소스
resource "aws_rds_cluster" "petclinic_aurora_cluster" {
  cluster_identifier      = "petclinic-aurora-cluster-dev"
  engine                  = "aurora-mysql"
  engine_version          = "8.0.mysql_aurora.3.10.1"
  database_name           = "petclinic"
  master_username         = "admin"
  manage_master_user_password = true
  master_user_secret_kms_key_id = aws_kms_key.aurora_secrets.arn
  

   # [추가] 생성될 Secret의 이름 접두사를 지정합니다.

  db_subnet_group_name   = aws_db_subnet_group.petclinic_db_subnet_group.name
  vpc_security_group_ids        = [data.terraform_remote_state.security.outputs.db_security_group_id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.petclinic_aurora_pg.name

  skip_final_snapshot = true

  tags = {
    Name = "petclinic-aurora-cluster-dev"
  }
}

# RDS Aurora 클러스터 인스턴스
resource "aws_rds_cluster_instance" "petclinic_aurora_instance" {
  count              = 1
  cluster_identifier = aws_rds_cluster.petclinic_aurora_cluster.id
  instance_class     = "db.t3.medium"
  engine             = aws_rds_cluster.petclinic_aurora_cluster.engine
  engine_version     = aws_rds_cluster.petclinic_aurora_cluster.engine_version
}

# DB 서브넷 그룹
resource "aws_db_subnet_group" "petclinic_db_subnet_group" {
  name       = "petclinic-db-subnet-group-dev"
  subnet_ids = values(data.terraform_remote_state.network.outputs.private_db_subnet_ids)

  tags = {
    Name = "petclinic-db-subnet-group-dev"
  }
}

# Aurora 클러스터용 파라미터 그룹 (UTF8MB4 설정)
resource "aws_rds_cluster_parameter_group" "petclinic_aurora_pg" {
  name        = "petclinic-aurora-cluster-pg-dev"
  family      = "aurora-mysql8.0"
  description = "Parameter group for petclinic aurora cluster with utf8mb4 settings"

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
    apply_method = "immediate"
  }

  parameter {
    name  = "character_set_connection"
    value = "utf8mb4"
    apply_method = "immediate"
  }

  parameter {
    name  = "character_set_results"
    value = "utf8mb4"
    apply_method = "immediate"
  }

  tags = {
    Name = "petclinic-aurora-cluster-pg-dev"
  }
}

