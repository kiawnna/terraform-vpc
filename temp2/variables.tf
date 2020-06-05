variable "vpc_cidr_block" {
    type = string
}
variable "public_subnet1_cidr_block" {
    type = string
}
variable "public_subnet2_cidr_block" {
    type = string
}
variable "private_subnet1_cidr_block" {
    type = string
}
variable "app_name" {
    type = string
}
variable "image_id" {
    type = string
}
variable "instance_type" {
    type = string
}
variable "asg_max_size" {
    type = number
}
variable "asg_min_size" {
    type = number
}
variable "asg_desired_count" {
    type = number
}