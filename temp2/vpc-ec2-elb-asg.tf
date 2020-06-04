provider "aws" {
  profile    = "kiasandbox"
  region     = "us-west-2"
}

resource "aws_vpc" "terraform" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "terraform"
  }
}

resource "aws_subnet" "tf-public-1" {
  availability_zone = "us-west-2a"
  vpc_id     = aws_vpc.terraform.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "tf-public-subnet-1"
  }
}

resource "aws_subnet" "tf-public-2" {
  availability_zone = "us-west-2b"
  vpc_id     = aws_vpc.terraform.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "tf-public-subnet-2"
  }
}

resource "aws_subnet" "tf-private-1" {
  availability_zone = "us-west-2a"
  vpc_id     = aws_vpc.terraform.id
  cidr_block = "10.0.3.0/24"

  tags = {
    Name = "tf-private-subnet-1"
  }
}

//resource "aws_subnet" "tf-private-2" {
//  availability_zone = "us-west-2b"
//  vpc_id     = aws_vpc.terraform.id
//  cidr_block = "10.0.4.0/24"
//
//  tags = {
//    Name = "tf-private-subnet-2"
//  }
//}

resource "aws_internet_gateway" "terraform-ig" {
  vpc_id = aws_vpc.terraform.id

  tags = {
    Name = "terraform-ig"
  }
}

resource "aws_route_table" "terraform-rt" {
  vpc_id = aws_vpc.terraform.id
  
    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.terraform-ig.id
    }
}

resource "aws_route_table_association" "rta-subnet-public-1" {
  subnet_id      = aws_subnet.tf-public-1.id
  route_table_id = aws_route_table.terraform-rt.id
}

resource "aws_route_table_association" "rta-subnet-public-2" {
  subnet_id      = aws_subnet.tf-public-2.id
  route_table_id = aws_route_table.terraform-rt.id
}

resource "aws_security_group" "terraform-alb-sg" {
  name        = "terraform-alb-sg"
  description = "Allow internet traffic"
  vpc_id      = aws_vpc.terraform.id

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
    Name = "allow-internet-traffic"
  }
}

resource "aws_security_group" "terraform-ec2-sg" {
  name        = "ec2_sg"
  description = "Allow traffic from alb"
  vpc_id      = aws_vpc.terraform.id

  ingress {
    description = "access 80 from alb"
    security_groups = [aws_security_group.terraform-alb-sg.id]
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
  }

    ingress {
    description = "access 443 from alb"
    security_groups = [aws_security_group.terraform-alb-sg.id]
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
    Name = "traffic-from-alb"
  }
}

resource "aws_launch_configuration" "tf-lc" {
  name          = "tf-lc"
  image_id      = "ami-0e34e7b9ca0ace12d"
  instance_type = "t2.micro"
}

//resource "aws_iam_role" "tf-asg-all-access" {
//  name = "asg-all-access"
//  assume_role_policy = <<EOF
//{
//  "Version": "2012-10-17",
//  "Statement": [
//    {
//      "Sid": "",
//      "Effect": "Allow",
//      "Principal": {
//        "Service": [
//          "ec2.amazonaws.com"
//        ]
//      },
//      "Action": "sts:AssumeRole"
//    }
//  ]
//}
//EOF
//}
//
//resource "aws_iam_role_policy_attachment" "asg-all-access-policy-attachment" {
//    role = aws_iam_role.tf-asg-all-access.name
//    policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AutoScalingServiceRolePolicy"
//}

resource "aws_autoscaling_group" "tf-asg" {
  name                      = "tf-asg"
  max_size                  = 2
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = true
  launch_configuration      = aws_launch_configuration.tf-lc.name
  target_group_arns         = [aws_lb_target_group.terraform-tg-1.arn]
  vpc_zone_identifier       = [aws_subnet.tf-private-1.id]

//  initial_lifecycle_hook {
//    name                 = "tf-lch"
//    default_result       = "CONTINUE"
//    heartbeat_timeout    = 2000
//    lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
////    role_arn = aws_iam_role.tf-asg-all-access.arn
////    notification_target_arn = ""
//  }

  timeouts {
    delete = "15m"
  }
}

resource "aws_lb_target_group" "terraform-tg-1" {
  name     = "ec2-tg-1"
  port     = 443
  protocol = "HTTP"
  vpc_id   = aws_vpc.terraform.id
  target_type = "instance"
}

resource "aws_lb" "tf-ec2-alb" {
  name               = "tf-ec2-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.terraform-alb-sg.id]
  subnets            = [aws_subnet.tf-public-1.id, aws_subnet.tf-public-2.id]

  enable_deletion_protection = false

  tags = {
    Name = "tf-ec2-alb"
  }
}

resource "aws_lb_listener" "tf-tg-ec2-1-listener-443" {
  load_balancer_arn = aws_lb.tf-ec2-alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:us-west-2:266245855374:certificate/0a78e678-e87c-43e6-a2f7-443a54aa8703"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.terraform-tg-1.arn
  }
}

resource "aws_lb_listener" "tf-tg-ec2-1-listener-80" {
  load_balancer_arn = aws_lb.tf-ec2-alb.arn
  port              = "80"
  protocol          = "HTTP"
//  certificate_arn   = "arn:aws:acm:us-west-2:266245855374:certificate/0a78e678-e87c-43e6-a2f7-443a54aa8703"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.terraform-tg-1.arn
  }
}

