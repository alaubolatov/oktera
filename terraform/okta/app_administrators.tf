locals {
  app_administrators = yamldecode(file("../../settings/app_administrators/${var.deployment_env}.yaml"))

  apps_ = toset(flatten([for admin_name, app_names in local.app_administrators : app_names]))
}

data "okta_app" "apps_" {
  for_each = local.apps_

  label = each.value
}

data "okta_user" "app_administrators" {
  for_each = local.app_administrators

  search {
    name  = "profile.email"
    value = each.key
  }
}

resource "okta_admin_role_targets" "app_administrators" {
  for_each = local.app_administrators

  user_id   = data.okta_user.app_administrators[each.key].id
  role_type = "APP_ADMIN"
  apps      = [for app_name in each.value : "${data.okta_app.apps_[app_name].name}.${data.okta_app.apps_[app_name].id}"]

  depends_on = [okta_user_admin_roles.administrators]
}
