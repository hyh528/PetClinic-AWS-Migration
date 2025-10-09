# ==========================================
# Database 모듈: Aurora MySQL 클러스터
# ==========================================
# 재사용 가능한 Aurora Database 모듈


# ==========================================
# 2. DB 서브넷 그룹 생성
# ==========================================
resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-aurora-subnet-group"
  subnet_ids = var.private_db_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-aurora-subnet-group"
  })
}

# ==========================================
# 2. Aurora MySQL 클러스터 생성
# ==========================================
resource "aws_rds_cluster" "this" {
  cluster_identifier = "${var.name_prefix}-aurora-cluster"

  # 데이터베이스 엔진 설정
  engine         = "aurora-mysql"
  engine_version = var.engine_version

  # 데이터베이스 접속 정보
  database_name   = var.db_name
  master_username = var.db_username
  port            = var.db_port

  # RDS가 Secrets Manager에서 비밀번호 관리
  manage_master_user_password = true

  # 네트워크 설정
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.vpc_security_group_ids

  # 백업 및 유지보수 설정
  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  # 삭제 보호 설정
  skip_final_snapshot       = true
  final_snapshot_identifier = "${var.name_prefix}-aurora-cluster-final"

  # Aurora Serverless v2 설정 (비용 최적화)
  serverlessv2_scaling_configuration {
    min_capacity = 0.5 # 최소 용량: 0.5 ACU
    max_capacity = 1.0 # 최대 용량: 1.0 ACU
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-aurora-cluster"
  })
}

# ==========================================
# 3. Writer 인스턴스 생성
# ==========================================
resource "aws_rds_cluster_instance" "writer" {
  identifier           = "${var.name_prefix}-aurora-writer"
  cluster_identifier   = aws_rds_cluster.this.id
  instance_class       = var.instance_class
  engine               = aws_rds_cluster.this.engine
  engine_version       = aws_rds_cluster.this.engine_version
  db_subnet_group_name = aws_db_subnet_group.this.name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-aurora-writer"
  })
}

# ==========================================
# 4. Reader 인스턴스 생성 (읽기 확장용)
# ==========================================
resource "aws_rds_cluster_instance" "reader" {
  identifier           = "${var.name_prefix}-aurora-reader"
  cluster_identifier   = aws_rds_cluster.this.id
  instance_class       = var.instance_class
  engine               = aws_rds_cluster.this.engine
  engine_version       = aws_rds_cluster.this.engine_version
  db_subnet_group_name = aws_db_subnet_group.this.name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-aurora-reader"
  })
}