resource "aws_instance" "application" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"

  subnet_id                   = data.aws_subnet.shared.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.application.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name

  user_data = replace(
    file("${path.module}/user-data.sh.tftpl"),
    "\r\n",
    "\n"
  )

  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  credit_specification {
    cpu_credits = "standard"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name        = "lab20-terraform-application-root"
      Project     = "cloud-infrastructure-operations-lab"
      Environment = "lab"
      Lab         = "20"
      ManagedBy   = "terraform"
      Owner       = "itamarsb"
    }
  }

  tags = {
    Name = "lab20-terraform-application-instance"
  }

  depends_on = [
    aws_vpc_security_group_ingress_rule.http,
    aws_vpc_security_group_egress_rule.https
  ]
}
