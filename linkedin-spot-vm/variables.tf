variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "m5.large"
  
  validation {
    condition = contains([
      "t3.medium", "t3.large", "t3.xlarge",
      "m5.large", "m5.xlarge", "m5.2xlarge",
      "c5.large", "c5.xlarge", "c5.2xlarge"
    ], var.instance_type)
    error_message = "Instance type must be suitable for browser automation workloads."
  }
}

variable "volume_size" {
  description = "Root volume size in GB (browser data is on separate EBS volume)"
  type        = number
  default     = 14
  
  validation {
    condition     = var.volume_size >= 10 && var.volume_size <= 50
    error_message = "Root volume size must be between 10 and 50 GB."
  }
}

variable "spot_max_price" {
  description = "Maximum price for spot instance (USD per hour)"
  type        = string
  default     = "0.10"
  
  validation {
    condition     = can(tonumber(var.spot_max_price)) && tonumber(var.spot_max_price) > 0
    error_message = "Spot max price must be a valid positive number."
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "key_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
  default     = "LinkedIn-VM"
}

variable "security_group_id" {
  description = "Security group ID for the instance"
  type        = string
  default     = "sg-08e3357b5355a8c4a"
  
  validation {
    condition     = can(regex("^sg-[0-9a-f]{8,17}$", var.security_group_id))
    error_message = "Security group ID must be a valid AWS security group ID."
  }
}

variable "ami_id" {
  description = "AMI ID for Ubuntu 22.04 LTS"
  type        = string
  default     = "ami-020cba7c55df1f615"  # Ubuntu 22.04 LTS in us-east-1
  
  validation {
    condition     = can(regex("^ami-[0-9a-f]{8,17}$", var.ami_id))
    error_message = "AMI ID must be a valid AWS AMI ID."
  }
}

variable "dummy_instance_id" {
  description = "Dummy instance ID for EIP parking when spot instance is destroyed"
  type        = string
  default     = "i-06aed8d8baa0db506"
  
  validation {
    condition     = can(regex("^i-[0-9a-f]{8,17}$", var.dummy_instance_id))
    error_message = "Instance ID must be a valid AWS instance ID."
  }
}

variable "eip_allocation_id" {
  description = "Allocation ID of the static Elastic IP"
  type        = string
  default     = "eipalloc-097c2ba45b51396c8"
  
  validation {
    condition     = can(regex("^eipalloc-[0-9a-f]{8,17}$", var.eip_allocation_id))
    error_message = "EIP allocation ID must be a valid AWS EIP allocation ID."
  }
}

variable "browser_volume_id" {
  description = "Pre-configured browser data volume ID (contains Gmail login, scripts, Drive folder)"
  type        = string
  default     = "vol-06834ddf3f58d41a8"
  
  validation {
    condition     = can(regex("^vol-[0-9a-f]{8,17}$", var.browser_volume_id))
    error_message = "Volume ID must be a valid AWS EBS volume ID."
  }
}

# Optional variables for advanced configuration
variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "root_volume_type" {
  description = "Root volume type"
  type        = string
  default     = "gp3"
  
  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.root_volume_type)
    error_message = "Root volume type must be gp2, gp3, io1, or io2."
  }
}