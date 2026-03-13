# ECS + Fluent Bit + OpenSearch (POC)

- **컴퓨팅**: ECS 클러스터에 **Fargate + EC2** 모두 등록. 앱·Fluent Bit는 Fargate, **OpenSearch는 EC2 용량**으로 배포.
- **OpenSearch**: ECS 서비스이지만 **launch_type = EC2**, 호스트 볼륨 `/data/opensearch`(EBS)에 데이터 영속.

## 구성

- **VPC**: `network.tf` — terraform-aws-modules/vpc (public/private, NAT)
- **ECS**: `ecs.tf` — 클러스터 (Service Connect, ECS Exec)
- **ECS EC2 용량**: `ecs-ec2-capacity.tf` — ASG(t3.medium, ECS 최적화 AMI), 추가 EBS 30GB → `/data/opensearch` 마운트, capacity provider로 클러스터에 등록
- **OpenSearch OSS**: `opensearch.tf` — ECS **태스크** (EC2 launch, bridge), `taskdefinitions/opensearch.json.tpl` 사용, 호스트 볼륨으로 `/data/opensearch` → 컨테이너 데이터 경로. 데이터는 EC2 EBS에 저장.

이미지: `opensearchproject/opensearch:2.18.0`. REST 포트 9200, VPC 내부 접근만 허용.

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

## OpenSearch (ECS EC2) 확인하기

1. `terraform apply` 후 ECS 콘솔에서 **opensearch-oss** 서비스 → 실행 중인 태스크 → 해당 태스크가 올라간 **컨테이너 인스턴스(EC2)** 의 private IP 확인. `http://<그 IP>:9200`으로 접근.
2. **ECS Exec**으로 컨테이너 접속 후 `curl localhost:9200`:

```bash
aws ecs execute-command --cluster ecs-logging-fluentbit-opensearch --task <TASK_ID> --container opensearch-oss --interactive --command /bin/bash
# 접속 후
curl http://localhost:9200
```

TASK_ID는 ECS 콘솔에서 opensearch-oss 서비스의 실행 중인 태스크에서 복사.

**Fluent Bit·앱**: 동일 VPC에서 `http://<컨테이너_인스턴스_private_ip>:9200`으로 로그 전송.
