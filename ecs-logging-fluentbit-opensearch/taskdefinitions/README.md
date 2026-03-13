# Task definition templates

JSON templates for ECS task definitions. Rendered by Terraform `templatefile()`.

- **app.json.tpl** – App container (e.g. nginx). 사용처: `ecs-service.tf`. Vars: `image`, `container_port`, `log_group_name`, `aws_region`.
- **opensearch.json.tpl** – OpenSearch OSS single-node. 사용처: `opensearch.tf`. Vars: `image`, `container_port`, `log_group_name`, `aws_region`.

Deployments (new task definition revisions) are managed by CI/CD; Terraform only creates the initial task definition and service with `lifecycle { ignore_changes = [task_definition] }` (app 서비스 한정).
