# 보안 계층: IAM, 보안 그룹, VPC 엔드포인트

# 1) IAM 사용자/그룹 (프로젝트 계정)
module "iam" {
  source = "../../../modules/iam"

  project_name               = "petclinic"
  team_members               = ["yeonghyeon", "seokgyeom", "junje", "hwigwon"]
  enable_role_based_policies = false # Phase 1: AdministratorAccess
}

