# Terraform Cloud Workspace Configuration
# 이 파일은 Terraform Cloud에서 사용할 워크스페이스 설정을 정의합니다.

# PetClinic Dev Environment
workspace "petclinic-dev" {
  description = "PetClinic 애플리케이션 개발 환경"
  environment = "dev"

  working_directory = "terraform/envs/dev"

  vcs_repo {
    identifier     = "your-org/petclinic-infrastructure"  # 실제 리포지토리로 변경
    branch         = "main"
    oauth_token_id = "ot-xxxxxxxxxxxxxxxx"  # 실제 OAuth 토큰 ID로 변경
  }

  # 실행 모드: remote (Terraform Cloud에서 실행)
  execution_mode = "remote"

  # 에이전트 풀 (필요시)
  # agent_pool_id = "apool-xxxxxxxxxxxx"

  # 변수 설정
  variables = [
    {
      key         = "environment"
      value       = "dev"
      category    = "terraform"
      description = "환경 이름"
    },
    {
      key         = "region"
      value       = "ap-northeast-1"
      category    = "terraform"
      description = "AWS 리전"
    }
  ]

  # 팀 접근 권한
  team_access {
    team_id    = "team-xxxxxxxxxxxx"  # DevOps 팀 ID
    access     = "write"
  }

  team_access {
    team_id    = "team-xxxxxxxxxxxx"  # 개발팀 ID
    access     = "read"
  }
}

# PetClinic Staging Environment
workspace "petclinic-staging" {
  description = "PetClinic 애플리케이션 스테이징 환경"
  environment = "staging"

  working_directory = "terraform/envs/staging"

  vcs_repo {
    identifier     = "your-org/petclinic-infrastructure"
    branch         = "staging"
    oauth_token_id = "ot-xxxxxxxxxxxxxxxx"
  }

  execution_mode = "remote"

  variables = [
    {
      key         = "environment"
      value       = "staging"
      category    = "terraform"
      description = "환경 이름"
    },
    {
      key         = "region"
      value       = "ap-northeast-1"
      category    = "terraform"
      description = "AWS 리전"
    }
  ]

  team_access {
    team_id    = "team-xxxxxxxxxxxx"  # DevOps 팀 ID
    access     = "write"
  }

  team_access {
    team_id    = "team-xxxxxxxxxxxx"  # QA 팀 ID
    access     = "read"
  }
}

# PetClinic Production Environment
workspace "petclinic-prod" {
  description = "PetClinic 애플리케이션 프로덕션 환경"
  environment = "prod"

  working_directory = "terraform/envs/prod"

  vcs_repo {
    identifier     = "your-org/petclinic-infrastructure"
    branch         = "production"
    oauth_token_id = "ot-xxxxxxxxxxxxxxxx"
  }

  execution_mode = "remote"

  # 프로덕션에서는 승인 요구
  auto_apply = false

  variables = [
    {
      key         = "environment"
      value       = "prod"
      category    = "terraform"
      description = "환경 이름"
    },
    {
      key         = "region"
      value       = "ap-northeast-1"
      category    = "terraform"
      description = "AWS 리전"
    }
  ]

  team_access {
    team_id    = "team-xxxxxxxxxxxx"  # DevOps 팀 ID
    access     = "write"
  }

  team_access {
    team_id    = "team-xxxxxxxxxxxx"  # 운영팀 ID
    access     = "read"
  }

  team_access {
    team_id    = "team-xxxxxxxxxxxx"  # 보안팀 ID
    access     = "read"
  }
}

# 글로벌 설정
terraform {
  version = "~> 1.5.0"
}

providers {
  aws = "~> 5.0"
}