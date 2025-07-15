variable "instance_type" {
  default = "m5.large"  # Your current instance type
}

variable "volume_size" {
  default = 14  # Reduced from 22GB since browser data is on separate volume
}

variable "region" {
  default = "us-east-1"
}

variable "key_name" {
  default = "LinkedIn-VM"
}

variable "security_group_id" {
  default = "sg-08e3357b5355a8c4a"
}

variable "ami_id" {
  default = "ami-020cba7c55df1f615"
}

variable "dummy_instance_id" {
  default = "i-06aed8d8baa0db506"
}

variable "eip_allocation_id" {
  description = "Allocation ID of the static Elastic IP"
  default     = "eipalloc-097c2ba45b51396c8"
}

variable "browser_volume_id" {
  description = "Pre-configured browser data volume ID"
  default     = "vol-06834ddf3f58d41a8"
}