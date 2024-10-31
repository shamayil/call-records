## Used to register a record in Route 53 ##
#data "aws_ssm_parameter" "route53_hostzone" {
#  name = "/route53/hostzone"
#}

data "aws_route53_zone" "public_hostzone" {
    name = var.hostzone
}

## load balancer name
data "aws_ssm_parameter" "alb_name" {
    name = "/alb/name"
}

data "aws_lb" "alb_name" {
    name = data.aws_ssm_parameter.alb_name.value
}

##############################################################
## Used in ECS Service - Parameter store ##
##############################################################

data "aws_ssm_parameter" "ecs_taskexecution_role" {
    name = "/ecs/taskexecutionrolearn"
}

data "aws_ssm_parameter" "ecs_cluster_arn" {
    name = "/${var.project}/${var.environment}/ecs/clusterarn"
}

data "aws_ssm_parameter" "ecs_cluster_name" {
    name = "/${var.project}/${var.environment}/ecs/clustername"
}

data "aws_ssm_parameter" "ecs_sg" {
    name = "/${var.project}/${var.environment}/ecs/securitygroupid"
}

data "aws_ssm_parameter" "sqs_queue" {
    name = "/${var.project}/${var.environment}/${var.service_name}/sqs/url"
}

data "aws_ssm_parameter" "public_subnet_ids" {
    name = "/vpc/publicsubnetids"
}

data "aws_ssm_parameter" "vpc_id" {
    name = "/vpc/id"
}

## load balancer listner arn
data "aws_ssm_parameter" "listerner_arn" {
    name = "/alb/listernerarn"
}

data "aws_ssm_parameter" "redis_endpoint" {
    name = "/redis/endpoint"
}

data "aws_ssm_parameter" "redis_port" {
    name = "/redis/port"
}

data "aws_ssm_parameter" "timezone" {
    name = "/timezone"
}

data "aws_ssm_parameter" "session_domain" {
    name = "/session/domain"
}

data "aws_ssm_parameter" "session_cookie" {
    name = "/session/cookie"
}

##############################################################
## Used in ECS Service - AWS Secrets ##
##############################################################

data "aws_secretsmanager_secret" "database" {
    name = var.database_secrets
}

data "aws_secretsmanager_secret_version" "database" {
    secret_id = data.aws_secretsmanager_secret.database.id
}

data "aws_secretsmanager_secret" "common" {
    name = var.common_secrets
}

data "aws_secretsmanager_secret_version" "common" {
    secret_id = data.aws_secretsmanager_secret.common.id
}

data "aws_caller_identity" "current" {}

locals {
    image_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
    #image_name = "111111111.dkr.ecr.ap-southeast-1.amazonaws.com/redis-cache-staging-service"
}
##############################################################
## Resource Creation 1.1: ECS - Log Group
##############################################################
resource "aws_cloudwatch_log_group" "main" {
    name = "${var.project}-${var.environment}-${var.service_name}"

    tags = {
        Name        = "${var.project}-${var.environment}-${var.service_name}"
        Environment = var.environment
    }
}

