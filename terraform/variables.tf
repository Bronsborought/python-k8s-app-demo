variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Default Google Cloud region"
  type        = string
  default     = "europe-central2"
}

variable "billing_account_id" {
  description = "Google Cloud Billing Account ID"
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly project budget in USD"
  type        = number
  default     = 20
}
