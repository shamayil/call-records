terraform {
    required_providers {
        random = {
            source  = "hashicorp/random"
            version = "3.5.1"
        }

        aws = {
            source  = "hashicorp/aws"
            version = ">= 5.26.0"
        }
    }

    required_version = ">= 1.3.0"
}

provider "aws" {
    region = var.region
}
