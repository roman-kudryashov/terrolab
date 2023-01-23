variable "region" {
  default = "us-east-1"
}

variable "default_tags" {
  default = {
    "Project" = "terraform_lab"
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
