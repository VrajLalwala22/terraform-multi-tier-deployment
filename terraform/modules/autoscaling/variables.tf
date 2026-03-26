variable "public_subnets" {
  type = list(string)
}
variable "ssh_key_name" {}
variable "ami_id" {}
variable "user_data" {}
variable "instance_type" {}
variable "vpc_id" {}
variable "repo_url" {}
variable "target_group_arn" {}