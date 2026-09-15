terraform {
  backend "gcs" {
    bucket = "python-k8s-app-demo-dt26-tfstate"
    prefix = "terraform/state"
  }
}
