# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.0"

  name = local.project
  cidr = local.vpc_cidr

  azs             = data.aws_availability_zones.azs.names
  public_subnets  = [for idx, _ in data.aws_availability_zones.azs.names : cidrsubnet(local.vpc_cidr, 8, idx)]
  private_subnets = [for idx, _ in data.aws_availability_zones.azs.names : cidrsubnet(local.vpc_cidr, 8, idx + 10)]

  default_security_group_egress = [
    {
      cidr_blocks      = "0.0.0.0/0"
      ipv6_cidr_blocks = "::/0"
    }
  ]

  enable_nat_gateway = true
  single_nat_gateway = true
}