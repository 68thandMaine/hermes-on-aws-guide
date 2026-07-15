variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "aws_profile" {
  description = "Local AWS CLI profile. Leave empty in CI (uses AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY)."
  type        = string
  default     = "hermes"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "name_prefix" {
  type    = string
  default = "hermes"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "availability_zone" {
  type    = string
  default = "us-west-2a"
}
