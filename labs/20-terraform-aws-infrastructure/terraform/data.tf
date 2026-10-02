data "aws_caller_identity" "current" {}

data "aws_vpc" "shared" {
  id = var.shared_vpc_id

  filter {
    name   = "tag:Name"
    values = ["lab08-application-vpc"]
  }

  filter {
    name   = "tag:Project"
    values = ["cloud-infrastructure-operations-lab"]
  }

  filter {
    name   = "tag:Lab"
    values = ["08"]
  }

  lifecycle {
    postcondition {
      condition     = self.owner_id == var.expected_account_id
      error_message = "A VPC compartilhada nao pertence a conta esperada."
    }

    postcondition {
      condition     = self.enable_dns_support && self.enable_dns_hostnames
      error_message = "A VPC compartilhada deve ter suporte DNS e hostnames DNS habilitados."
    }
  }
}

data "aws_subnet" "shared" {
  id = var.shared_subnet_id

  filter {
    name   = "tag:Name"
    values = ["lab08-public-subnet-a"]
  }

  filter {
    name   = "tag:Project"
    values = ["cloud-infrastructure-operations-lab"]
  }

  filter {
    name   = "tag:Lab"
    values = ["08"]
  }

  lifecycle {
    postcondition {
      condition     = self.vpc_id == data.aws_vpc.shared.id
      error_message = "A sub-rede informada nao pertence a VPC compartilhada selecionada."
    }

    postcondition {
      condition     = self.owner_id == var.expected_account_id
      error_message = "A sub-rede compartilhada nao pertence a conta esperada."
    }

    postcondition {
      condition     = self.state == "available"
      error_message = "A sub-rede compartilhada nao esta disponivel."
    }
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "image-type"
    values = ["machine"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
