# Terraform VPC with ALB and ASG
Simple terraform template that will launch a custom VPC with:
 - 2 public subnets
 - 1 public route table
 - 2 public route table associations
 - internet gateway
 - 1 private subnet
 - 1 private route table
 - 1 private route table association
 - 1 nat gateway
 - application load balancer highly available in two subnets
 - autoscaling group with a laucnh configuration and 1 target group
 - 2 listeners on the alb that forward both HTTP and HTTPS traffic to the 1 target group

There are variables set so that the template can be easily customized for each new deployment.

This is a template with no modules, and simple resources for easy customization. I built this for other just learning Terraform who needed an easy place to start and learn without the complication of modules and workspaces.
