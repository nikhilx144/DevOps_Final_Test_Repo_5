variable "region" {
    description = "AWS Region"
    type = string
}

variable "ami_id" {
    description = "ID of the AMI for the EC2 Instance"
    type = string
}

variable "type" {
    description = "EC2 Instance Type"
    type = string
}