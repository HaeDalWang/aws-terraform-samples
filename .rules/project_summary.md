# Project Summary & Agent Rules

**AI Agents must read this document first before starting any work.**

---

## Communication

- **Responses**: All agent replies and explanations to the user must be in **Korean**.

---

## Project Summary

- **Purpose**: A collection of POCs (Proof of Concept) that implement AWS architecture examples with Terraform.
- **Structure**: Each directory under the repo root is an independently runnable sample (e.g. `ecs-logging-fluentbit-opensearch/`).

---

## Common Rules (Brief)

| Item | Rule |
|------|------|
| VPC | Use `terraform-aws-modules/vpc/aws` in `network.tf`. Base on `local.project`, `local.vpc_cidr`, and `data.aws_availability_zones`. |
| Modules | Prefer official or well-established modules from Terraform Registry (`terraform-aws-modules/*`, HashiCorp/AWS). |
| Provider | Terraform ≥1.13, AWS `hashicorp/aws` ~>6.36. Use `default_tags = local.tags`. |
| Locals / Tags | In `local.tf`: data for `aws_region`, `availability_zones`, `caller_identity`, `partition`; locals for `project`, `vpc_cidr`, `tags`. Add `owner`, `env`, etc. to resources when needed. |

---

## Git (Required)

- **Before changes**: Check existing history and intent via `git status`, `git diff`, `git log -p -- <path>` before editing.
- **When changing**: Write commit messages that clearly state **what** and **why** (e.g. `feat(ecs): add Fluent Bit sidecar task def`, `fix(vpc): correct private subnet CIDR`).
- **After changes**: Commit in logical units. Treat **git history** as the single source of truth for past changes; avoid duplicating that in docs or code.
