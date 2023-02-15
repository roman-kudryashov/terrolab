resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = var.vpc_instance_tenancy
  enable_dns_support   = var.vpc_enable_dns_support
  enable_dns_hostnames = var.vpc_enable_dns_hostnames
  enable_classiclink   = var.vpc_enable_classiclink

  tags = merge(
    var.default_tags,
    tomap({
      "Name" = join("-", tolist([var.default_tags["Project"], "vpc"]))
    })
  )
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.default_tags,
    tomap(
      {
        "Name"        = join("-", tolist([var.default_tags["Project"], aws_vpc.this.id, "igw"])),
        "Description" = "Internet Gateway"
      }
    )
  )
}

resource "aws_subnet" "public_subnet" {
  for_each                = var.subnet_settings
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value["cidr"]
  availability_zone       = "${var.region}${each.value["az"]}"
  map_public_ip_on_launch = each.value["map_public_ip_on_launch"]

  tags = merge(
    var.default_tags,
    tomap({
      "Name"        = join("-", tolist([var.default_tags["Project"], each.key])),
      "Description" = "${var.region}${each.value["az"]} public subnet"
    })
  )
}

resource "aws_subnet" "private_subnet" {
  for_each                = var.private_subnet_settings
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value["cidr"]
  availability_zone       = "${var.region}${each.value["az"]}"
  map_public_ip_on_launch = each.value["map_public_ip_on_launch"]

  tags = merge(
    var.default_tags,
    tomap({
      "Name"        = join("-", tolist([var.default_tags["Project"], each.key, "private"])),
      "Description" = "${var.region}${each.value["az"]} private subnet"
    })
  )
}

resource "aws_route_table" "default-public" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.default_tags,
    tomap({
      "Name"        = join("-", tolist([var.default_tags["Project"], "default-public"])),
      "Description" = "Default public route table"
    })
  )
}

resource "aws_route_table" "default-private" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.default_tags,
    tomap({
      "Name"        = join("-", tolist([var.default_tags["Project"], "default-private"])),
      "Description" = "Default private route table"
    })
  )
}

resource "aws_route" "igw" {
  route_table_id         = aws_route_table.default-public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
  depends_on             = [aws_route_table.default-public]
}

resource "aws_route_table_association" "default-public-association" {
  for_each       = var.subnet_settings
  subnet_id      = aws_subnet.public_subnet[each.key].id
  route_table_id = aws_route_table.default-public.id
}

resource "aws_route_table_association" "default-private-association" {
  for_each       = var.private_subnet_settings
  subnet_id      = aws_subnet.private_subnet[each.key].id
  route_table_id = aws_route_table.default-private.id
}

locals {
  ec2_pool_sg = {
    ssh = {
      cidr_blocks     = []
      security_groups = [aws_security_group.bastion.id]
    }
    nfs = {
      cidr_blocks     = [aws_vpc.this.cidr_block]
      security_groups = []
    }
    ghost = {
      cidr_blocks     = [aws_vpc.this.cidr_block]
      security_groups = []
    }
  }
  fargate = {
    nfs = {
      cidr_blocks     = [aws_vpc.this.cidr_block]
      security_groups = []
    }
    ghost = {
      cidr_blocks     = [aws_vpc.this.cidr_block]
      security_groups = []
    }
  }
  alb_sg = {
    global = {
      security_groups = [
        aws_security_group.ec2-pool.id,
        aws_security_group.fargate.id
      ]
    }
  }
  efs_sg = {
    nfs = {
      security_groups = [
        aws_security_group.ec2-pool.id,
        aws_security_group.fargate.id
      ]
    }
    global = {
      cidr_blocks = [aws_vpc.this.cidr_block]
    }
  }
  rds_sg = {
    mysql = {
      security_groups = [
        aws_security_group.ec2-pool.id,
        aws_security_group.fargate.id
      ]
    }
  }
  endpoint_sg = {
    global = {
      cidr_blocks = [aws_vpc.this.cidr_block]
    }
  }
}

