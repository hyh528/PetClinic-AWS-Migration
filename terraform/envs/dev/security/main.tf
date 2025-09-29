terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

module "team_iam" {
  source = "../../../modules/iam"

  project_name = var.project_name
  group_name   = var.group_name
  team_members = var.team_members
}
