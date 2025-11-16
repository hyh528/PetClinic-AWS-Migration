#!/bin/bash
# =============================================================================
# Bastion Host User Data Script
# =============================================================================
# 목적: MySQL 클라이언트 및 디버깅 도구 설치, 데이터베이스 연결 테스트

yum update -y
amazon-linux-extras install -y epel
yum install -y mysql
yum install -y telnet
yum install -y nc
yum install -y jq
yum install -y awscli

# 데이터베이스 연결 정보 조회 및 연결 테스트
echo "=== Database Connection Test ===" > /tmp/db_test.log

# Parameter Store에서 DB 정보 조회
DB_URL=$(aws ssm get-parameter --name "/petclinic/dev/db/url" --query "Parameter.Value" --output text --region ${aws_region})
DB_USERNAME=$(aws ssm get-parameter --name "/petclinic/dev/db/username" --query "Parameter.Value" --output text --region ${aws_region})
DB_SECRET_ARN=$(aws ssm get-parameter --name "/petclinic/dev/db/secrets-manager-name" --query "Parameter.Value" --output text --region ${aws_region})

echo "DB_URL: $DB_URL" >> /tmp/db_test.log
echo "DB_USERNAME: $DB_USERNAME" >> /tmp/db_test.log
echo "DB_SECRET_ARN: $DB_SECRET_ARN" >> /tmp/db_test.log

# Secrets Manager에서 비밀번호 조회
DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_ARN" --query "SecretString" --output text --region ${aws_region} | jq -r '.password')

echo "DB_PASSWORD retrieved successfully" >> /tmp/db_test.log

# MySQL 연결 테스트
echo "=== Testing MySQL Connection ===" >> /tmp/db_test.log
mysql -h ${db_cluster_endpoint} \
      -P 3306 \
      -u "$DB_USERNAME" \
      -p"$DB_PASSWORD" \
      -e "SHOW DATABASES;" >> /tmp/db_test.log 2>&1

# petclinic 데이터베이스 확인
echo "=== Checking petclinic database ===" >> /tmp/db_test.log
mysql -h ${db_cluster_endpoint} \
      -P 3306 \
      -u "$DB_USERNAME" \
      -p"$DB_PASSWORD" \
      -e "USE petclinic; SHOW TABLES;" >> /tmp/db_test.log 2>&1

# 사용자 권한 확인
echo "=== Checking user permissions ===" >> /tmp/db_test.log
mysql -h ${db_cluster_endpoint} \
      -P 3306 \
      -u "$DB_USERNAME" \
      -p"$DB_PASSWORD" \
      -e "SELECT User, Host FROM mysql.user WHERE User = '$DB_USERNAME';" >> /tmp/db_test.log 2>&1

echo "=== Test Complete ===" >> /tmp/db_test.log