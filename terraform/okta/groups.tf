locals {
  common_groups = yamldecode(file("../../settings/groups/_common.yaml"))

  env_specific_groups = yamldecode(file("../../settings/groups/${var.deployment_env}.yaml"))

  groups = { for group in flatten([local.common_groups, local.env_specific_groups]) :
    "${group["name"]}" => {
      name        = group["name"]
      description = lookup(group, "description", "")
      admins      = lookup(group, "admins", "") == "" ? [] : group["admins"]
      apps        = lookup(group, "apps", "") == "" ? [] : group["apps"]

    }
  }

  # list of users to make admin in any group
  group_admins = toset(flatten([for group in local.groups : group["admins"]]))
  # list of apps any new group is going to be assigned in
  apps = toset(flatten([for group in local.groups : group["apps"]]))

  # new_group => app_to_be_added_in mapping
  group_app_mappings = merge([for group in local.groups :
    { for app in group["apps"] :
      "${group["name"]}@${app}" => {
        group = group["name"]
        app   = app
  } }]...)

  # admin => new_group_to_be_admin_in mapping
  group_admin_mappings = { for admin in local.group_admins :
    "${admin}" => [for group in local.groups : group["name"] if contains(group["admins"], admin)]
  }
}

data "okta_user" "group_admins" {
  for_each = local.group_admins

  search {
    name  = "profile.email"
    value = each.value
  }
}

data "okta_app" "apps" {
  for_each = local.apps

  label = each.value
}

# create groups
resource "okta_group" "groups" {
  for_each = local.groups

  name        = each.value["name"]
  description = each.value["description"]

  lifecycle {
    prevent_destroy = true
  }
}

# assign group admins
resource "okta_admin_role_targets" "group_admins" {
  for_each = local.group_admin_mappings

  user_id   = data.okta_user.group_admins[each.key].id
  role_type = "GROUP_MEMBERSHIP_ADMIN"

  groups = [for group_name in each.value : okta_group.groups[group_name].id]

  depends_on = [okta_user_admin_roles.administrators]
}

# assign groups to apps
resource "okta_app_group_assignment" "group_assignments" {
  for_each = local.group_app_mappings

  app_id   = data.okta_app.apps[each.value["app"]].id
  group_id = okta_group.groups[each.value["group"]].id
}