##############################################################
## Resource Creation 1.2: ECS - Task Definition
##############################################################
resource "aws_ecs_task_definition" "service" {
    family                   = "${var.project}-${var.environment}-${var.service_name}-td"
    execution_role_arn       = data.aws_ssm_parameter.ecs_taskexecution_role.value
    task_role_arn            = data.aws_ssm_parameter.ecs_taskexecution_role.value
    cpu                      = var.cpu
    memory                   = var.memory
    requires_compatibilities = ["FARGATE"]
    network_mode             = "awsvpc"
    container_definitions    = jsonencode([
        {
            name         = "${var.project}-${var.environment}-${var.service_name}-php"
            image        = "${local.image_url}/${var.phpapp_image_tag}"
            essential    = true
            portMappings = [
                {
                    containerPort = 9000
                    hostPort      = 9000
                }
            ]
            environment = [
                {
                    name  = "APP_NAME"
                    value = "call-records"
                },
                {
                    name  = "APP_DEBUG"
                    value = "false"
                },
                {
                    name  = "APP_ENV"
                    value = var.environment
                },
                {
                    name  = "APP_URL"
                    value = "https://${var.host_header}"
                },
                {
                    name  = "ASSET_URL"
                    value = "https://${var.host_header}"
                },
                {
                    name  = "REDIS_HOST"
                    value = data.aws_ssm_parameter.redis_endpoint.value
                },
                {
                    name  = "REDIS_PORT"
                    value = data.aws_ssm_parameter.redis_port.value
                },
                {
                    name  = "LOG_CHANNEL"
                    value = "stack"
                },
                {
                    name  = "CACHE_DRIVER"
                    value = "redis"
                },
                {
                    name  = "BROADCAST_DRIVER"
                    value = "log"
                },
                {
                    name  = "FILESYSTEM_DRIVER"
                    value = "s3"
                },
                {
                    name  = "SESSION_DRIVER"
                    value = "database"
                },
                {
                    name  = "QUEUE_CONNECTION"
                    value = "sqs"
                },
                {
                    name  = "SQS_QUEUE"
                    value = data.aws_ssm_parameter.sqs_queue.value
                },
                {
                    name  = "DB_CONNECTION"
                    value = "mysql"
                },
                {
                    "name"  = "DB_PORT"
                    "value" = "3306"
                },
                {
                    name  = "DB_DATABASE"
                    value = "iposgcom_custlog"
                },
                {
                    name  = "TIMEZONE"
                    value = data.aws_ssm_parameter.timezone.value
                },
                {
                    "name" : "AWS_BUCKET",
                    "value" : "iposg-calls-app"
                },
                {
                    "name" : "VONAGE_FETCH_PER_PAGE",
                    "value" : "150"
                },
                {
                    "name" : "VONAGE_CALL_RECORDING_BASE_URL",
                    "value" : "https://api.vonage.com/t/vbc.prod/call_recording/"
                }
            ]
            secrets = [
                {
                    "name"      = "ENCRYPT_KEY",
                    "valueFrom" = "${data.aws_secretsmanager_secret_version.common.arn}:APP_KEY::"
                },
                {
                    "name"      = "APP_KEY",
                    "valueFrom" = "${data.aws_secretsmanager_secret_version.common.arn}:APP_KEY::"
                },
                {
                    "name"      = "AWS_ACCESS_KEY_ID",
                    "valueFrom" = "${data.aws_secretsmanager_secret_version.common.arn}:AWS_ACCESS_KEY_ID::"
                },
                {
                    "name"      = "AWS_DEFAULT_REGION",
                    "valueFrom" = "${data.aws_secretsmanager_secret_version.common.arn}:AWS_DEFAULT_REGION::"
                },
                {
                    "name"      = "AWS_SECRET_ACCESS_KEY",
                    "valueFrom" = "${data.aws_secretsmanager_secret_version.common.arn}:AWS_SECRET_ACCESS_KEY::"
                },
                {
                    name      = "SQS_REGION"
                    valueFrom = "${data.aws_secretsmanager_secret_version.common.arn}:AWS_DEFAULT_REGION::"
                },
                {
                    "name"      = "SQS_PREFIX"
                    "valueFrom" = "${data.aws_secretsmanager_secret_version.common.arn}:SQS_PREFIX::"
                },
                {
                    "name"      = "SQS_KEY"
                    "valueFrom" = "${data.aws_secretsmanager_secret_version.common.arn}:SQS_KEY::"
                },
                {
                    "name"      = "SQS_SECRET"
                    "valueFrom" = "${data.aws_secretsmanager_secret_version.common.arn}:SQS_SECRET::"
                },
                {
                    "name"      = "DB_HOST"
                    "valueFrom" = "${data.aws_secretsmanager_secret_version.database.arn}:DB_CUSTLOG_HO_HOST::"
                },
                {
                    "name"      = "DB_USERNAME"
                    "valueFrom" = "${data.aws_secretsmanager_secret_version.database.arn}:DB_CUSTLOG_HO_USER::"
                },
                {
                    "name"      = "DB_PASSWORD"
                    "valueFrom" = "${data.aws_secretsmanager_secret_version.database.arn}:DB_CUSTLOG_HO_PASS::"
                },
                {
                    "name" : "VONAGE_CLIENT_ID",
                    "valueFrom" = "${data.aws_secretsmanager_secret_version.common.arn}:VONAGE_CLIENT_ID::"
                },
                {
                    "name" : "VONAGE_CLIENT_SECRET",
                    "valueFrom" = "${data.aws_secretsmanager_secret_version.common.arn}:VONAGE_CLIENT_SECRET::"
                },
                {
                    "name" : "VONAGE_USERNAME",
                    "valueFrom" = "${data.aws_secretsmanager_secret_version.common.arn}:VONAGE_USERNAME::"
                },
                {
                    "name" : "VONAGE_PASSWORD",
                    "valueFrom" = "${data.aws_secretsmanager_secret_version.common.arn}:VONAGE_PASSWORD::"
                }
            ]
            logConfiguration = {
                logDriver = "awslogs"
                options   = {
                    awslogs-group         = aws_cloudwatch_log_group.main.name
                    awslogs-region        = var.region
                    awslogs-stream-prefix = "ecs"
                }
            }
        },
        {
            name         = "${var.project}-${var.environment}-${var.service_name}-nginx"
            image        = "${local.image_url}/${var.nginx_image_tag}"
            essential    = true
            portMappings = [
                {
                    containerPort = 80
                    hostPort      = 80
                }
            ]
            environment = [
                {
                    name  = "BACKEND_URL"
                    value = "localhost:9000"
                }
            ]
            logConfiguration = {
                logDriver = "awslogs"
                options   = {
                    awslogs-group         = aws_cloudwatch_log_group.main.name
                    awslogs-region        = var.region
                    awslogs-stream-prefix = "ecs"
                }
            }
        },
        {
            name        = "${var.project}-${var.environment}-${var.service_name}-sqs"
            image       = "shamayil/sqs-cron-worker:2.0"
            essential   = true
            environment = [
                {
                    name  = "MAX_IN_FLIGHT"
                    value = "1"
                },
                {
                    name  = "API_URL"
                    value = "http://localhost:80/worker/queue"
                },
                {
                    name  = "BATCH_SIZE"
                    value = "1"
                },
                {
                    name  = "QUEUE_NAME"
                    value = data.aws_ssm_parameter.sqs_queue.value
                },
                {
                    name  = "DELAY_SECS"
                    value = "0"
                },
                {
                    name  = "POOL_INTERVAL_MS"
                    value = "200"
                },
                {
                    name  = "QUEUE_REGION"
                    value = var.region
                }
            ]
            secrets = [
                {
                    "name"      = "AWS_ACCESS_KEY_ID",
                    "valueFrom" = "${data.aws_secretsmanager_secret_version.common.arn}:AWS_ACCESS_KEY_ID::"
                },
                {
                    "name"      = "AWS_DEFAULT_REGION",
                    "valueFrom" = "${data.aws_secretsmanager_secret_version.common.arn}:AWS_DEFAULT_REGION::"
                },
                {
                    "name"      = "AWS_SECRET_ACCESS_KEY",
                    "valueFrom" = "${data.aws_secretsmanager_secret_version.common.arn}:AWS_SECRET_ACCESS_KEY::"
                }
            ]
            logConfiguration = {
                logDriver = "awslogs"
                options   = {
                    awslogs-group         = aws_cloudwatch_log_group.main.name
                    awslogs-region        = var.region
                    awslogs-stream-prefix = "ecs"
                }
            }
        }
    ])
    runtime_platform {
        operating_system_family = "LINUX"
        cpu_architecture        = "X86_64"
    }
}

