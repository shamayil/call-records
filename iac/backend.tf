terraform {
    backend "s3" {
        dynamodb_table = "tfstate-lock"
    }
}
