data "aws_iam_policy_document" "role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "fargate-role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "policy" {
  statement {
    sid    = "1"
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "elasticfilesystem:DescribeFileSystems",
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite",
      "ssm:GetParameter*",
      "secretsmanager:GetSecretValue",
      "kms:Decrypt"

    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "fargate-policy" {
  statement {
    sid    = "1"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "elasticfilesystem:DescribeFileSystems",
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite"
    ]
    resources = ["*"]
  }
}

data "aws_ami" "amazon-linux-2" {
  most_recent = var.ami_settings["most_recent"]
  name_regex  = var.ami_settings["name_regex"]
  owners      = var.ami_settings["owners"]

  filter {
    name   = "root-device-type"
    values = var.ami_settings["root-device-type"]
  }
  filter {
    name   = "virtualization-type"
    values = var.ami_settings["virtualization-type"]
  }
}

data "template_file" "user-data" {
  template = file("templates/user-data.sh")

  vars = {
    alb_url         = aws_lb.loadbalancer.dns_name
    efs_id          = aws_efs_file_system.efs.id
    region          = var.region
    db_url          = aws_db_instance.rds.address
    db_user         = var.rds_settings["username"]
    db_name         = var.rds_settings["dbname"]
    ssm_db_password = aws_ssm_parameter.secret.name
  }
}

data "aws_vpc_endpoint_service" "vpc_endpoint_service" {

  for_each = try(var.vpc_endpoint_settings["endpoints"], {})

  service      = lookup(each.value, "service", null)
  service_type = lookup(each.value, "service_type", null)

}

