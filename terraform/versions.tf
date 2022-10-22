
terraform {

  cloud {
      organization = "Training1997"

      workspaces {
        name = "Arctiq-iac-Mission"
      }
    }
  
}