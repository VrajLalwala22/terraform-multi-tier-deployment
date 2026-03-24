provider "aws" {
  region = "ap-south-1"
}

# 🔹 LOCAL LOGIC (instance size based on preference)
locals {
    
    instance_type = (
    var.preference == "performance" ? "t3.small" :
    var.preference == "cost" ? "t3.micro" :
    "t3.micro"
  )
}

module "vpc" {
  source = "./modules/vpc"  
}

# 🔹 1-TIER (EC2 only)
module "ec2" {
 source = "./modules/ec2"

  count = var.tier == "1-tier" ? 1 : 0

  instance_type = local.instance_type
  repo_url      = var.repo_url
  os            = var.os
  vpc_id        = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnets[0]
}

# 🔹 2-TIER (EC2 + RDS)
module "ec2_2tier" {
  source = "./modules/ec2"

  count = var.tier == "2-tier" ? 1 : 0

  instance_type = local.instance_type
  repo_url      = var.repo_url
  os            = var.os
  vpc_id        = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnets[0]
}

module "rds" {
  source = "./modules/rds"

  count = var.tier == "2-tier" ? 1 : 0

  vpc_id = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets
}

# 🔹 3-TIER (ALB + ASG + RDS)
module "alb" {
  source = "./modules/alb"

  count = var.tier == "3-tier" ? 1 : 0

  public_subnets = module.vpc.public_subnets
}

module "autoscaling" {
  source = "./modules/autoscaling"

  count = var.tier == "3-tier" ? 1 : 0

  public_subnets = module.vpc.public_subnets
}

module "rds_3tier" {
  source = "./modules/rds"

  count = var.tier == "3-tier" ? 1 : 0

  vpc_id = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets
}