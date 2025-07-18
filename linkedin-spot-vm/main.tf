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
  availability_zone           = data.aws_ebs_volume.browser_data.availability_zone

  # Spot configuration
  instance_market_options {
    market_type = "spot"
    spot_options {
      spot_instance_type             = "one-time"
      instance_interruption_behavior = "terminate"
      max_price                      = var.spot_max_price
    }
  }

  user_data  = data.template_file.user_data.rendered
  monitoring = true

  # Root volume - optimized for system files only
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.volume_size
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
    encrypted             = false
  }

  # Enable EBS optimization for better volume performance
  ebs_optimized = true

  tags = {
    Name        = "LinkedIn-Spot-VM"
    Purpose     = "Browser-Automation"
    Environment = "Production"
    VolumeSetup = "Configured"
  }

  # Ensure the instance waits for the browser volume to be available
  depends_on = [data.aws_ebs_volume.browser_data]
}

# Attach the pre-configured browser volume
resource "aws_volume_attachment" "browser_data" {
  device_name = "/dev/xvdf"
  volume_id   = data.aws_ebs_volume.browser_data.id
  instance_id = aws_instance.linkedln_vm.id
  
  # Force detach if volume is already attached elsewhere
  force_detach = true
  
  # Ensure instance is running before attaching
  depends_on = [aws_instance.linkedln_vm]
}

# Associate EIP with new VM
resource "aws_eip_association" "attach_eip" {
  allocation_id = data.aws_eip.static.id
  instance_id   = aws_instance.linkedln_vm.id
  
  # Wait for volume attachment to complete first
  depends_on = [aws_volume_attachment.browser_data]
}

# Outputs
output "instance_id" {
  value       = aws_instance.linkedln_vm.id
  description = "EC2 Instance ID"
}

output "public_ip" {
  value       = aws_instance.linkedln_vm.public_ip
  description = "Public IP address (temporary)"
}

output "elastic_ip" {
  value       = data.aws_eip.static.public_ip
  description = "Static Elastic IP address"
}

output "instance_type" {
  value       = aws_instance.linkedln_vm.instance_type
  description = "Instance type used"
}

output "browser_volume_status" {
  value       = "Browser volume ${var.browser_volume_id} attached as /dev/xvdf"
  description = "Browser volume attachment status"
}

output "availability_zone" {
  value       = aws_instance.linkedln_vm.availability_zone
  description = "Instance availability zone"
}

output "rdp_connection" {
  value       = "RDP to ${data.aws_eip.static.public_ip}:3389 (user: ubuntu, pass: YourStrongPassword)"
  description = "RDP connection details"
}

output "browser_data_location" {
  value       = "Browser data persisted at /mnt/browsers on EBS volume"
  description = "Browser data persistence info"
}