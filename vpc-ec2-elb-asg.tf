# All variables should be specified in variables.tf, otherwise defaults will be used.
# The exception is the variable cert_arn, which MUST be updated in order for this solutions to deploy.

# Virtual private cloud with custom cidr block.
resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr_block
  instance_tenancy = "default"

  tags = {
    Name = "${var.app_name}-vpc"
  }
}

# Internet gateway attached to VPC.
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.app_name}-ig"
  }
}

# Public subnet 1.
resource "aws_subnet" "public-1" {
  availability_zone = "us-west-2a"
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet1_cidr_block

  tags = {
    Name = "${var.app_name}-publicsubnet-1"
  }
}

# Public subnet 2.
resource "aws_subnet" "public-2" {
  availability_zone = "us-west-2b"
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet2_cidr_block

  tags = {
    Name = "${var.app_name}-publicsubnet-2"
  }
}

# Public route table.
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.main.id

    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.ig.id
    }
    tags = {
        Name = "${var.app_name}-public-rt"
    }
}

# Public route table association between public-subnet-1 and the public route table.
resource "aws_route_table_association" "rta-public-1" {
  subnet_id      = aws_subnet.public-1.id
  route_table_id = aws_route_table.public-rt.id
}

# Public route table association between public-subnet-2 and the public route table.
resource "aws_route_table_association" "rta-public-2" {
  subnet_id      = aws_subnet.public-2.id
  route_table_id = aws_route_table.public-rt.id
}

# Allocates an EIP to the nat gateway.
resource "aws_eip" "nat" {
    vpc      = true
}

# Nat gateway set up in public-subnet-1.
resource "aws_nat_gateway" "gw" {
    allocation_id = aws_eip.nat.id
    subnet_id     = aws_subnet.public-1.id
    tags = {
        Name = "${var.app_name}-nat-gateway"
    }
}

# Private subnet.
resource "aws_subnet" "private-1" {
  availability_zone = "us-west-2a"
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet1_cidr_block

  tags = {
    Name = "${var.app_name}-privatesubnet-1"
  }
}

# Private route table which routes to the nat gateway in public-subnet-1.
resource "aws_route_table" "private-rt" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_nat_gateway.gw.id
    }
    tags = {
        Name = "${var.app_name}-private-rt"
    }
}

# Associates the private subnet with the private route table.
resource "aws_route_table_association" "rta-private-1" {
    subnet_id      = aws_subnet.private-1.id
    route_table_id = aws_route_table.private-rt.id
}

# Security group for a load balancer.
resource "aws_security_group" "alb-sg" {
  name        = "alb-sg"
  description = "Allow internet traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "http access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    description = "https access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-alb-sg"
  }
}

# Security group for EC2 instances/application/microservice.
resource "aws_security_group" "ec2-sg" {
  name        = "ec2-sg"
  description = "Allow traffic from alb"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "access 80 from alb"
    security_groups = [aws_security_group.alb-sg.id]
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
  }

    ingress {
    description = "access 443 from alb"
    security_groups = [aws_security_group.alb-sg.id]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-ec2-sg"
  }
}

# Launch configuration for the ASG.
resource "aws_launch_configuration" "launchconfig" {
  name          = "${var.app_name}-lc"
  image_id      = var.image_id
  instance_type = var.instance_type
}

resource "aws_autoscaling_group" "tf-asg" {
  name                      = "${var.app_name}-asg"
  max_size                  = var.asg_max_size
  min_size                  = var.asg_min_size
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = var.asg_desired_count
  force_delete              = true
  launch_configuration      = aws_launch_configuration.launchconfig.name
  target_group_arns         = [aws_lb_target_group.tg-1.arn]
  vpc_zone_identifier       = [aws_subnet.private-1.id]

  timeouts {
    delete = "15m"
  }
}

# Target group for an ASG that the ALB forwards traffic (over ports 8 and 443) to.
resource "aws_lb_target_group" "tg-1" {
  name     = "tg-1"
  port     = 443
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "instance"

  tags = {
    Name = "${var.app_name}-alb"
  }
}

# Application load balancer resource, highly available in two public subnets, secured with its own security group.
resource "aws_lb" "alb" {
  name               = "alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb-sg.id]
  subnets            = [aws_subnet.public-1.id, aws_subnet.public-2.id]

  enable_deletion_protection = false

  tags = {
    Name = "${var.app_name}-alb"
  }
}

## Listener for the ALB that forwards port 443 traffic to target group 1.
#resource "aws_lb_listener" "listener-443" {
#  load_balancer_arn = aws_lb.alb.arn
#  port              = "443"
#  protocol          = "HTTPS"
#  ssl_policy        = "ELBSecurityPolicy-2016-08"
#  certificate_arn   = var.cert_arn

#  default_action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.tg-1.arn
#  }
#}

# Listener for the ALB that forwards port 80 traffic to target group 1.
resource "aws_lb_listener" "listener-80" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-1.arn
  }
}

