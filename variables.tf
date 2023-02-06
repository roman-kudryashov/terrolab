variable "region" {
  default = "us-east-1"
}

variable "default_tags" {
  default = {
    "Project"    = "terraform-lab"
    "Managed_by" = "terraform"
  }
}

variable "vpc_cidr" {
  default = "10.10.0.0/16"
}

variable "vpc_instance_tenancy" {
  default = "default"
}

variable "vpc_enable_dns_support" {
  default = true
}

variable "vpc_enable_dns_hostnames" {
  default = true
}

variable "vpc_enable_classiclink" {
  default = false
}

variable "subnet_settings" {
  default = {
    subnet-1 = {
      az                      = "a"
      cidr                    = "10.10.1.0/24"
      map_public_ip_on_launch = true
    }
    subnet-2 = {
      az                      = "b"
      cidr                    = "10.10.2.0/24"
      map_public_ip_on_launch = true
    }
    subnet-3 = {
      az                      = "c"
      cidr                    = "10.10.3.0/24"
      map_public_ip_on_launch = true
    }
  }
}

variable "private_subnet_settings" {
  default = {
    subnet-1 = {
      az                      = "a"
      cidr                    = "10.10.4.0/24"
      map_public_ip_on_launch = false
    }
    subnet-2 = {
      az                      = "b"
      cidr                    = "10.10.5.0/24"
      map_public_ip_on_launch = false
    }
    subnet-3 = {
      az                      = "c"
      cidr                    = "10.10.6.0/24"
      map_public_ip_on_launch = false
    }
  }
}

variable "bastion_sg" {
  default = {
    name = "bastion"
    ingress = {
      ssh = {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        self        = false
        cidr_blocks = ["0.0.0.0/0"]
        description = "Inbound ssh traffic"
      }
    }
    egress = {
      global = {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        self             = false
        security_groups  = []
        prefix_list_ids  = []
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = []
        description      = "Outbound traffic"
      }
    }
    tags = {
      "Description" = "allows access to bastion"
    }
  }
}

variable "endpoint_sg" {
  default = {
    name = "endpoint"
    ingress = {
      ssh = {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        self        = false
        cidr_blocks = ["0.0.0.0/0"]
        description = "Inbound ssh traffic"
      }
    }
    egress = {
      global = {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        self             = false
        security_groups  = []
        prefix_list_ids  = []
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = []
        description      = "Outbound traffic"
      }
    }
    tags = {
      "Description" = "allows access to endpoint"
    }
  }
}

variable "alb_sg" {
  default = {
    name = "alb"
    ingress = {
      http = {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        self        = false
        cidr_blocks = ["0.0.0.0/0"]
        description = "Inbound http traffic"
      }
    }
    egress = {
      global = {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        self        = false
        cidr_blocks = []
        description = "Outbound traffic"
      }
    }
    tags = {
      "Description" = "allows access to alb"
    }
  }
}

variable "ec2_pool_sg" {
  default = {
    name = "ec2_pool"
    ingress = {
      ssh = {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        self        = false
        cidr_blocks = []
        description = "Inbound ssh traffic"
      }
      nfs = {
        from_port   = 2049
        to_port     = 2049
        protocol    = "tcp"
        self        = false
        cidr_blocks = []
        description = "Inbound nfs traffic"
      }
      ghost = {
        from_port   = 2368
        to_port     = 2368
        protocol    = "tcp"
        self        = false
        cidr_blocks = []
        description = "Inbound ghost traffic"
      }
    }
    egress = {
      global = {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        self             = false
        security_groups  = []
        prefix_list_ids  = []
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = []
        description      = "Outbound traffic"
      }
    }
    tags = {
      "Description" = "allows access to ec2 instances"
    }
  }
}

