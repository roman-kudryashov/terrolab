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