resource "aws_security_group" "bastion" {
  name        = join("-", tolist([var.default_tags["Project"], var.bastion_sg["name"]]))
  description = var.bastion_sg["tags"]["Description"]
  vpc_id      = aws_vpc.this.id
  lifecycle {
    create_before_destroy = false
  }
  dynamic "ingress" {
    for_each = var.bastion_sg["ingress"]

    content {
      from_port   = ingress.value["from_port"]
      to_port     = ingress.value["to_port"]
      protocol    = ingress.value["protocol"]
      self        = ingress.value["self"]
      cidr_blocks = ingress.value["cidr_blocks"]
      description = ingress.value["description"]
    }
  }

  dynamic "egress" {
    for_each = var.bastion_sg["egress"]

    content {
      from_port   = egress.value["from_port"]
      to_port     = egress.value["to_port"]
      protocol    = egress.value["protocol"]
      self        = egress.value["self"]
      cidr_blocks = egress.value["cidr_blocks"]
      description = egress.value["description"]
    }
  }

  tags = merge(
    var.default_tags,
    tomap({
      "Name" = join("-", tolist([var.default_tags["Project"], var.bastion_sg["name"]]))
    })
  )
}

resource "aws_security_group" "endpoint" {
  name        = join("-", tolist([var.default_tags["Project"], var.endpoint_sg["name"]]))
  description = var.endpoint_sg["tags"]["Description"]
  vpc_id      = aws_vpc.this.id
  lifecycle {
    create_before_destroy = false
  }
  dynamic "ingress" {
    for_each = var.endpoint_sg["ingress"]

    content {
      from_port   = ingress.value["from_port"]
      to_port     = ingress.value["to_port"]
      protocol    = ingress.value["protocol"]
      self        = ingress.value["self"]
      cidr_blocks = local.endpoint_sg[ingress.key]["cidr_blocks"]
      description = ingress.value["description"]
    }
  }

  dynamic "egress" {
    for_each = var.endpoint_sg["egress"]

    content {
      from_port   = egress.value["from_port"]
      to_port     = egress.value["to_port"]
      protocol    = egress.value["protocol"]
      self        = egress.value["self"]
      cidr_blocks = egress.value["cidr_blocks"]
      description = egress.value["description"]
    }
  }

  tags = merge(
    var.default_tags,
    tomap({
      "Name" = join("-", tolist([var.default_tags["Project"], var.endpoint_sg["name"]]))
    })
  )
}

resource "aws_security_group" "ec2-pool" {
  name        = join("-", tolist([var.default_tags["Project"], var.ec2_pool_sg["name"]]))
  description = var.ec2_pool_sg["tags"]["Description"]
  vpc_id      = aws_vpc.this.id

  dynamic "ingress" {
    for_each = var.ec2_pool_sg["ingress"]

    content {
      from_port       = ingress.value["from_port"]
      to_port         = ingress.value["to_port"]
      protocol        = ingress.value["protocol"]
      self            = ingress.value["self"]
      cidr_blocks     = local.ec2_pool_sg[ingress.key]["cidr_blocks"]
      security_groups = local.ec2_pool_sg[ingress.key]["security_groups"]
      description     = ingress.value["description"]
    }
  }

  dynamic "egress" {
    for_each = var.ec2_pool_sg["egress"]

    content {
      from_port   = egress.value["from_port"]
      to_port     = egress.value["to_port"]
      protocol    = egress.value["protocol"]
      self        = egress.value["self"]
      cidr_blocks = egress.value["cidr_blocks"]
      description = egress.value["description"]
    }
  }

  tags = merge(
    var.default_tags,
    tomap({
      "Name" = join("-", tolist([var.default_tags["Project"], var.ec2_pool_sg["name"]]))
    })
  )
}

