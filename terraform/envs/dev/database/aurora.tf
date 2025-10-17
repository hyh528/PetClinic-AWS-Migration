
# RDS Aurora MySQL 클러스터 리소스
resource "aws_rds_cluster" "petclinic_aurora_cluster" {
  cluster_identifier      = "petclinic-aurora-cluster-dev"
  engine                  = "aurora-mysql"
  engine_version          = "8.0.mysql_aurora.3.10.1"
  database_name           = "petclinic"
  master_username         = "admin"
  manage_master_user_password = true
  master_user_secret_kms_key_id = aws_kms_key.aurora_secrets.arn

  db_subnet_group_name   = aws_db_subnet_group.petclinic_db_subnet_group.name
  vpc_security_group_ids = [data.terraform_remote_state.security.outputs.db_security_group_id]

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
