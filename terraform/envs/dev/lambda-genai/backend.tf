terraform {
  backend "s3" {
    bucket         = "petclinic-tfstate-team-jungsu-kopo"
    key            = "dev/lambda-genai/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "petclinic-tf-locks-jungsu-kopo"
    encrypt        = true
    profile        = "petclinic-yeonghyeon"
  }
}