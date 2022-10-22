
terraform {

  cloud {
      organization = "Training1997"

      workspaces {
        name = "iac-test"
      }
    }
  
}