data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket  = "petclinic-tfstate-team-jungsu-kopo"
    key     = "dev/yeonghyeon/network/terraform.tfstate"
    region  = var.aws_region
    profile = var.network_state_profile
  }
} # network 레이어 결과

data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket  = "petclinic-tfstate-team-jungsu-kopo"
    key     = "dev/hwigwon/security/terraform.tfstate"
    region  = var.aws_region
    profile = var.security_state_profile
  }
} # security 레이어 결과

data "terraform_remote_state" "database" {                 
  backend = "s3"                                           
  config = {                                               
    bucket  = "petclinic-tfstate-team-jungsu-kopo"         
    key     = "dev/junje/database/terraform.tfstate"       
    region  = var.aws_region                               
    profile = var.database_state_profile                   
  }                                                        
} # database 레이어 결과                                   