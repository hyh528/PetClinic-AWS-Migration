# ==========================================
# Terraform 백엔드 공유 설정
# ==========================================
# 모든 환경에서 공유하는 백엔드 구성
# Clean Architecture: 설정을 코드에서 분리

# S3 버킷 설정
tfstate_bucket_name = "petclinic-tfstate-team-jungsu-kopo"

# DynamoDB 테이블 설정
tf_lock_table_name = "petclinic-tf-locks-jungsu-kopo"

# 리전 설정
aws_region = "ap-northeast-2"

# 암호화 설정
encrypt_state = true