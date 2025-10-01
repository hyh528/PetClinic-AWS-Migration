terraform {
  backend "s3" {
    bucket         = "petclinic-tfstate-team-jungsu-kopo"
    key            = "dev/junje/database/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "petclinic-tf-locks-jungsu-kopo"
    encrypt        = true
    profile        = "petclinic-junje"
  }
}