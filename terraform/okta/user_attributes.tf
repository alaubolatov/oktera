locals {
  common_attributes       = yamldecode(file("../../settings/user_profile/okta_user_custom_attributes/_common.yaml"))
  env_specific_attributes = yamldecode(file("../../settings/user_profile/okta_user_custom_attributes/${var.deployment_env}.yaml"))
  custom_attributes       = merge(local.common_attributes, local.env_specific_attributes)
}

resource "okta_user_schema_property" "default_user" {
  for_each = local.custom_attributes

  index       = each.value["variable name"]
  title       = each.key
  type        = each.value["data type"]
  array_type  = each.value["data type"] == "array" ? lookup(each.value, "array type", "string") : null
  description = each.value["description"]
  required    = each.value["required"]
  master      = "OKTA"
  scope       = "NONE"
  unique      = each.value["value must be unique for each user?"] ? "UNIQUE_VALIDATED" : null

  lifecycle {
    prevent_destroy = true
  }
}
