# /terraform/envs/dev/database/main.tf

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket  = "petclinic-tfstate-team-jungsu-kopo"
    key     = "dev/yeonghyeon/network/terraform.tfstate"
    region  = "ap-northeast-2"
    profile = "petclinic-yeonghyeon"
  }
}

data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket  = "petclinic-tfstate-team-jungsu-kopo"
    key     = "dev/hwigwon/security/terraform.tfstate"
    region  = "ap-northeast-2"
    profile = "petclinic-yeonghyeon"
  }
}

# Application Configuration using SSM Parameter Store is now managed directly in parameters.tf
# The legacy "config" module has been removed to avoid conflicts and duplication.