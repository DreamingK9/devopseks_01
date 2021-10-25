provider "aws" {
  region = var.AWS_REGION
  profile = var.profile
}

data "aws_region" "current" {
}

data "aws_availability_zones" "available" {
}

provider "http" {
}