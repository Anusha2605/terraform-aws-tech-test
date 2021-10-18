variable "region" {
}

variable "vpc-cidr" {
}

variable "subnet-cidr-public" {
  type = list(any)
}

variable "imageid" {
}

# for the purpose of this exercise use the default key pair on your local system
variable "public_key" {
  default = "~/.ssh/id_rsa.pub"
}


