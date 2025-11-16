[
  {
    "name": "${service_name}",
    "image": "${image_uri}",
    "cpu": ${cpu},
    "memory": ${memory},
    "essential": true,
    "portMappings": [
      {
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
    },
    "command": [
      "/bin/sh",
      "-c",
      "echo '=== ECR DNS Resolution Test ===' && nslookup ${aws_region}.dkr.ecr.${aws_region}.amazonaws.com && echo '=== ECR API DNS Test ===' && nslookup api.ecr.${aws_region}.amazonaws.com && echo '=== ECR Auth Test ===' && timeout 10 aws ecr get-login-password --region ${aws_region} && echo '=== Auth Success ===' || echo '=== Auth Failed ===' && echo '=== Network Test ===' && curl -I --connect-timeout 5 https://google.com && echo '=== Tests Complete - Starting Application ===' && exec java -jar app.jar"
    ],
    "environment": ${jsonencode(environment_vars)},
    "secrets": ${jsonencode(secrets)}
  }
]