##############################################################
## Resource Creation 1.3: ECS - ECS Service
##############################################################
resource "aws_ecs_service" "main" {
    name                   = "${var.project}-${var.environment}-${var.service_name}-nginx"
    cluster                = data.aws_ssm_parameter.ecs_cluster_arn.value
    task_definition        = aws_ecs_task_definition.service.arn
    desired_count          = var.desired_count
    enable_execute_command = true
    launch_type            = "FARGATE"
    wait_for_steady_state  = true

    deployment_circuit_breaker {
        enable   = true
        rollback = true
    }

    load_balancer {
        target_group_arn = aws_lb_target_group.main.arn
        container_name   = "${var.project}-${var.environment}-${var.service_name}-nginx"
        container_port   = 80
    }

    network_configuration {
        subnets          = split(",", data.aws_ssm_parameter.public_subnet_ids.value)
        security_groups  = [data.aws_ssm_parameter.ecs_sg.value]
        assign_public_ip = true
    }
}


######################################################################
## Resource Creation 1.4: ECS - This creates Target Group and Listerner Rule
#######################################################################
resource "aws_lb_target_group" "main" {
    port        = 8088
    protocol    = "HTTP"
    vpc_id      = data.aws_ssm_parameter.vpc_id.value
    target_type = "ip"

    health_check {
        enabled             = "true"
        path                = "/health"
        healthy_threshold   = 2
        interval            = 60          # Reduce interval for more frequent checks
        matcher             = "200"       # Only consider 200 OK responses as healthy
        timeout             = 30           # Reduce timeout to a more typical 5 seconds
        unhealthy_threshold = 7           # Reduce unhealthy threshold for faster removal
    }

    tags = {
        "name" = "${var.project}-${var.environment}-${var.service_name}"
    }
}

