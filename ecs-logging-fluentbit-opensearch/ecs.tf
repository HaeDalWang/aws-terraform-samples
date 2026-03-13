# ECS Service Connect: 서비스 간 통신용 Cloud Map HTTP 네임스페이스 및 클러스터 기본값
# 참고: https://aws.amazon.com/ko/blogs/tech/run-microservices-easily-with-amazon-ecs-service-connect/
locals {
  service_connect_namespace_name = "${local.project}-connect"
}

# Service Connect에서 사용할 AWS Cloud Map HTTP 네임스페이스
resource "aws_service_discovery_http_namespace" "service_connect" {
  name        = local.service_connect_namespace_name
  description = "ECS Service Connect namespace for ${local.project}"
}

# ECS Exec 로그 수신용 로그 그룹 (클러스터 execute_command_configuration에서 사용)
resource "aws_cloudwatch_log_group" "ecs_exec" {
  name              = "/ecs/${local.project}/exec"
  retention_in_days  = 1
}

# 1. ECS 클러스터 생성 (Service Connect + ECS Exec 설정)
resource "aws_ecs_cluster" "main" {
  name = local.project

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  # ECS Exec: 클러스터에 execute command 설정이 있어야 TargetNotConnectedException 방지
  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      log_configuration {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.ecs_exec.name
      }
    }
  }

  # Service Connect: 클러스터 기본 네임스페이스 (서비스에서 동일 네임스페이스 사용 시 통신)
  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.service_connect.arn
  }
}

# 2. 태스크 실행 역할 (Task Execution Role) - ECR 접근 및 로그 생성 권한
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}