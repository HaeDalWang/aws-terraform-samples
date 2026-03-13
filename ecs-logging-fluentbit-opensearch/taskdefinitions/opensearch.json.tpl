[
  {
    "name": "opensearch-oss",
    "image": "${image}",
    "essential": true,
    "environment": [
      { "name": "discovery.type", "value": "single-node" },
      { "name": "DISABLE_SECURITY_PLUGIN", "value": "true" },
      { "name": "OPENSEARCH_JAVA_OPTS", "value": "-Xms1g -Xmx1g" }
    ],
    "portMappings": [
      {
        "containerPort": ${container_port},
        "hostPort": ${container_port},
        "protocol": "tcp"
      }
    ],
    "mountPoints": [
      {
        "sourceVolume": "${data_volume_name}",
        "containerPath": "/usr/share/opensearch/data",
        "readOnly": false
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${log_group_name}",
        "awslogs-region": "${aws_region}",
        "awslogs-stream-prefix": "opensearch"
      }
    },
    "healthCheck": {
      "command": ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"],
      "interval": 30,
      "timeout": 5,
      "retries": 3,
      "startPeriod": 120
    }
  }
]
