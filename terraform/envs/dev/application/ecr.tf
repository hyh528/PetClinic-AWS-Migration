module "ecr" {
  source = "../../../modules/ecr"

  repository_names = [
    "customers-service",
    "vets-service",    
    "visits-service"
  ]

  tags = {
    Environment = "dev"
    Project     = "PetClinic"
  }
} # ECR 모듈