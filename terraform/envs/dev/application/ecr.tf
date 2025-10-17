module "ecr" {
  source = "../../../modules/ecr"

  repository_names = [
    "customers-service",
    "vets-service",    
    "visits-service",
    "admin-server",
  ]

  tags = {
    Environment = "dev"
    Project     = "PetClinic"
  }
} # ECR 모듈