variable "efs_sg" {
  default = {
    name = "efs"
    ingress = {
      nfs = {
        from_port   = 2049
        to_port     = 2049
        protocol    = "tcp"
        self        = false
        cidr_blocks = []
        description = "Inbound nfs traffic"
      }
    }
    egress = {
      global = {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        self             = false
        security_groups  = []
        prefix_list_ids  = []
        cidr_blocks      = []
        ipv6_cidr_blocks = []
        description      = "Outbound traffic"
      }
    }
    tags = {
      "Description" = "defines access to efs mount points"
    }
  }
}

variable "fargate_sg" {
  default = {
    name = "fargate"
    ingress = {
      nfs = {
        from_port   = 2049
        to_port     = 2049
        protocol    = "tcp"
        self        = false
        cidr_blocks = []
        description = "Inbound nfs traffic"
      }
      ghost = {
        from_port   = 2368
        to_port     = 2368
        protocol    = "tcp"
        self        = false
        cidr_blocks = []
        description = "Inbound ghost traffic"
      }
    }
    egress = {
      global = {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        self             = false
        security_groups  = []
        prefix_list_ids  = []
        cidr_blocks      = []
        ipv6_cidr_blocks = []
        description      = "Outbound traffic"
      }
    }
    tags = {
      "Description" = "defines access to Fargate container"
    }
  }
}

variable "key_pair" {
  default = {
    name       = "ghost-ec2-pool"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDCVtiwVs+Q4/XpjcHggbruL5pqYlTUo4kv+kdpFFngysFmeaM+BBH6ii1ZZPQP8TCMGxrI8CEAtP+sBrOfotxoiwb1oC7Pik6r6Q89MhX9elTF4Tp6rx2CocdPiInkV01rHxcfLOghmEcmYi4BFHgKJLZH0AU5PJvTLfuQENcdfPUbFpm2WliJvSgDjsnFHh8O889p0eG20OsdsosgLTJWDRX4/ER2wh++s4MvmYI94q8fdSiBhYBibcvJc4BvHNiSps4JpMIaL9uUjorXZnYVgrxuNNXHI7e6w1bMBguqWsGXVeKILha+mRi4wcMorMI0VzaJRmwdwzH9LkVhTTWD6SrwBSfWusX6mQ6VmHndTczDaHaV1ciJ72gF5w0XSf0eB2EdEMZ7+WDe7BkulGGeu5GVODnsAFagRL3skLemoSwpIH/BtcojlJT5Tz8OYA55tJjdq4t3LlFeEVsCgAjWCNJ0AvWBPc4o/NI+s/OKdt6BCzwJFOJpHgtIfrUosNvqhYCmdJWpfCsTqGr4GosT5nlQanSEUOtbWcfKmz+r72IpzyvfrNyyurFq3Mw1m6Jc4R5ZWFeZ1UiGgzAtFAeek895mwQ9oMJEoJ/vhRhT7hrp5wSpgvS59+/+m25zSX3lQh/uHHDx02EylO6PjqFaW9d38xASIPHmVaFA8vWNqw== boris_kamenetskii@epam.com"
  }
}

variable "iam_role" {
  default = {
    name               = "ghost_app"
    role_description   = "EC2 main role"
    policy_description = "EC2 main policy"
  }
}

variable "fargate_iam_role" {
  default = {
    name               = "fargate_ghost_app"
    role_description   = "ECS main role"
    policy_description = "ECS main policy"
  }
}


variable "efs_settings" {
  default = {
    name_prefix      = "ghost_content"
    lifecycle_policy = "AFTER_14_DAYS"
    encrypted        = false
    performance_mode = "generalPurpose"
    throughput_mode  = "bursting"

    additional_tags = {
      Description = "ghost_content."
      Purpose     = "Ghost storage."
    }
  }
}

variable "lb_settings" {
  default = {
    name                             = "ghost-alb"
    load_balancer_type               = "application"
    internal                         = false
    enable_deletion_protection       = false
    enable_cross_zone_load_balancing = true
    enable_http2                     = false
    idle_timeout                     = "300"

    access_logs = {
      enabled = false
    }

  }
}

