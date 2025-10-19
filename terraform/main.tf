resource "aws_security_group" "test_sg" {
    name = "test_sg"
    description = "Security group for the EC2 Instance"

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_key_pair" "deployer_key" {
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDS05RiC3iwF5ISZkuPbivKH8IifYyve5TXKPnlKDvpv4hd9+9gCqmCi7Hn40dgNzyfo0URaCVFVBDR9jmelRfgsQQ5qIcqX3Mam9xnmWufMjriji2v+N5qT8FONk4paHj4di3dzrV5Vb1rMUybOU4rIA+mhCezjsbShMtvsVGTOxJTol65UZn5SsrKcBsTgxvzAmEnm95hVOcFvz4QooxNwAFMjkFMaq0/9HpOFbvBjsDuDp7QH4eDgLTnINAfP4PWpeuBtoMXXLdspLw/RskNW/fds3/ivFMlaBLkTiN3MC3mUNMau4iTeCY7BfLtKsIhId1AznyMJXOIDKz+9SxSZl/yKgJwtXqpSXnt75fCIkbXxGacIru0Hd0jAwWx8ZVYF6zYjdY+uZ9epSQCgTGBBV8aXivltvnvUykCPX5zj4tGdJYq0Fgh2YK/BKzSUfQvuzui9uzk8Sc7uzLQ8dkkH1LaherfNx6u2iKETO/vBLiUmha9UXz4914t6+y5z9wNrAwkA825IP0DuFA5ccAGAs0q1vrkNmmIdHhlmhrnrPeW6w6Ifh/UifZWjfU8+0hx8paeRTnCcd/snnVpb8EZIH6F+D5Pc+bKS5wPOy7/GpKR5EK9CMs5zWA6saNxaItZoIEbClLMBSnduVFqx9/uG4+mCo/Lt7+WiXBi28Ua8w== nikhi@Nikhil"
}

resource "aws_iam_role" "ec2_role" {
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "ec2.amazonaws.com"
                }
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "ecr_read_only_policy" {
    role = aws_iam_role.ec2_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ecr_ec2_profile" {
    name = "ecr_ec2_profile"
    role = aws_iam_role.ec2_role.name
}

resource "aws_instance" "ec2_instance" {
    ami = var.ami_id
    instance_type = var.type
    iam_instance_profile = aws_iam_instance_profile.ecr_ec2_profile.name
    key_name = aws_key_pair.deployer_key.key_name
    vpc_security_group_ids = [aws_security_group.test_sg.id]
    
    user_data = <<-EOT
              #!/bin/bash
              # Update all packages
              sudo dnf update -y
              # Install Docker and the AWS CLI
              sudo dnf install -y docker aws-cli
              # Start and enable the Docker service
              sudo systemctl start docker
              sudo systemctl enable docker
              # Add the default user to the docker group
              sudo usermod -a -G docker ec2-user
    EOT
    
    tags = {
        Name = "Test_EC2_Instance"
    }

}

resource "aws_ecr_repository" "app_repo" {
    name = "devops_ci_cd_final_prac_5"
    image_tag_mutability = "MUTABLE"
    force_delete = true
}