resource "aws_security_group" "fargate" {
  name        = join("-", tolist([var.default_tags["Project"], var.fargate_sg["name"]]))
  description = var.fargate_sg["tags"]["Description"]
  vpc_id      = aws_vpc.this.id

  dynamic "ingress" {
    for_each = var.fargate_sg["ingress"]

    content {
      from_port       = ingress.value["from_port"]
      to_port         = ingress.value["to_port"]
      protocol        = ingress.value["protocol"]
      self            = ingress.value["self"]
      cidr_blocks     = local.fargate[ingress.key]["cidr_blocks"]
      security_groups = local.fargate[ingress.key]["security_groups"]
      description     = ingress.value["description"]
    }
  }

  dynamic "egress" {
    for_each = var.ec2_pool_sg["egress"]

    content {
      from_port   = egress.value["from_port"]
      to_port     = egress.value["to_port"]
      protocol    = egress.value["protocol"]
      self        = egress.value["self"]
      cidr_blocks = egress.value["cidr_blocks"]
      description = egress.value["description"]
    }
  }

  tags = merge(
    var.default_tags,
    tomap({
      "Name" = join("-", tolist([var.default_tags["Project"], var.fargate_sg["name"]]))
    })
  )
}


resource "aws_security_group" "alb" {
  name        = join("-", tolist([var.default_tags["Project"], var.alb_sg["name"]]))
  description = var.alb_sg["tags"]["Description"]
  vpc_id      = aws_vpc.this.id

  dynamic "ingress" {
    for_each = var.alb_sg["ingress"]

    content {
      from_port   = ingress.value["from_port"]
      to_port     = ingress.value["to_port"]
      protocol    = ingress.value["protocol"]
      self        = ingress.value["self"]
      cidr_blocks = ingress.value["cidr_blocks"]
      description = ingress.value["description"]
    }
  }

  dynamic "egress" {
    for_each = var.alb_sg["egress"]

    content {
      from_port       = egress.value["from_port"]
      to_port         = egress.value["to_port"]
      protocol        = egress.value["protocol"]
      self            = egress.value["self"]
      security_groups = local.alb_sg[egress.key]["security_groups"]
      description     = egress.value["description"]
    }
  }

  tags = merge(
    var.default_tags,
    tomap({
      "Name" = join("-", tolist([var.default_tags["Project"], var.alb_sg["name"]]))
    })
  )
}

resource "aws_security_group" "efs" {
  name        = join("-", tolist([var.default_tags["Project"], var.efs_sg["name"]]))
  description = var.efs_sg["tags"]["Description"]
  vpc_id      = aws_vpc.this.id

  dynamic "ingress" {
    for_each = var.efs_sg["ingress"]

    content {
      from_port       = ingress.value["from_port"]
      to_port         = ingress.value["to_port"]
      protocol        = ingress.value["protocol"]
      self            = ingress.value["self"]
      security_groups = local.efs_sg[ingress.key]["security_groups"]
      description     = ingress.value["description"]
    }
  }

  dynamic "egress" {
    for_each = var.efs_sg["egress"]

    content {
      from_port   = egress.value["from_port"]
      to_port     = egress.value["to_port"]
      protocol    = egress.value["protocol"]
      self        = egress.value["self"]
      cidr_blocks = local.efs_sg[egress.key]["cidr_blocks"]
      description = egress.value["description"]
    }
  }

  tags = merge(
    var.default_tags,
    tomap({
      "Name" = join("-", tolist([var.default_tags["Project"], var.efs_sg["name"]]))
    })
  )
}

resource "aws_key_pair" "ssh" {
  key_name   = var.key_pair["name"]
  public_key = var.key_pair["public_key"]
}

resource "aws_iam_role" "role" {
  name               = join("-", [var.default_tags["Project"], var.iam_role["name"]])
  assume_role_policy = data.aws_iam_policy_document.role.json
  description        = var.iam_role["role_description"]

  tags = merge(
    var.default_tags,
    tomap({
      "Name"        = join("-", [var.default_tags["Project"], var.iam_role["name"]]),
      "Description" = var.iam_role["role_description"]
    })
  )
}

resource "aws_iam_role" "fargate-role" {
  name               = join("-", [var.default_tags["Project"], var.fargate_iam_role["name"]])
  assume_role_policy = data.aws_iam_policy_document.fargate-role.json
  description        = var.fargate_iam_role["role_description"]

  tags = merge(
    var.default_tags,
    tomap({
      "Name"        = join("-", [var.default_tags["Project"], var.fargate_iam_role["name"]]),
      "Description" = var.fargate_iam_role["role_description"]
    })
  )
}

