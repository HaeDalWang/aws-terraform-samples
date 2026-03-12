# AWS Terraform Samples

AWS 아키텍처 예제를 Terraform으로 구축한 POC(Proof of Concept) 모음입니다.  
각 디렉터리는 독립 실행 가능한 샘플이며, 공통 패턴을 따라 일관된 구조를 유지합니다.

---

## 공통 패턴

### 1. VPC

- **모듈**: [terraform-aws-modules/vpc/aws](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws) (AWS 공식 계열 모듈) 적극 활용.
- 각 샘플의 `network.tf`에서 VPC 모듈을 사용하며, `local.project`, `local.vpc_cidr` 및 `data.aws_availability_zones` 기반 서브넷 구성이 공통입니다.

```hcl
# network.tf 공통 패턴 예시
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.0"

  name = local.project
  cidr = local.vpc_cidr
  azs             = data.aws_availability_zones.azs.names
  public_subnets  = [...]
  private_subnets = [...]
  intra_subnets   = [...]
  enable_nat_gateway = true
  single_nat_gateway = true
}
```

### 2. AWS 공식/커뮤니티 모듈 활용

- 가능한 한 **Terraform Registry의 공식·검증된 모듈**을 사용합니다.
- VPC, EKS, RDS 등은 `terraform-aws-modules/*` 또는 HashiCorp/AWS 공식 리소스·모듈을 우선합니다.

### 3. Provider 및 버전

- **Terraform**: `>= 1.13.0`
- **AWS Provider**: `hashicorp/aws` `~> 6.36.0` (기준: 2026년 3월)
- 모든 리소스에 **default_tags** 적용 (`local.tags` 사용).

### 4. 로컬 값 및 태그

- `local.tf`에서 공통 로컬 정의:
  - `data.aws_region`, `data.aws_availability_zones`, `data.aws_caller_identity`, `data.aws_partition`
  - `local.project` (프로젝트/VPC 이름), `local.vpc_cidr`, `local.tags` (예: `terraform`, `project`)
- 리소스에는 `owner`, `env` 등 필요한 태그를 추가할 수 있으며, 기본적으로 `local.tags`가 전역 적용됩니다.

---

## 디렉터리 구조

| 디렉터리 | 설명 |
|----------|------|
| `ecs-logging-fluentbit-opensearch/` | ECS + Fluent Bit + OpenSearch 로깅 파이프라인 POC |

샘플 추가 시 위 공통 패턴(`network.tf` VPC 모듈, `providers.tf`, `local.tf` 구조)을 따르면 됩니다.

---

## 사용 방법

1. 사용할 샘플 디렉터리로 이동: `cd <샘플명>`
2. `terraform init` → `terraform plan` → `terraform apply`
3. 각 샘플의 `README.md`에 선행 조건(AWS 자격 증명, 도메인 등)이 있으면 참고합니다.

---

## 요구 사항

- Terraform >= 1.13.0
- AWS CLI 설정 또는 환경 변수(`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` 등)로 실행 계정 설정
