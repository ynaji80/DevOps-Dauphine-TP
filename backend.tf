terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.10"
    }
  }

   backend "gcs" {
     bucket = "tp-devops-1052023"
   }

  required_version = ">= 1.0"
}


provider "google" {
    project = "tp-devops-401106"
}