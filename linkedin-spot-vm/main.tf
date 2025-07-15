provider "aws" {
  region = var.region
}

data "template_file" "user_data" {
  template = file("${path.module}/cloud-init.sh")
}

data "aws_security_group" "launch_sg" {
  id = var.security_group_id
}

# Look up the existing EIP
data "aws_eip" "static" {
  filter {
    name   = "allocation-id"
    values = [var.eip_allocation_id]
  }
}

# Look up the pre-configured browser volume
data "aws_ebs_volume" "browser_data" {
  filter {
    name   = "volume-id"
    values = [var.browser_volume_id]
  }
}

# Main spot instance configuration
resource "aws_instance" "linkedln_vm" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [data.aws_security_group.launch_sg.id]
  associate_public_ip_address = true

  # Spot configuration
  instance_market_options {
    market_type = "spot"
    spot_options {
      spot_instance_type             = "one-time"
      instance_interruption_behavior = "terminate"
      max_price                      = "0.10"
    }
  }

  user_data  = data.template_file.user_data.rendered
  monitoring = true

  # Root volume - reduced size since browsers are on separate volume
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.volume_size
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
    encrypted             = false
  }

  # Enable EBS optimization
  ebs_optimized = true

  tags = {
    Name        = "LinkedIn-Spot-VM"
    Purpose     = "Automation"
    Environment = "Production"
  }
}

# Attach the pre-configured browser volume
resource "aws_volume_attachment" "browser_data" {
  device_name = "/dev/xvdf"
  volume_id   = data.aws_ebs_volume.browser_data.id
  instance_id = aws_instance.linkedln_vm.id
  
  # Ensure instance is running before attaching
  depends_on = [aws_instance.linkedln_vm]
}

# Associate EIP with new VM
resource "aws_eip_association" "attach_eip" {
  allocation_id = data.aws_eip.static.id
  instance_id   = aws_instance.linkedln_vm.id
}

# Outputs
output "instance_id" {
  value = aws_instance.linkedln_vm.id
}

output "public_ip" {
  value = aws_instance.linkedln_vm.public_ip
}

output "instance_type" {
  value = aws_instance.linkedln_vm.instance_type
}

output "browser_volume_attached" {
  value = "Browser volume ${var.browser_volume_id} attached as /dev/xvdf"
}