variable "listeners_settings" {
  default = {
    port       = 80
    protocol   = "HTTP"
    ssl_policy = false
    type       = "forward"
  }
}

variable "tg_settings" {
  default = {
    name                             = "ghost-tg"
    target_type                      = "instance"
    port                             = 2368
    protocol                         = "HTTP"
    deregistration_delay             = 300
    slow_start                       = 0
    proxy_protocol_v2                = false
    health_check_port                = 2368
    health_check_protocol            = "HTTP"
    health_check_healthy_threshold   = 2
    health_check_unhealthy_threshold = 2
    health_check_interval            = 30
    health_check_path                = "/ghost/"
    health_check_matcher             = "200"
  }
}

variable "ami_settings" {
  default = {
    name_regex          = "amzn2-ami-kernel-5.10-hvm-2.0.20230119.1-x86_64-gp2"
    most_recent         = true
    owners              = ["137112412989"]
    root-device-type    = ["ebs"]
    virtualization-type = ["hvm"]
  }
}

variable "ghost_instance_settings" {
  default = {
    name                    = "ghost"
    disable_api_termination = false
    instance_type           = "t2.micro"
    ebs_block_device = {
      "/dev/xvda" = {
        volume_type           = "gp2"
        volume_size           = "8"
        delete_on_termination = true
      }
    }
  }
}

variable "asg_settings" {
  default = {
    name                      = "ghost"
    min_size                  = 1
    desired_capacity          = 1
    max_size                  = 1
    load_balancer             = true
    health_check_type         = "ELB"
    health_check_grace_period = 300
    default_cooldown          = 450
    create_before_destroy     = true
    version                   = "$Latest"
  }
}

variable "bastion_instance_settings" {
  default = {
    name                        = "bastion"
    disable_api_termination     = false
    associate_public_ip_address = true
    instance_type               = "t2.micro"
    source_dest_check           = true
    ebs_block_device = {
      root = {
        volume_type           = "gp2"
        volume_size           = "8"
        delete_on_termination = true
      }
    }
  }
}

variable "rds_settings" {
  default = {
    name                    = "ghost"
    dbname                  = "ghost_db"
    allocated_storage       = "20"
    storage_type            = "gp2"
    engine                  = "mariadb"
    availability_zone       = "us-east-1a"
    engine_version          = "10.3.36"
    instance_class          = "db.t3.micro"
    username                = "ghost_user"
    storage_encrypted       = true
    skip_final_snapshot     = true
    backup_retention_period = 35
    backup_window           = "09:54-10:24"
    family                  = "mariadb10.3"

  }
}

variable "rds_sg" {
  default = {
    name = "rds"
    ingress = {
      mysql = {
        from_port   = 3306
        to_port     = 3306
        protocol    = "tcp"
        self        = false
        cidr_blocks = []
        description = "Inbound Mysql traffic"
      }
    }
    egress = {
    }
    tags = {
      "Description" = "allows access to RDS instances"
    }
  }
}

variable "ecr_settings"  {
  default = {
    name = "ghost"
        image_tag_mutability = "MUTABLE"
    scan_on_push         = false
  }
}


variable "vpc_endpoint_settings" {
  default = {
    endpoints = {
      s3 = {
        service = "s3"
        service_type = "Interface"
      }
      ecr_dkr = {
        service = "ecr.dkr"
        service_type = "Interface"
      }
      ecr_api = {
        service = "ecr.api"
        service_type = "Interface"
      }
      efs = {
        service = "elasticfilesystem"
        service_type = "Interface"
      }
      ssm = {
        service = "ssm"
        service_type = "Interface"
      }
      cloudwatch = {
        service = "monitoring"
        service_type = "Interface"
      }
      cloudwatch_logs = {
        service = "logs"
        service_type = "Interface"
      }
    }
  }
}