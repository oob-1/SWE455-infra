terraform {
  backend "gcs" {
    # bucket and prefix supplied via -backend-config in CI:
    #   terraform init -backend-config="bucket=<state-bucket>" -backend-config="prefix=expense-tracker"
  }
}
