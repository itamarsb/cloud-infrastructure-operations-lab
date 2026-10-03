resource "aws_iam_role" "ec2" {
  name        = "lab20-ec2-terraform-role"
  description = "Role da instancia EC2 do LAB 20 para AWS Systems Manager."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "lab20-ec2-terraform-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "lab20-ec2-terraform-instance-profile"
  role = aws_iam_role.ec2.name

  tags = {
    Name = "lab20-ec2-terraform-instance-profile"
  }

  depends_on = [
    aws_iam_role_policy_attachment.ssm
  ]
}
