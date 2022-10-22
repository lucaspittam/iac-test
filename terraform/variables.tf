variable "aws_region" {
  type = string
  default = "us-east-2"
}

variable "AWS_ACCESS_KEY_ID" {
  type = string
  default = ""
}
variable "AWS_SECRET_ACCESS_KEY" {
  type = string
  default = ""
}

variable "instance_type" {
  type = string
  default = "t2.micro"
}