resource "aws_vpc" "vpc" {
    cidr_block = "172.31.0.0/16"
    enable_dns_hostnames = true
    enable_dns_support = true

    tags = {
        Name = format("%s-vpc", var.org)
    }
}

resource "aws_main_route_table_association" "vpc_rt_association" {
    vpc_id = aws_vpc.vpc.id
    route_table_id = aws_vpc.vpc.default_route_table_id
}

resource "aws_default_route_table" "rt" {
    default_route_table_id = aws_vpc.vpc.default_route_table_id

    tags = {
        Name = format("%s-rt", var.org)
    }
}

resource "aws_default_network_acl" "network_acl" {
    default_network_acl_id = aws_vpc.vpc.default_network_acl_id

    tags = {
        Name = format("%s-network-acl", var.org)
    }

    lifecycle {
        ignore_changes = [egress, ingress, subnet_ids]
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vpc.id

    tags = {
        Name = format("%s-igw", var.org)
    }
}

locals {
    subnets = [
        {
            cidr_block = "172.31.16.0/20"
            az = "us-east-1a"
        },
        {
            cidr_block = "172.31.32.0/20"
            az = "us-east-1b"
        },
        {
            cidr_block = "172.31.0.0/20"
            az = "us-east-1c"
        }
    ]
    subnets_ids = [ for subnet in aws_subnet.subnets: subnet.id]
    network_acls = [
        {
            rule_number = 10
            protocol = "tcp"
            from_port = 80
            to_port = 80
            cidr_block =  "0.0.0.0/0"
            rule_action = "allow"
            egress = false
        },
        {
            rule_number = 20
            protocol = "tcp"
            from_port = 1024
            to_port = 65535
            cidr_block =  "0.0.0.0/0"
            rule_action = "allow"
            egress = false
        },
        {
            rule_number = 100
            protocol = "all"
            from_port = 0
            to_port = 0
            cidr_block =  "0.0.0.0/0"
            rule_action = "deny"
            egress = false
        },
        {
            rule_number = 10
            protocol = "tcp"
            from_port = 443
            to_port = 443
            cidr_block =  "0.0.0.0/0"
            rule_action = "allow"
            egress = true
        },
        {
            rule_number = 20
            protocol = "tcp"
            from_port = 80
            to_port = 80
            cidr_block =  "0.0.0.0/0"
            rule_action = "allow"
            egress = true
        },
        {
            rule_number = 30
            protocol = "tcp"
            from_port = 1024
            to_port = 65535
            cidr_block =  "0.0.0.0/0"
            rule_action = "allow"
            egress = true
        },
        {
            rule_number = 100
            protocol = "all"
            from_port = 0
            to_port = 0
            cidr_block =  "0.0.0.0/0"
            rule_action = "deny"
            egress = true
        }
    ]
    security_groups = {
        web = {
            rules = [
                {
                    type = "ingress"
                    from_port = 8080
                    to_port = 8080
                    protocol = "tcp"
                    cidr_blocks = ["0.0.0.0/0"]
                },
                {
                    type = "egress"
                    from_port = 0
                    to_port = 0
                    protocol = "all"
                    cidr_blocks = ["0.0.0.0/0"]
                }
            ]
        }
        hello = {
            rules = [
                {
                    type = "ingress"
                    from_port = 8080
                    to_port = 8080
                    protocol = "tcp"
                    cidr_blocks = ["0.0.0.0/0"]
                },
                {
                    type = "egress"
                    from_port = 0
                    to_port = 0
                    protocol = "all"
                    cidr_blocks = ["0.0.0.0/0"]
                }
            ]
        }
        lb = {
            rules = [
                {
                    type = "ingress"
                    from_port = 80
                    to_port = 80
                    protocol = "tcp"
                    cidr_blocks = ["0.0.0.0/0"]
                },
                {
                    type = "egress"
                    from_port = 0
                    to_port = 0
                    protocol = "all"
                    cidr_blocks = ["0.0.0.0/0"]
                }
            ]
        }
    }
    security_group_name_id_map = zipmap(
        [for sgName, options in local.security_groups: sgName],
        [for sg in aws_security_group.sgs: sg.id]
    )
    security_groups_rules = flatten(
        [for sgName, options in local.security_groups: 
            [for rule in options.rules: merge(rule, {id = lookup(local.security_group_name_id_map, sgName)})]
        ]
    )
    security_groups_ids = [for sg in aws_security_group.sgs: sg.id]
    services = {
        web = {
            cpu = 256
            memory = 512
            essential = true
            containerPort = 8080
            desired_count = 1
            health_path = "/ping"
            listener_priority = 20
        }
        hello = {
            cpu = 256
            memory = 512
            essential = true
            containerPort = 8080
            desired_count = 1
            health_path = "/ping"
            listener_priority = 10
        }
    }
    service_target_group_id_map = zipmap(
        [for serviceName, options in local.services: serviceName],
        [for tg in aws_lb_target_group.lb_tgs: tg.id]
    )
    service_repository_map = zipmap(
        [for serviceName, options in local.services: serviceName ],
        [for repo in aws_ecr_repository.ecr_repositories: repo.repository_url]
    )
    service_task_definition_map = zipmap(
        [for serviceName, options in local.services: serviceName],
        [for taskDefinition in aws_ecs_task_definition.taskDefinitions: taskDefinition.arn]
    )
}

resource "aws_subnet" "subnets" {
    count = length(local.subnets)

    vpc_id = aws_vpc.vpc.id
    cidr_block = element(local.subnets, count.index).cidr_block
    availability_zone = element(local.subnets, count.index).az
    tags = {
        Name = format("%s-subnet-%s", var.org, count.index)
    }
}

resource "aws_route_table_association" "rt_subnets_association" {
    count = length(local.subnets_ids)
    
    subnet_id = element(local.subnets_ids, count.index)
    route_table_id = aws_default_route_table.rt.id
}

resource "aws_route" "rt_allow_all" {
    route_table_id = aws_default_route_table.rt.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
}

resource "aws_network_acl_rule" "networkc_acl_rules" {
    count = length(local.network_acls)

    network_acl_id = aws_default_network_acl.network_acl.id
    rule_number = element(local.network_acls, count.index).rule_number
    egress = element(local.network_acls, count.index).egress
    protocol = element(local.network_acls, count.index).protocol
    rule_action = element(local.network_acls, count.index).rule_action
    cidr_block = element(local.network_acls, count.index).cidr_block
    from_port = element(local.network_acls, count.index).from_port
    to_port = element(local.network_acls, count.index).to_port
}

resource "aws_security_group" "sgs" {
    for_each = local.security_groups
    vpc_id = aws_vpc.vpc.id
    name = format("%s-%s-sg", var.org, each.key)

    tags = {
        Name = format("%s-%s-sg", var.org, each.key)
    }
}

resource "aws_security_group_rule" "sgs_rules" {
    count = length(local.security_groups_rules)

    security_group_id = element(local.security_groups_rules, count.index).id
    type = element(local.security_groups_rules, count.index).type
    from_port = element(local.security_groups_rules, count.index).from_port
    to_port = element(local.security_groups_rules, count.index).to_port
    protocol = element(local.security_groups_rules, count.index).protocol
    cidr_blocks = element(local.security_groups_rules, count.index).cidr_blocks
}

resource "aws_lb" "lb" {
    name = format("%s-lb", var.org)
    internal = false
    load_balancer_type = "application"
    subnets = local.subnets_ids
    security_groups = [ lookup(local.security_group_name_id_map, "lb") ]
}

resource "aws_lb_listener" "http_listener" {
    load_balancer_arn = aws_lb.lb.arn
    port = "80"
    protocol = "HTTP"
    
    default_action {
        type = "forward"
        target_group_arn = lookup(local.service_target_group_id_map, "web")
    }
}

resource "aws_lb_listener_rule" "listener_rules" {
    for_each = local.services
    listener_arn = aws_lb_listener.http_listener.arn
    priority = each.value.listener_priority

    action {
        type = "forward"
        target_group_arn = lookup(local.service_target_group_id_map, each.key)
    }

    condition {
        http_header {
            http_header_name = "X-Service"
            values = [ each.key ]
        }
    }
}

resource "aws_lb_target_group" "lb_tgs" {
    for_each = local.services

    name = format("%s-%s-tg", var.org ,each.key)
    port = 80
    protocol = "HTTP"
    target_type = "ip"
    vpc_id = aws_vpc.vpc.id

    health_check {
        enabled = true
        path = each.value.health_path
    }
}

resource "aws_ecs_cluster" "cluster" {
    name = "cluster"
    capacity_providers = ["FARGATE"]

    setting {
        name = "containerInsights"
        value = "disabled"
    }

    default_capacity_provider_strategy {
        capacity_provider=  "FARGATE"
    }
}

resource "aws_ecr_repository" "ecr_repositories" {
    for_each = local.services

    name = format("%s-%s", var.org, each.key)
    image_tag_mutability = "IMMUTABLE"

    tags = {
        Name = format("%s-%s", var.org, each.key)
    }    
}

data "aws_iam_policy_document" "bot_role_inline_policy" {
    version = "2012-10-17"
    statement {
        actions = [
            "ecs:*",
            "ecr:*"
        ]
        effect = "Allow"
        resources = ["*"]
    }
}

data "aws_iam_policy_document" "bot_role_assume_policy" {
    version = "2012-10-17"
    statement {
        actions = [
            "sts:AssumeRole"
        ]
        effect = "Allow"
        principals {
            type = "Service"
            identifiers = [
                "ecs.amazonaws.com",
               "ecs-tasks.amazonaws.com",
            ]
        }
    }
}

resource "aws_iam_role" "bot_role" {
    name = format("%s-bot-role", var.org)
    assume_role_policy = data.aws_iam_policy_document.bot_role_assume_policy.json

    inline_policy { 
        name = format("%s-bot-role-inline-policy", var.org)
        policy = data.aws_iam_policy_document.bot_role_inline_policy.json
    }

    tags = {
        Name = format("%s-bot-role", var.org)
    }
}

resource "aws_ecs_task_definition" "taskDefinitions" {
    for_each = local.services
    family = format("%s-task-definition", each.key)
    cpu = each.value.cpu
    memory = each.value.memory
    network_mode = "awsvpc"
    requires_compatibilities = ["FARGATE"]
    task_role_arn = aws_iam_role.bot_role.arn
    execution_role_arn = aws_iam_role.bot_role.arn
    
    container_definitions = jsonencode([
        {
            name = each.key
            image = lookup(local.service_repository_map, each.key)
            cpu = each.value.cpu
            memory = each.value.memory
            essential = each.value.essential
            portMappings = [
                {
                    containerPort = each.value.containerPort
                    hostPort = each.value.containerPort
                }
            ] 
        }
    ])
}

resource "aws_ecs_service" "ecs_services" {
    for_each = local.services
    name = format("%s-service", each.key)
    cluster = aws_ecs_cluster.cluster.id
    task_definition = lookup(local.service_task_definition_map, each.key)
    desired_count = each.value.desired_count
    launch_type = "FARGATE"
    wait_for_steady_state = false

    network_configuration {
        subnets = local.subnets_ids
        security_groups = [ lookup(local.security_group_name_id_map, each.key) ]
        assign_public_ip = true
    }
    
    load_balancer {
        target_group_arn = lookup(local.service_target_group_id_map, each.key)
        container_name = each.key
        container_port = each.value.containerPort
    }

//    depends_on = [
//        aws_lb_listener.http_listener
//    ]
}