locals {
  default_auth_server_config = yamldecode(file("../../settings/security/default_auth_server/${var.deployment_env}.yaml"))

  auth_servers_config = yamldecode(file("../../settings/security/auth_servers/${var.deployment_env}.yaml"))

  default_policy_rule = local.default_auth_server_config["Default access policy"]["Default policy rule"]

  common_default_claims       = yamldecode(file("../../settings/security/default_auth_server/claims/_common.yaml"))
  env_specific_default_claims = yamldecode(file("../../settings/security/default_auth_server/claims/${var.deployment_env}.yaml"))

  default_id_claims     = merge(local.common_default_claims["ID claims"], local.env_specific_default_claims["ID claims"])
  default_access_claims = merge(local.common_default_claims["Access claims"], local.env_specific_default_claims["Access claims"])
}

resource "okta_auth_server_default" "default_auth_server" {
  name                      = local.default_auth_server_config["Name"]
  audiences                 = local.default_auth_server_config["Audiences"]
  description               = local.default_auth_server_config["Description"]
  issuer_mode               = local.default_auth_server_config["Issuer mode"]
  credentials_rotation_mode = local.default_auth_server_config["Credentials rotation mode"]
  status                    = local.default_auth_server_config["Active?"] ? "ACTIVE" : "INACTIVE"

  lifecycle {
    prevent_destroy = true
  }
}

resource "okta_auth_server" "auth_servers" {
  for_each = local.auth_servers_config

  name                      = each.key
  audiences                 = each.value["Audiences"]
  description               = each.value["Description"]
  issuer_mode               = each.value["Issuer mode"]
  credentials_rotation_mode = each.value["Credentials rotation mode"]
  status                    = each.value["Active?"] ? "ACTIVE" : "INACTIVE"

  lifecycle {
    prevent_destroy = true
  }
}

data "okta_auth_server_policy" "default" {
  auth_server_id = okta_auth_server_default.default_auth_server.id
  name           = "Default Policy"
}

resource "okta_auth_server_policy_rule" "knauf_default" {
  auth_server_id = data.okta_auth_server_policy.default.auth_server_id
  policy_id      = data.okta_auth_server_policy.default.id

  name = local.default_policy_rule["Name"]

  priority             = 1
  grant_type_whitelist = local.default_policy_rule["Grant types"]

  group_whitelist = local.default_policy_rule["Groups"]
  scope_whitelist = local.default_policy_rule["Scopes"]

  access_token_lifetime_minutes  = local.default_policy_rule["Access token lifetime (in minutes)"]
  refresh_token_lifetime_minutes = local.default_policy_rule["Refresh token lifetime (in minutes)"]
  refresh_token_window_minutes   = local.default_policy_rule["Refresh token window (in minutes)"]

  lifecycle {
    prevent_destroy = true
  }
}

resource "okta_auth_server_claim" "id_claims" {
  for_each = local.default_id_claims

  auth_server_id = okta_auth_server_default.default_auth_server.id
  name           = each.value["Name"]

  always_include_in_token = each.value["Always include in token?"]
  claim_type              = "IDENTITY"

  value_type        = upper(each.value["Value type"])
  value             = each.value["Value"]
  group_filter_type = upper(each.value["Value type"]) == "GROUPS" ? each.value["Group filter type"] : null

  scopes = each.value["Scopes"]

  status = upper(merge({ Status = "active" }, each.value)["Status"])

  depends_on = [okta_user_schema_property.default_user]
}

resource "okta_auth_server_claim" "access_claims" {
  for_each = local.default_access_claims

  auth_server_id = okta_auth_server_default.default_auth_server.id
  name           = each.value["Name"]

  always_include_in_token = each.value["Always include in token?"]
  claim_type              = "RESOURCE"

  value_type        = upper(each.value["Value type"])
  value             = each.value["Value"]
  group_filter_type = upper(each.value["Value type"]) == "GROUPS" ? each.value["Group filter type"] : null

  scopes = each.value["Scopes"]

  status = upper(merge({ Status = "active" }, each.value)["Status"])

  depends_on = [okta_user_schema_property.default_user]
}
