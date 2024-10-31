variable "region" {
    type        = string
    description = "ap-southeast-1 | eu-west-2"
}

variable "project" {
    type        = string
    description = "Project name | srp"
}

variable "environment" {
    type        = string
    description = "Environment name | staging / production"
}

variable "service_name" {
    type = string
}

variable "hostzone" {
    type = string
}

variable "cpu" {
    type = number
}

variable "memory" {
    type = number
}

variable "desired_count" {
    type = number
}

variable "max_capacity" {
    type = number
}

variable "min_capacity" {
    type = number
}

variable "enable_auto_scaling" {
    type = bool
}

variable "host_header" {
    type = string
}

variable "nginx_image_tag" {
    type = string
}

variable "phpapp_image_tag" {
    type = string
}

variable "subdomain_name" {
    type = string
}

variable "database_secrets" {
    type    = string
    default = null
}

variable "common_secrets" {
    type    = string
    default = null
}
