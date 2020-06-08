# You must add a valid certificate arn. Once you have, everything else will deploy with default values.
variable "vpc_cidr_block" {
    type = string
    default = "10.200.0.0/16"
}
variable "public_subnet1_cidr_block" {
    type = string
    default = "10.200.0.0/24"
}
variable "public_subnet2_cidr_block" {
    type = string
    default = "10.200.1.0/24"
}
variable "private_subnet1_cidr_block" {
    type = string
    default = "10.200.2.0/24"
}
variable "app_name" {
    type = string
    default = "hello_world"
}
variable "image_id" {
    type = string
    default = "ami-0e34e7b9ca0ace12d"
}
variable "instance_type" {
    type = string
    default = "t2.micro"
}
variable "asg_max_size" {
    type = number
    default = 3
}
variable "asg_min_size" {
    type = number
    default = 1
}
variable "asg_desired_count" {
    type = number
    default = 2
}
variable "cert_arn" {
    type = string
    default = "arn:aws:acm:aws-region:aws-account-id:certificate/certificatenumber"
}