resource "aws_iam_instance_profile" "instance-profile" {
  name = join("-", [var.default_tags["Project"], var.iam_role["name"]])
  role = aws_iam_role.role.name
}

resource "aws_iam_instance_profile" "fargate-instance-profile" {
  name = join("-", [var.default_tags["Project"], var.fargate_iam_role["name"]])
  role = aws_iam_role.fargate-role.name
}

resource "aws_iam_policy" "policy" {
  name        = join("-", [var.default_tags["Project"], var.iam_role["name"]])
  description = var.iam_role["policy_description"]
  policy      = data.aws_iam_policy_document.policy.json
}

resource "aws_iam_policy" "fargate-policy" {
  name        = join("-", [var.default_tags["Project"], var.fargate_iam_role["name"]])
  description = var.fargate_iam_role["policy_description"]
  policy      = data.aws_iam_policy_document.fargate-policy.json
}

resource "aws_iam_role_policy_attachment" "role-policy-attachment" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_iam_role_policy_attachment" "fargate-role-policy-attachment" {
  role       = aws_iam_role.fargate-role.name
  policy_arn = aws_iam_policy.fargate-policy.arn
}

resource "aws_efs_file_system" "efs" {
  creation_token = var.efs_settings["name_prefix"]

  lifecycle_policy {
    transition_to_ia = var.efs_settings["lifecycle_policy"]
  }

  encrypted = var.efs_settings["encrypted"]

  performance_mode = var.efs_settings["performance_mode"]
  throughput_mode  = var.efs_settings["throughput_mode"]

  tags = merge(
    var.default_tags,
    tomap({
      "Name" = join("-", tolist([var.default_tags["Project"], var.efs_settings["name_prefix"]]))
    })
  )

}

resource "aws_efs_mount_target" "mount_target" {
  for_each        = var.subnet_settings
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = aws_subnet.public_subnet[each.key].id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_lb" "loadbalancer" {
  name                             = join("-", tolist(["lb", var.default_tags["Project"], var.lb_settings["name"]]))
  internal                         = var.lb_settings["internal"]
  load_balancer_type               = var.lb_settings["load_balancer_type"]
  security_groups                  = [aws_security_group.alb.id]
  subnets                          = [for k, v in aws_subnet.public_subnet : v.id]
  idle_timeout                     = var.lb_settings["idle_timeout"]
  enable_deletion_protection       = var.lb_settings["enable_deletion_protection"]
  enable_cross_zone_load_balancing = var.lb_settings["enable_cross_zone_load_balancing"]
  enable_http2                     = var.lb_settings["enable_http2"]

  tags = merge(
    var.default_tags,
    tomap({
      "Name" = join("-", tolist([var.default_tags["Project"], var.lb_settings["name"]]))
    })
  )
}

resource "aws_lb_target_group" "target-group" {
  name                 = join("-", tolist([var.default_tags["Project"], var.tg_settings["name"], var.tg_settings["port"]]))
  port                 = var.tg_settings["port"]
  protocol             = var.tg_settings["protocol"]
  vpc_id               = aws_vpc.this.id
  target_type          = var.tg_settings["target_type"]
  deregistration_delay = var.tg_settings["deregistration_delay"]
  slow_start           = var.tg_settings["slow_start"]

  health_check {
    port                = var.tg_settings["port"]
    protocol            = var.tg_settings["protocol"]
    healthy_threshold   = var.tg_settings["health_check_healthy_threshold"]
    interval            = var.tg_settings["health_check_interval"]
    unhealthy_threshold = var.tg_settings["health_check_unhealthy_threshold"]
    path                = var.tg_settings["health_check_path"]
    matcher             = var.tg_settings["health_check_matcher"]
  }

  tags = merge(
    var.default_tags,
    tomap({
      "Name" = join("-", tolist([var.default_tags["Project"], var.tg_settings["name"], var.tg_settings["port"]]))
    })
  )
}

resource "aws_lb_listener" "forward" {
  load_balancer_arn = aws_lb.loadbalancer.arn
  port              = var.listeners_settings["port"]
  protocol          = var.listeners_settings["protocol"]

  default_action {
    type = var.listeners_settings["type"]
    forward {
      target_group {
        arn    = aws_lb_target_group.target-group.arn
        weight = 50
      }
      target_group {
        arn    = aws_lb_target_group.ecs-target-group.arn
        weight = 50
      }
    }
  }
}

