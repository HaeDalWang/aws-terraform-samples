# AWS 지역 정보 불러오기
data "aws_region" "current" {}
# 현재 설정된 AWS 리전에 있는 가용영역 정보 불러오기
data "aws_availability_zones" "azs" {}
# 현재 Terraform을 실행하는 IAM 객체
data "aws_caller_identity" "current" {}
# AWS 파티션 정보 불러오기
data "aws_partition" "current" {}

# 로컬 환경변수 지정
locals {
  project        = "ecs-logging-fluentbit-opensearch" # vpc-name,
  vpc_cidr       = "10.0.0.0/16"
  project_prefix = ""
  tags = { # 모든 리소스에 적용되는 전역 태그
    "terraform" = "true"
    "project"   = local.project
  }
}


