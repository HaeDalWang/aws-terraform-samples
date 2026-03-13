[
  {
    "name": "app-container",
    "image": "${image}",
    "essential": true,
    "portMappings": [
      {
        "name": "app",
        "containerPort": ${container_port},
        "hostPort": ${container_port},
        "protocol": "tcp"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${log_group_name}",
        "awslogs-region": "${aws_region}",
        "awslogs-stream-prefix": "ecs"
      }
    }
  }
]
