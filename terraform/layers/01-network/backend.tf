terraform {
  backend "s3" {
    bucket         = "petclinic-yeonghyeon-test"
    key            = "dev/01-network/terraform.tfstate"
    region         = "ap-northeast-1"
    profile        = "petclinic-dev"
    encrypt        = true
    dynamodb_table = "petclinic-yeonghyeon-test-locks"
  }
}