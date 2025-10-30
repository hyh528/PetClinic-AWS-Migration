# Network 레이어의 상태(tfstate)를 읽어오기 위한 데이터 소스 (ALB DNS 이름 때문에 필요)
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket         = "petclinic-tfstate-team-jungsu-kopo"
    key            = "dev/yeonghyeon/network/terraform.tfstate" # 중요: 담당자 이름(yeonghyeon)을 실제 담당자로 변경하세요.
    region         = var.aws_region
    dynamodb_table = var.tf_lock_table_name
    encrypt        = var.encrypt_state
    profile        = var.network_state_profile
  }
}

# Security 레이어의 상태(tfstate)를 읽어오기 위한 데이터 소스
data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket         = "petclinic-tfstate-team-jungsu-kopo"
    key            = "dev/hwigwon/security/terraform.tfstate" # 중요: 담당자 이름(hwigwon)을 실제 담당자로 변경하세요.
    region         = var.aws_region
    dynamodb_table = var.tf_lock_table_name
    encrypt        = var.encrypt_state
    profile        = var.security_state_profile
  }
}

data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
    bucket         = "petclinic-tfstate-team-jungsu-kopo"
    key            = "dev/junje/database/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = var.tf_lock_table_name
    encrypt        = var.encrypt_state
    profile        = var.database_state_profile
  }
}