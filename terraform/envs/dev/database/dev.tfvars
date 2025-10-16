# Database 레이어용 변수 파일
# 준제 (Database 담당)

aws_region  = "ap-northeast-2"
aws_profile = "petclinic-junje"

# Common variables
project_name = "petclinic"
environment  = "dev"

# Database specific variables
db_name              = "petclinic"
db_master_password   = "change-me!" # IMPORTANT: Change this to a secure password

network_state_profile = "petclinic-yeonghyeon"
security_state_profile = "petclinic-hwigwon"