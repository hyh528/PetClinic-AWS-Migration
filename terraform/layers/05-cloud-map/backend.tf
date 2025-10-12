terraform {
  backend "s3" {
    bucket         = "petclinic-yeonghyeon-test"
    region         = "ap-northeast-1"
    key            = "dev/05-cloud-map/terraform.tfstate"
    encrypt        = true
    dynamodb_table = "petclinic-yeonghyeon-test-locks"
  }
}