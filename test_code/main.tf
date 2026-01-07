terraform {
  cloud {
    hostname = "tfe22.aws.munnep.com"
    organization = "test"

    workspaces {
      name = "test"
    }
  }
}

resource "null_resource" "test" {
  
}