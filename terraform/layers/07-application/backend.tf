terraform {
  backend "s3" {
    bucket         = ""
    key            = ""
    region         = ""
    encrypt        = true
    dynamodb_table = ""
  }
}