resource "aws_launch_template" "lt" {
  name                    = join("-", tolist([var.default_tags["Project"], var.ghost_instance_settings["name"]]))
  instance_type           = var.ghost_instance_settings["instance_type"]
  key_name                = aws_key_pair.ssh.key_name
  disable_api_termination = var.ghost_instance_settings["disable_api_termination"]
  user_data               = base64encode(data.template_file.user-data.rendered)
  image_id                = data.aws_ami.amazon-linux-2.id
  vpc_security_group_ids  = [aws_security_group.ec2-pool.id]

  dynamic "block_device_mappings" {
    for_each = try(var.ghost_instance_settings["ebs_block_device"], {})
    content {
      device_name = block_device_mappings.key
      ebs {
        volume_type           = block_device_mappings.value["volume_type"]
        volume_size           = block_device_mappings.value["volume_size"]
        delete_on_termination = block_device_mappings.value["delete_on_termination"]
      }
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.instance-profile.name
  }


  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.default_tags,
      tomap({
        "Name" = join("-", tolist(["from-lt", var.default_tags["Project"], var.ghost_instance_settings["name"], "instance"]))
      })
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      var.default_tags,
      tomap({
        "Name" = join("-", tolist(["from-lt", var.default_tags["Project"], var.ghost_instance_settings["name"], "volume"]))
      })
    )
  }

}

resource "aws_autoscaling_group" "asg" {
  name                      = join("-", tolist([var.default_tags["Project"], var.asg_settings["name"]]))
  min_size                  = var.asg_settings["min_size"]
  desired_capacity          = var.asg_settings["desired_capacity"]
  max_size                  = var.asg_settings["max_size"]
  health_check_type         = var.asg_settings["health_check_type"]
  health_check_grace_period = var.asg_settings["health_check_grace_period"]
  default_cooldown          = var.asg_settings["default_cooldown"]
  vpc_zone_identifier       = [for k, v in aws_subnet.public_subnet : v.id]
  target_group_arns         = [aws_lb_target_group.target-group.id]

  launch_template {
    id      = aws_launch_template.lt.id
    version = var.asg_settings["version"]
  }

}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon-linux-2.id
  instance_type               = var.bastion_instance_settings["instance_type"]
  key_name                    = aws_key_pair.ssh.key_name
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  subnet_id                   = aws_subnet.public_subnet["subnet-1"].id
  associate_public_ip_address = var.bastion_instance_settings["associate_public_ip_address"]
  source_dest_check           = var.bastion_instance_settings["source_dest_check"]

  root_block_device {
    volume_type           = var.bastion_instance_settings["ebs_block_device"]["root"]["volume_type"]
    volume_size           = var.bastion_instance_settings["ebs_block_device"]["root"]["volume_size"]
    delete_on_termination = var.bastion_instance_settings["ebs_block_device"]["root"]["delete_on_termination"]

    tags = merge(
      var.default_tags,
      tomap({
        "Name" = join("-", concat(tolist([var.default_tags["Project"], var.bastion_instance_settings["name"], "ebs-root"])))
      })
    )

  }


  tags = merge(
    var.default_tags,
    tomap({
      "Name" = join("-", concat(tolist([var.default_tags["Project"], var.bastion_instance_settings["name"], "instance"])))
    })
  )

}

resource "aws_kms_key" "rds-kms-key" {
  description             = "For RDS"
  deletion_window_in_days = 10

  tags = merge(
    var.default_tags,
    tomap({
      "Name" = join("-", tolist([var.default_tags["Project"], var.rds_settings["name"]]))
    })
  )
}

resource "aws_kms_alias" "kms-rds-alias" {
  name          = "alias/${var.default_tags["Project"]}/${var.rds_settings["name"]}"
  target_key_id = aws_kms_key.rds-kms-key.id
}

resource "random_string" "password" {
  length           = 16
  special          = false
  override_special = "!@#$&"
}

