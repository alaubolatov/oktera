locals {
  administrators = yamldecode(file("../../settings/administrators/${var.deployment_env}.yaml"))
}

data "okta_user" "administrators" {
  for_each = local.administrators

  search {
    name  = "profile.email"
    value = each.key
  }
}

resource "okta_user_admin_roles" "administrators" {
  for_each = local.administrators

  user_id     = data.okta_user.administrators[each.key].id
  admin_roles = each.value

  disable_notifications = true
}
