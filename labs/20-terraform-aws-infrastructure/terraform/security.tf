resource "aws_security_group" "application" {
  name        = "lab20-terraform-application-sg"
  description = "HTTP restrito e saida HTTPS para a instancia do LAB 20."
  vpc_id      = data.aws_vpc.shared.id

  tags = {
    Name = "lab20-terraform-application-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.application.id
  description       = "HTTP permitido somente para o IPv4 autorizado."

  cidr_ipv4   = var.allowed_http_cidr
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80

  tags = {
    Name = "lab20-http-ingress"
  }
}

resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.application.id
  description       = "HTTPS para repositorios de pacotes e AWS Systems Manager."

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443

  tags = {
    Name = "lab20-https-egress"
  }
}
