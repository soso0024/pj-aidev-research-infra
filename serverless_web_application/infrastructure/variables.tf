# infrastructure/variables.tf
variable "project_name" {
  type    = string
  default = "serverless-web-app"
}

variable "environment" {
  type    = string
  default = "dev"
}