resource "aws_lb_listener_rule" "main" {
    listener_arn = data.aws_ssm_parameter.listerner_arn.value
    priority     = 570

    action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.main.arn
    }

    condition {
        host_header {
            values = [var.host_header]
        }
    }
}

#########################################################################
## Resource Creation 2.1: Route53 - This register the domain in Route53
#########################################################################
resource "aws_route53_record" "main" {
    zone_id = data.aws_route53_zone.public_hostzone.id
    name    = var.subdomain_name
    type    = "A"

    alias {
        name                   = data.aws_lb.alb_name.dns_name
        zone_id                = data.aws_lb.alb_name.zone_id
        evaluate_target_health = true
    }
}

output "hosted_zone_id" {
    value = data.aws_route53_zone.public_hostzone.zone_id
}

#########################################################################
## Resource Creation 3.1: Autoscaling - This manage fargate autoscaling
#########################################################################
resource "aws_appautoscaling_target" "main" {
    count              = var.enable_auto_scaling ? 1 : 0
    max_capacity       = var.max_capacity
    min_capacity       = var.min_capacity
    resource_id        = "service/${data.aws_ssm_parameter.ecs_cluster_name.value}/${var.service_name}"
    scalable_dimension = "ecs:service:DesiredCount"
    service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
    count              = var.enable_auto_scaling ? 1 : 0
    name               = "${var.service_name}-cpu-scale"
    policy_type        = "TargetTrackingScaling"
    resource_id        = aws_appautoscaling_target.main[0].resource_id
    scalable_dimension = aws_appautoscaling_target.main[0].scalable_dimension
    service_namespace  = aws_appautoscaling_target.main[0].service_namespace

    target_tracking_scaling_policy_configuration {
        target_value       = 70
        scale_in_cooldown  = 300
        scale_out_cooldown = 300
        predefined_metric_specification {
            predefined_metric_type = "ECSServiceAverageCPUUtilization"
        }
    }
}

resource "aws_appautoscaling_policy" "memory" {
    count              = var.enable_auto_scaling ? 1 : 0
    name               = "${var.service_name}-memory-scale"
    policy_type        = "TargetTrackingScaling"
    resource_id        = aws_appautoscaling_target.main[0].resource_id
    scalable_dimension = aws_appautoscaling_target.main[0].scalable_dimension
    service_namespace  = aws_appautoscaling_target.main[0].service_namespace

    target_tracking_scaling_policy_configuration {
        target_value       = 60
        scale_in_cooldown  = 300
        scale_out_cooldown = 300
        predefined_metric_specification {
            predefined_metric_type = "ECSServiceAverageMemoryUtilization"
        }
    }
}
