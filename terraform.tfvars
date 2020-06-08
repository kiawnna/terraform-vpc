vpc_cidr_block = "10.200.0.0/16"
public_subnet1_cidr_block = "10.200.0.0/24"
public_subnet2_cidr_block = "10.200.1.0/24"
private_subnet1_cidr_block = "10.200.2.0/24"
app_name = "bestappever"
image_id = "ami-0e34e7b9ca0ace12d"
instance_type = "t2.micro"
asg_max_size = 5
asg_min_size = 1
asg_desired_count = 2