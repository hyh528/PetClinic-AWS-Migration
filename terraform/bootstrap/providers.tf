# ==========================================
# Bootstrap: AWS Provider 선언 (클린 아키텍처)
# - 변수 파일(variables.tf)로부터 region/profile 주입
# - 공통 태그는 운영 관점에서 필수 메타데이터로 유지
# ==========================================

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "petclinic" # 프로젝트 식별자
      Environment = "bootstrap" # 부트스트랩 전용 환경 라벨
      ManagedBy   = "terraform" # IaC 관리 주체
      Owner       = "team-petclinic"
      CostCenter  = "training"
    }
  }
}