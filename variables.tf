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
      self             = true
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