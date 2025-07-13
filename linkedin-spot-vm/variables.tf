variable "instance_type" {
  default = "t2.micro"
}

variable "volume_size" {
  default = 14
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
