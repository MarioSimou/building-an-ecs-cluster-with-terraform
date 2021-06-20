output "vpc_id" {
    description = "vpc id"
    value = aws_vpc.vpc.id
}

output "rt_id" {
    description = "route table id"
    value = aws_vpc.vpc.default_route_table_id
}

output "network_acl_id" {
    description = "route table id"
    value = aws_vpc.vpc.default_network_acl_id
}

output "igw_id" {
    description = "internet gateway id"
    value = aws_internet_gateway.igw.id
}

output "subnets_ids" {
    description = "subnets ids"
    value = local.subnets_ids
}

output "security_groups_ids" {
    description = "security groups ids"
    value = local.security_groups_ids
}

output "lb_id" {
    description = "load balancer id"
    value = aws_lb.lb.id
}

output "lb_dns_name" {
    description = "load balancer DNS name"
    value = aws_lb.lb.dns_name
}