# ECS + Fluent Bit + OpenSearch (POC)

- **컴퓨팅**: 앱·Fluent Bit는 **ECS Fargate**, OpenSearch는 **독립 EC2** (ECS 외부 운영).
- **OpenSearch**: 단일 EC2 인스턴스(t3.medium)에 직접 설치. 고정 ENI(`10.0.10.100`)로 Private IP 고정, EBS 30GB 데이터 영속화.

## 구성

- **VPC**: `network.tf` — terraform-aws-modules/vpc (public/private, NAT)
- **ECS**: `ecs.tf` — 클러스터 (Service Connect, ECS Exec)
- **OpenSearch EC2**: `opensearch.tf` — 독립 EC2(t3.medium), 고정 ENI(10.0.10.100), EBS 30GB, user_data로 OpenSearch OSS 2.18.0 설치
- **설치 스크립트**: `scripts/opensearch_setup.sh.tpl` — EBS 마운트, 커널 파라미터, RPM 설치, systemd 기동

### OpenSearch EC2 상세

| 항목 | 값 |
|------|-----|
| 인스턴스 타입 | t3.medium |
| AMI | Amazon Linux 2023 (최신, 동적 조회) |
| Private IP | `10.0.10.100` (고정 ENI, ap-northeast-2a) |
| 데이터 경로 | `/data/opensearch` (EBS 30GB gp3, 암호화) |
| OpenSearch 버전 | OSS 2.18.0, single-node, 보안 플러그인 비활성화 |
| REST 포트 | 9200 |
| Inbound 허용 | Private Subnet CIDR 4개 (10.0.10~13.0/24) |
| 접속 방법 | SSM Session Manager (IAM Instance Profile) |
| (추후) 외부 노출 | ALB → 80/443 → EC2 9200 (SG 주석 해제 필요) |

## Amazon ECS 의 서비스간 통신 방법
첫 번째 방법은 Amazon ECS Service Discovery를 활용하는 것 
두 번째 방법은 Amazon Elastic Load Balancer(ELB)를 사용하는 방법
세 번째 방법은 AWS App Mesh를 활용하는 방법
그러나 가장 최신 스펙은 **Amazon ECS Service Connect** 이므로 여기서는 해당 방법을 사용한다.

- **구현**: `ecs-service-connect.tf`에서 HTTP 네임스페이스 생성, `ecs.tf` 클러스터에 `service_connect_defaults` 설정, `ecs-service.tf`의 app 서비스에 `service_connect_configuration` 적용.
- 동일 네임스페이스에 등록된 다른 서비스는 **`app:80`** 같은 DNS 이름으로 app 서비스에 접근한다.
- 태스크 정의(`taskdefinitions/app.json.tpl`)의 `portMappings`에 `name: "app"`이 있어야 Service Connect와 매칭된다.
- 자세한 방법: https://aws.amazon.com/ko/blogs/tech/run-microservices-easily-with-amazon-ecs-service-connect/

## 사용

```bash
terraform init
terraform plan
terraform apply
```

## OpenSearch 접속 및 확인

### SSM Session Manager로 EC2 접속

```bash
# 인스턴스 ID 확인 (terraform output)
terraform output opensearch_instance_id

# SSM으로 접속
aws ssm start-session --target <INSTANCE_ID>

# 접속 후 OpenSearch 헬스체크
curl http://localhost:9200/_cluster/health?pretty
curl http://localhost:9200
```

### VPC 내부에서 직접 접근 (ECS 태스크 등)

```bash
# 고정 IP 사용 (ENI로 고정됨)
curl http://10.0.10.100:9200/_cluster/health?pretty

# terraform output으로 엔드포인트 확인
terraform output opensearch_endpoint
```

### OpenSearch 서비스 상태 확인 (EC2 내부)

```bash
systemctl status opensearch
journalctl -u opensearch -f
cat /var/log/opensearch_setup.log  # user_data 실행 로그
```
