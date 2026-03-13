# 요구되는 테라폼 제공자 목록
# 버전 기준: 2026년 3월 12일
terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.36.0"
    }
  }
}

# AWS 제공자 설정
provider "aws" {
  # 해당 테라폼 모듈을 통해서 생성되는 모든 AWS 리소스에 아래의 태그 부여
  default_tags {
    tags = local.tags
  }
}