resource "aws_ssm_parameter" "secret" {
  name        = "/${var.rds_settings["name"]}/dbpasswd"
  description = "RDS Ghost password"
  type        = "SecureString"
  value       = random_string.password.result

  tags = merge(
    var.default_tags,
    tomap({
      "Name" = join("-", tolist([var.default_tags["Project"], var.rds_settings["name"]]))
    })
  )
}

resource "aws_db_subnet_group" "rds-subnet-group" {
  name        = join("-", tolist([var.default_tags["Project"], var.rds_settings["name"]]))
  description = "Ghost RDS"
  subnet_ids  = [for k, v in aws_subnet.private_subnet : v.id]

  tags = merge(
    var.default_tags,
    tomap({
      "Name" = join("-", tolist([var.default_tags["Project"], var.rds_settings["name"]]))
    })
  )
}

resource "aws_security_group" "rds" {
  name        = join("-", tolist([var.default_tags["Project"], var.rds_sg["name"]]))
  description = var.rds_sg["tags"]["Description"]
  vpc_id      = aws_vpc.this.id

  dynamic "ingress" {
    for_each = var.rds_sg["ingress"]

    content {
      from_port       = ingress.value["from_port"]
      to_port         = ingress.value["to_port"]
      protocol        = ingress.value["protocol"]
      self            = ingress.value["self"]
      security_groups = local.rds_sg[ingress.key]["security_groups"]
      description     = ingress.value["description"]
    }
  }

  dynamic "egress" {
    for_each = var.rds_sg["egress"]

    content {
      from_port   = egress.value["from_port"]
      to_port     = egress.value["to_port"]
      protocol    = egress.value["protocol"]
      self        = egress.value["self"]
      cidr_blocks = egress.value["cidr_blocks"]
      description = egress.value["description"]
    }
  }

  tags = merge(
    var.default_tags,
    tomap({
      "Name" = join("-", tolist([var.default_tags["Project"], var.rds_sg["name"]]))
    })
  )
}
resource "aws_db_instance" "rds" {
  identifier              = join("-", tolist([var.default_tags["Project"], var.rds_settings["name"]]))
  name                    = var.rds_settings["dbname"]
  allocated_storage       = var.rds_settings["allocated_storage"]
  storage_type            = var.rds_settings["storage_type"]
  engine                  = var.rds_settings["engine"]
  availability_zone       = var.rds_settings["availability_zone"]
  engine_version          = var.rds_settings["engine_version"]
  instance_class          = var.rds_settings["instance_class"]
  username                = var.rds_settings["username"]
  password                = random_string.password.result
  vpc_security_group_ids  = [aws_security_group.rds.id]
  db_subnet_group_name    = aws_db_subnet_group.rds-subnet-group.name
  kms_key_id              = aws_kms_key.rds-kms-key.arn
  parameter_group_name    = aws_db_parameter_group.rds-pg.name
  storage_encrypted       = var.rds_settings["storage_encrypted"]
  skip_final_snapshot     = var.rds_settings["skip_final_snapshot"]
  backup_retention_period = var.rds_settings["backup_retention_period"]
  backup_window           = var.rds_settings["backup_window"]

  tags = merge(
    var.default_tags,
    tomap({
      "Name" = join("-", tolist([var.default_tags["Project"], var.rds_settings["name"]]))
    })
  )
}

