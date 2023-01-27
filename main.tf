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
  alb_sg = {
    global = {
      security_groups = [aws_security_group.ec2-pool.id]
    }
  }
  efs_sg = {
    nfs = {
      security_groups = [aws_security_group.ec2-pool.id]
    }
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

resource "aws_iam_instance_profile" "instance-profile" {
  name = join("-", [var.default_tags["Project"], var.iam_role["name"]])
  role = aws_iam_role.role.name
}

resource "aws_iam_policy" "policy" {
  name        = join("-", [var.default_tags["Project"], var.iam_role["name"]])
  description = var.iam_role["policy_description"]
  policy      = data.aws_iam_policy_document.policy.json
}

resource "aws_iam_role_policy_attachment" "role-policy-attachment" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy.arn
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
    type             = var.listeners_settings["type"]
    target_group_arn = aws_lb_target_group.target-group.arn
  }
}

#resource "aws_lb_target_group_attachment" "target-group-attachment" {
#  count            = length(var.target_instance_id_list)
#  target_group_arn = aws_lb_target_group.target-group.arn
#  target_id        = var.target_instance_id_list[count.index]
#  port             = var.tg_settings["port"]
#}

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
  ami                                  = data.aws_ami.amazon-linux-2.id
  instance_type                        = var.bastion_instance_settings["instance_type"]
  key_name                             = aws_key_pair.ssh.key_name
  vpc_security_group_ids               = [aws_security_group.bastion.id]
  subnet_id                            = aws_subnet.public_subnet["subnet-1"].id
  associate_public_ip_address          = var.bastion_instance_settings["associate_public_ip_address"]
  source_dest_check                    = var.bastion_instance_settings["source_dest_check"]

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