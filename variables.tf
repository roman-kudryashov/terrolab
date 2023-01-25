variable "region" {
  default = "us-east-1"
}

variable "default_tags" {
  default = {
    "Project" = "terraform-lab"
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
      az = "a"
      cidr = "10.10.1.0/24"
      map_public_ip_on_launch = true
    }
    subnet-2 = {
      az = "b"
      cidr = "10.10.2.0/24"
      map_public_ip_on_launch = true
    }
    subnet-3 = {
      az = "c"
      cidr = "10.10.3.0/24"
      map_public_ip_on_launch = true
    }
  }
}

variable "bastion_sg" {
  default = {
    name = "bastion"
    ingress = {
    ssh = {
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      self             = false
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "Inbound ssh traffic"
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

variable "alb_sg" {
  default = {
    name = "alb"
    ingress = {
      http = {
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      self             = false
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "Inbound http traffic"
    }
  }
  egress = {
    global = {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      self             = false
      cidr_blocks      = []
      description      = "Outbound traffic"
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
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      self             = false
      cidr_blocks      = []
      description      = "Inbound ssh traffic"
    }
      nfs = {
      from_port        = 2049
      to_port          = 2049
      protocol         = "tcp"
      self             = false
      cidr_blocks      = []
      description      = "Inbound nfs traffic"
    }
      ghost = {
      from_port        = 2368
      to_port          = 2368
      protocol         = "tcp"
      self             = false
      cidr_blocks      = []
      description      = "Inbound ghost traffic"
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
      from_port        = 2049
      to_port          = 2049
      protocol         = "tcp"
      self             = false
      cidr_blocks      = []
      description      = "Inbound nfs traffic"
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

variable "key_pair" {
  default = {
    name = "ghost-ec2-pool"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDCVtiwVs+Q4/XpjcHggbruL5pqYlTUo4kv+kdpFFngysFmeaM+BBH6ii1ZZPQP8TCMGxrI8CEAtP+sBrOfotxoiwb1oC7Pik6r6Q89MhX9elTF4Tp6rx2CocdPiInkV01rHxcfLOghmEcmYi4BFHgKJLZH0AU5PJvTLfuQENcdfPUbFpm2WliJvSgDjsnFHh8O889p0eG20OsdsosgLTJWDRX4/ER2wh++s4MvmYI94q8fdSiBhYBibcvJc4BvHNiSps4JpMIaL9uUjorXZnYVgrxuNNXHI7e6w1bMBguqWsGXVeKILha+mRi4wcMorMI0VzaJRmwdwzH9LkVhTTWD6SrwBSfWusX6mQ6VmHndTczDaHaV1ciJ72gF5w0XSf0eB2EdEMZ7+WDe7BkulGGeu5GVODnsAFagRL3skLemoSwpIH/BtcojlJT5Tz8OYA55tJjdq4t3LlFeEVsCgAjWCNJ0AvWBPc4o/NI+s/OKdt6BCzwJFOJpHgtIfrUosNvqhYCmdJWpfCsTqGr4GosT5nlQanSEUOtbWcfKmz+r72IpzyvfrNyyurFq3Mw1m6Jc4R5ZWFeZ1UiGgzAtFAeek895mwQ9oMJEoJ/vhRhT7hrp5wSpgvS59+/+m25zSX3lQh/uHHDx02EylO6PjqFaW9d38xASIPHmVaFA8vWNqw== boris_kamenetskii@epam.com"
  }
}

variable "iam_role" {
  default = {
    name = "ghost_app"
    role_description = "EC2 main role"
    policy_description = "EC2 main policy"
  }
}