resource "aws_db_parameter_group" "rds-pg" {
  name   = join("-", tolist([var.default_tags["Project"], var.rds_settings["name"]]))
  family = var.rds_settings["family"]

  parameter {
    name  = "general_log"
    value = 0
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  tags = merge(
    var.default_tags,
    tomap({
      "Name" = join("-", tolist([var.default_tags["Project"], var.rds_settings["name"]]))
    })
  )
}

resource "aws_ecr_repository" "ecr" {
  name                 = join("-", tolist([var.default_tags["Project"], var.ecr_settings["name"]]))
  image_tag_mutability = var.ecr_settings["image_tag_mutability"]

  image_scanning_configuration {
    scan_on_push = var.ecr_settings["scan_on_push"]
  }

  tags = merge(
    var.default_tags,
    {
      "Name"        = join("-", tolist([var.default_tags["Project"], var.ecr_settings["name"]])),
      "Description" = "Ghost Container registry."
    }
  )
}

resource "aws_vpc_endpoint" "vpc_endpoint" {

  for_each = try(var.vpc_endpoint_settings["endpoints"], {})

  vpc_id              = aws_vpc.this.id
  service_name        = data.aws_vpc_endpoint_service.vpc_endpoint_service[each.key].service_name
  vpc_endpoint_type   = lookup(each.value, "service_type", "Interface")
  security_group_ids  = lookup(each.value, "service_type", "Interface") == "Interface" ? distinct(concat([aws_security_group.endpoint.id], lookup(each.value, "security_group_ids", []))) : null
  subnet_ids          = lookup(each.value, "service_type", "Interface") == "Interface" ? distinct(concat([for k, v in aws_subnet.private_subnet : v.id], lookup(each.value, "subnet_ids", []))) : null
  route_table_ids     = lookup(each.value, "service_type", "Interface") == "Gateway" ? distinct(concat([aws_route_table.default-private.id], lookup(each.value, "route_table_ids", []))) : null
  private_dns_enabled = lookup(each.value, "service_type", "Interface") == "Interface" ? lookup(each.value, "private_dns_enabled", null) : null

  tags = merge(
    var.default_tags,
    {
      Name = join("-", [var.default_tags["Project"], each.value["service"], lower(each.value["service_type"]), "endpoint"])
    }
  )
}

resource "aws_lb_target_group" "ecs-target-group" {
  name                 = join("-", tolist([var.default_tags["Project"], var.ecs_tg_settings["name"], var.ecs_tg_settings["port"]]))
  port                 = var.ecs_tg_settings["port"]
  protocol             = var.ecs_tg_settings["protocol"]
  vpc_id               = aws_vpc.this.id
  target_type          = var.ecs_tg_settings["target_type"]
  deregistration_delay = var.ecs_tg_settings["deregistration_delay"]
  slow_start           = var.ecs_tg_settings["slow_start"]

  health_check {
    port                = var.ecs_tg_settings["port"]
    protocol            = var.ecs_tg_settings["protocol"]
    healthy_threshold   = var.ecs_tg_settings["health_check_healthy_threshold"]
    interval            = var.ecs_tg_settings["health_check_interval"]
    unhealthy_threshold = var.ecs_tg_settings["health_check_unhealthy_threshold"]
    path                = var.ecs_tg_settings["health_check_path"]
    matcher             = var.ecs_tg_settings["health_check_matcher"]
  }

  tags = merge(
    var.default_tags,
    tomap({
      "Name" = join("-", tolist([var.default_tags["Project"], var.ecs_tg_settings["name"], var.ecs_tg_settings["port"]]))
    })
  )
}

resource "aws_ecs_cluster" "ecs" {
  name = join("-", tolist([var.default_tags["Project"], var.ecs_settings["name"]]))
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "ecs" {
  cluster_name = aws_ecs_cluster.ecs.name

  capacity_providers = var.ecs_settings["capacity_providers"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_ecs_task_definition" "ecs" {
  family                   = join("-", tolist([var.default_tags["Project"], var.ecs_settings["name"]]))
  requires_compatibilities = var.ecs_settings["capacity_providers"]
  network_mode             = var.ecs_settings["network_mode"]
  cpu                      = var.ecs_settings["cpu"]
  memory                   = var.ecs_settings["memory"]
  task_role_arn            = aws_iam_role.fargate-role.arn
  execution_role_arn       = aws_iam_role.fargate-role.arn
  volume {
    name = var.ecs_settings["volume_name"]
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.efs.id
    }
  }

  container_definitions = <<TASK_DEFINITION
[
  {
    "name": "ghost_container",
    "image": "${aws_ecr_repository.ecr.repository_url}:latest",
    "essential": true,
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
          "awslogs-create-group": "true",
          "awslogs-group": "ghost",
          "awslogs-region": "${var.region}",
          "awslogs-stream-prefix": "ecs"
      }
    },
    "environment": [
      {
        "name": "database__client",
        "value": "mysql"
      },
      {
        "name": "database__connection__host",
        "value": "${aws_db_instance.rds.address}"
      },
      {
        "name": "database__connection__user",
        "value": "${var.rds_settings["username"]}"
      },
      {
        "name": "database__connection__password",
        "value": "${random_string.password.result}"
      },
      {
        "name": "database__connection__database",
        "value": "${var.rds_settings["dbname"]}"
      }
    ],
    "mountPoints": [
      {
        "containerPath": "/var/lib/ghost/content",
        "sourceVolume": "ghost_volume"
      }
    ],
    "portMappings": [
      {
        "containerPort": 2368,
        "hostPort": 2368
      }
    ]
  }
]

TASK_DEFINITION

}

