# terraform/envs/dev/database/providers.tf

provider "aws" {
  region  = "ap-northeast-2"
  profile = "petclinic-junje"
}