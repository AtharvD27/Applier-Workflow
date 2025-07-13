provider "aws" {
  region = var.region
}

data "template_file" "user_data" {
  template = file("${path.module}/cloud-init.sh")
}

data "aws_security_group" "launch_sg" {
  id = var.security_group_id
}

# -----------------  LOOK UP THE EXISTING EIP  -----------------
data "aws_eip" "static" {
  filter {
    name   = "allocation-id"
    values = [var.eip_allocation_id]
  }
}

# -----------------  SPOT INSTANCE  -----------------
resource "aws_instance" "linkedln_vm" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [data.aws_security_group.launch_sg.id]
  associate_public_ip_address = true

  instance_market_options {
    market_type = "spot"
    spot_options {
      spot_instance_type             = "one-time"
      instance_interruption_behavior = "terminate"
    }
  }

  user_data  = data.template_file.user_data.rendered
  monitoring = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.volume_size
    delete_on_termination = true
  }

  tags = {
    Name = "LinkedIn-Spot-VM"
  }
}

# -----------------  ASSOCIATE EIP WITH NEW VM  -----------------
resource "aws_eip_association" "attach_eip" {
  allocation_id = data.aws_eip.static.id
  instance_id   = aws_instance.linkedln_vm.id
}

# -----------------  OUTPUTS  -----------------
output "instance_id" {
  value = aws_instance.linkedln_vm.id
}

output "public_ip" {
  value = aws_instance.linkedln_vm.public_ip
}