resource "aws_ecs_service" "ecs" {
  name            = var.ecs_settings["name"]
  cluster         = aws_ecs_cluster.ecs.id
  task_definition = aws_ecs_task_definition.ecs.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  load_balancer {
    target_group_arn = aws_lb_target_group.ecs-target-group.arn
    container_name   = "ghost_container"
    container_port   = "2368"
  }
  network_configuration {
    assign_public_ip = false
    subnets          = [for k, v in aws_subnet.private_subnet : v.id]
    security_groups  = [aws_security_group.fargate.id]
  }
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "terralab"

  dashboard_body = <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [
            "AWS/EC2",
            "CPUUtilization",
            "AutoScalingGroupName",
            "${aws_autoscaling_group.asg.name}"
          ]
        ],
        "period": 300,
        "stat": "Average",
        "region": "${var.region}",
        "title": "Autoscaling group CPU Utilization"
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [
            "AWS/ECS",
            "CPUUtilization",
            "ServiceName",
            "${aws_ecs_service.ecs.name}",
            "ClusterName",
            "${aws_ecs_cluster.ecs.name}"
          ]
        ],
        "period": 300,
        "stat": "Average",
        "region": "${var.region}",
        "title": "ECS service CPU Utilization"
      }
    },
{
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [
            "AWS/EFS",
            "StorageBytes",
            "StorageClass",
            "Total",
            "FileSystemId",
            "${aws_efs_file_system.efs.id}"
          ]
        ],
        "period": 300,
        "stat": "Average",
        "region": "${var.region}",
        "title": "EFS Total Storage."
      }
    },
{
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [
            "AWS/EFS",
            "ClientConnections",
            "FileSystemId",
            "${aws_efs_file_system.efs.id}"
          ]
        ],
        "period": 300,
        "stat": "Average",
        "region": "${var.region}",
        "title": "EFS Client connections."
      }
    },
{
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [
            "AWS/RDS",
            "CPUUtilization",
            "DBInstanceIdentifier",
            "${aws_db_instance.rds.name}"
          ]
        ],
        "period": 300,
        "stat": "Average",
        "region": "${var.region}",
        "title": "RDS CPU Utilization"
      }
    },
{
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [
            "AWS/RDS",
            "DatabaseConnections",
            "DBInstanceIdentifier",
            "${aws_db_instance.rds.name}"
          ]
        ],
        "period": 300,
        "stat": "Average",
        "region": "${var.region}",
        "title": "RDS client connections."
      }
    },
{
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [
            "AWS/RDS",
            "WriteIOPS",
            "DBInstanceIdentifier",
            "${aws_db_instance.rds.name}"
          ]
        ],
        "period": 300,
        "stat": "Average",
        "region": "${var.region}",
        "title": "RDS Write IOPS."
      }
    },
{
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [
            "AWS/RDS",
            "ReadIOPS",
            "DBInstanceIdentifier",
            "${aws_db_instance.rds.name}"
          ]
        ],
        "period": 300,
        "stat": "Average",
        "region": "${var.region}",
        "title": "RDS Read IOPS."
      }
    },
{
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [
            "ECS/ContainerInsights",
            "RunningTaskCount",
            "ServiceName",
            "${aws_ecs_service.ecs.name}",
            "ClusterName",
            "${aws_ecs_cluster.ecs.name}"
          ]
        ],
        "period": 300,
        "stat": "Average",
        "region": "${var.region}",
        "title": "ECS Running task acount."
      }
    }
  ]
}
EOF
}