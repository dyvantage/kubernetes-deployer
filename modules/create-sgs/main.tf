resource "aws_security_group" "allow_all_internal" {
  name        = "allow_all_internal"
  description = "Allow all traffic within the VPC"
  vpc_id      = var.target_vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.target_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.target_vpc_cidr]
  }

  tags = {
    Name = "allow_all_internal"
  }
}

resource "aws_security_group" "allow_inbound_ssh" {
  name        = "allow_inbound_ssh"
  description = "Allow inbound SSH traffic"
  vpc_id      = var.target_vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_inbound_ssh"
  }
}

resource "aws_security_group" "allow_inbound_6443" {
  name        = "allow_inbound_6443"
  description = "Allow inbound TCP-6443 traffic"
  vpc_id      = var.target_vpc_id

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_inbound_6443"
  }
}

resource "aws_security_group" "allow_inbound_icmp" {
  name        = "allow_inbound_icmp"
  description = "Allow inbound ICMP traffic"
  vpc_id      = var.target_vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_inbound_icmp"
  }
}

resource "aws_security_group" "allow_all_outbound" {
  name        = "allow_all_outbound"
  description = "Allow all outbound traffic"
  vpc_id      = var.target_vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_all_outbound"
  }
}

# define outputs
output "sg_ids" {
  value = [
	aws_security_group.allow_all_internal.id,
	aws_security_group.allow_inbound_ssh.id,
	aws_security_group.allow_inbound_6443.id,
	aws_security_group.allow_inbound_icmp.id,
	aws_security_group.allow_all_outbound.id,
  ]
}
