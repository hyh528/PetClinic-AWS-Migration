# ==========================================
# Database 모듈: RDS MySQL
# ==========================================
# 재사용 가능한 Database 모듈

# RDS 서브넷 그룹 (프라이빗 DB 서브넷 사용)
resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = var.private_db_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-subnet-group"
  })
}

# RDS MySQL 인스턴스
resource "aws_db_instance" "mysql" {
  identifier = "${var.name_prefix}-mysql"

  # 엔진 설정
  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  # 저장소 설정
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"

  # 데이터베이스 설정
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = var.db_port

  # 네트워크 설정
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.vpc_security_group_ids
  publicly_accessible    = false

  # 백업 및 유지보수 설정
  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  # 모니터링 설정
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn

  # 성능 개선 설정
  performance_insights_enabled = true
  performance_insights_retention_period = 7

  # 삭제 보호 (실무에서는 true로 설정)
  deletion_protection = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-mysql"
  })
}

# RDS Enhanced Monitoring을 위한 IAM 역할
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${var.name_prefix}-rds-enhanced-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}