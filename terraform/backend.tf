terraform {
  backend "s3" {
    bucket       = "sreechandana-terraform-state-934868"
    key          = "terraform-monitoring/dev/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}