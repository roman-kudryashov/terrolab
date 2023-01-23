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