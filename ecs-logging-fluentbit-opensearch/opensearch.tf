# ============================================================
# OpenSearch OSS - Standalone EC2 (단일 노드, ECS 외부 운영)
# ============================================================
# 구성 요약:
#   - EC2 t3.medium, Amazon Linux 2023, ap-northeast-2a private subnet
#   - 고정 ENI (Private IP 10.0.10.100) → 인스턴스 교체 후에도 IP 유지
#   - EBS 30GB (gp3) → /data/opensearch 마운트, 데이터 영속화
#   - OpenSearch OSS 2.18.0, single-node, 보안 플러그인 비활성화
#   - IAM Instance Profile (SSM Session Manager, CloudWatch Logs)
#   - Security Group: 9200 inbound from Private Subnet CIDR 4개만 허용
#   - (추후) ALB 연결을 위한 80/443 inbound 확장 예정
# ============================================================

locals {
  opensearch_version   = "2.18.0"
  opensearch_port      = 9200
  opensearch_data_path = "/data/opensearch"
  opensearch_fixed_ip  = "10.0.10.100" # ap-northeast-2a private subnet 고정 IP
  opensearch_az        = "${data.aws_region.current.id}a"

  # Private Subnet CIDR 4개 (OpenSearch SG inbound 허용 대상)
  private_subnet_cidrs = [for idx, _ in data.aws_availability_zones.azs.names : cidrsubnet(local.vpc_cidr, 8, idx + 10)]
}

# ============================================================
# 1. AMI - Amazon Linux 2023 최신 버전 동적 조회
# ============================================================
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# ============================================================
# 2. Security Group - OpenSearch EC2용
# ============================================================
resource "aws_security_group" "opensearch" {
  name        = "${local.project}-opensearch"
  description = "Security group for OpenSearch standalone EC2"
  vpc_id      = module.vpc.vpc_id

  # OpenSearch REST API (9200) - Private Subnet 4개에서만 허용
  # ECS Fargate 태스크 및 동일 VPC Private Subnet 내 리소스 접근 가능
  dynamic "ingress" {
    for_each = local.private_subnet_cidrs
    content {
      description = "OpenSearch REST API from private subnet ${ingress.value}"
      from_port   = local.opensearch_port
      to_port     = local.opensearch_port
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # (추후 ALB 연결 시 아래 블록 주석 해제)
  # ingress {
  #   description     = "HTTP from ALB"
  #   from_port       = 80
  #   to_port         = 80
  #   protocol        = "tcp"
  #   security_groups = [aws_security_group.opensearch_alb.id]
  # }
  # ingress {
  #   description     = "HTTPS from ALB"
  #   from_port       = 443
  #   to_port         = 443
  #   protocol        = "tcp"
  #   security_groups = [aws_security_group.opensearch_alb.id]
  # }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.project}-opensearch"
  }
}

# ============================================================
# 3. 고정 ENI - Private IP 10.0.10.100 (ap-northeast-2a)
# ============================================================
resource "aws_network_interface" "opensearch" {
  subnet_id       = module.vpc.private_subnets[0] # ap-northeast-2a private subnet
  private_ips     = [local.opensearch_fixed_ip]
  security_groups = [aws_security_group.opensearch.id]
  description     = "Fixed ENI for OpenSearch EC2 (${local.opensearch_fixed_ip})"

  tags = {
    Name = "${local.project}-opensearch"
  }
}

# ============================================================
# 4. EBS 볼륨 - OpenSearch 데이터 영속화 (30GB gp3)
# ============================================================
resource "aws_ebs_volume" "opensearch_data" {
  availability_zone = local.opensearch_az
  size              = 30
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${local.project}-opensearch-data"
  }
}

# ============================================================
# 5. IAM - EC2 Instance Role (SSM Session Manager + CloudWatch Logs)
# ============================================================
resource "aws_iam_role" "opensearch_ec2" {
  name = "${local.project}-opensearch-ec2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# SSM Session Manager 접속 (ECS Exec 대신 EC2 직접 접속)
resource "aws_iam_role_policy_attachment" "opensearch_ec2_ssm" {
  role       = aws_iam_role.opensearch_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Logs 쓰기 (EC2 system 로그)
resource "aws_iam_role_policy_attachment" "opensearch_ec2_cw_logs" {
  role       = aws_iam_role.opensearch_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_instance_profile" "opensearch_ec2" {
  name = "${local.project}-opensearch-ec2"
  role = aws_iam_role.opensearch_ec2.name
}

# ============================================================
# 6. EC2 인스턴스 - OpenSearch 호스트
# ============================================================
resource "aws_instance" "opensearch" {
  ami               = data.aws_ami.amazon_linux_2023.id
  instance_type     = "t3.medium"
  availability_zone = local.opensearch_az

  # 기본 ENI 대신 고정 ENI를 primary로 지정 → Private IP 고정
  network_interface {
    network_interface_id = aws_network_interface.opensearch.id
    device_index         = 0
  }

  iam_instance_profile = aws_iam_instance_profile.opensearch_ec2.name

  # 루트 볼륨 (OS용, 최소 크기)
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    delete_on_termination = true
    encrypted             = true
  }

  # user_data: 부팅 시 OpenSearch OSS 2.18.0 설치 및 설정
  user_data_base64 = base64encode(templatefile("${path.module}/scripts/opensearch_setup.sh.tpl", {
    opensearch_version   = local.opensearch_version
    opensearch_data_path = local.opensearch_data_path
    opensearch_port      = local.opensearch_port
  }))

  user_data_replace_on_change = true # user_data 변경 시 인스턴스 재생성

  tags = {
    Name = "${local.project}-opensearch"
  }
}

# EBS 볼륨 → EC2 연결
resource "aws_volume_attachment" "opensearch_data" {
  device_name  = "/dev/xvdf"
  volume_id    = aws_ebs_volume.opensearch_data.id
  instance_id  = aws_instance.opensearch.id
  force_detach = false
}

# ============================================================
# 7. CloudWatch Log Group - OpenSearch EC2 시스템 로그
# ============================================================
resource "aws_cloudwatch_log_group" "opensearch" {
  name              = "/ec2/${local.project}/opensearch"
  retention_in_days = 7
}
