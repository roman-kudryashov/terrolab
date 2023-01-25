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
  for_each = var.subnet_settings
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value["cidr"]
  availability_zone       = "${var.region}${each.value["az"]}"
  map_public_ip_on_launch = each.value["map_public_ip_on_launch"]

  tags = merge(
    var.default_tags,
    tomap({
      "Name"        = join("-", tolist([var.default_tags["Project"], each.key ])),
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
  for_each = var.subnet_settings
  subnet_id      = aws_subnet.public_subnet[each.key].id
  route_table_id = aws_route_table.default-public.id
}

locals {
  ec2_pool_sg = {
    ssh = {
      cidr_blocks = []
      security_groups = [aws_security_group.bastion.id]
    }
    nfs = {
      cidr_blocks = [aws_vpc.this.cidr_block]
      security_groups = []
    }
    ghost = {
      cidr_blocks = [aws_vpc.this.cidr_block]
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
      from_port        = ingress.value["from_port"]
      to_port          = ingress.value["to_port"]
      protocol         = ingress.value["protocol"]
      self             = ingress.value["self"]
      cidr_blocks      = ingress.value["cidr_blocks"]
      description      = ingress.value["description"]
    }
  }

  dynamic "egress" {
    for_each = var.bastion_sg["egress"]

    content {
      from_port        = egress.value["from_port"]
      to_port          = egress.value["to_port"]
      protocol         = egress.value["protocol"]
      self             = egress.value["self"]
      cidr_blocks      = egress.value["cidr_blocks"]
      description      = egress.value["description"]
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
      from_port        = ingress.value["from_port"]
      to_port          = ingress.value["to_port"]
      protocol         = ingress.value["protocol"]
      self             = ingress.value["self"]
      cidr_blocks      = local.ec2_pool_sg[ingress.key]["cidr_blocks"]
      security_groups  = local.ec2_pool_sg[ingress.key]["security_groups"]
      description      = ingress.value["description"]
    }
  }

  dynamic "egress" {
    for_each = var.ec2_pool_sg["egress"]

    content {
      from_port        = egress.value["from_port"]
      to_port          = egress.value["to_port"]
      protocol         = egress.value["protocol"]
      self             = egress.value["self"]
      cidr_blocks      = egress.value["cidr_blocks"]
      description      = egress.value["description"]
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
      from_port        = ingress.value["from_port"]
      to_port          = ingress.value["to_port"]
      protocol         = ingress.value["protocol"]
      self             = ingress.value["self"]
      cidr_blocks      = ingress.value["cidr_blocks"]
      description      = ingress.value["description"]
    }
  }

  dynamic "egress" {
    for_each = var.alb_sg["egress"]

    content {
      from_port        = egress.value["from_port"]
      to_port          = egress.value["to_port"]
      protocol         = egress.value["protocol"]
      self             = egress.value["self"]
      security_groups  = local.alb_sg[egress.key]["security_groups"]
      description      = egress.value["description"]
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
      from_port        = ingress.value["from_port"]
      to_port          = ingress.value["to_port"]
      protocol         = ingress.value["protocol"]
      self             = ingress.value["self"]
      security_groups  = local.efs_sg[ingress.key]["security_groups"]
      description      = ingress.value["description"]
    }
  }

  dynamic "egress" {
    for_each = var.efs_sg["egress"]

    content {
      from_port        = egress.value["from_port"]
      to_port          = egress.value["to_port"]
      protocol         = egress.value["protocol"]
      self             = egress.value["self"]
      cidr_blocks      = local.efs_sg[egress.key]["cidr_blocks"]
      description      = egress.value["description"]
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
  name  = join("-", [var.default_tags["Project"], var.iam_role["name"]])
  role  = aws_iam_role.role.name
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
