variable "accountLinkURL" {
  type        = string
  description = "The main URL of Knauf Portal Account webpage, without `https://` part, where we often redirect users from emails"
}

variable "emailSubjectSuffix" {
  type        = string
  default     = "" # just in case we forgot it, empty string works well for prod
  description = "Text to be added at the end of every email subjects. `Forgot Password` becomes `Forgot Password (dev)` when this value is `(dev)`."
}

variable "deployment_env" {
  type        = string
  description = "In some places within our Terraform configuration, we need to know which environment we're deploying this repo into. For instance, we use this variable when picking the currect trusted origins config file."
}

variable "supportEmail" {
  type        = string
  description = "Email used as support email"
}
