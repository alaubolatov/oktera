locals {
  common_group_rules       = yamldecode(file("../../settings/group_rules/_common.yaml"))
  env_specific_group_rules = yamldecode(file("../../settings/group_rules/${var.deployment_env}.yaml"))
  group_rules              = merge(local.common_group_rules, local.env_specific_group_rules)

  groups_to_use_in_rules = toset(flatten([for rule in local.group_rules : concat(
    lookup(rule, "source groups", []),
    lookup(rule, "target groups", [])
  )]))
}

resource "okta_group_rule" "group_rules" {
  for_each = local.group_rules

  name = each.key

  status = each.value["active?"] ? "ACTIVE" : "INACTIVE"

  expression_type = "urn:okta:expression:1.0"
  expression_value = can(each.value["expression"]) ? each.value["expression"] : "isMemberOfAnyGroup(\"${join("\",\"", [for group_name in each.value["source groups"] : okta_group.groups[group_name].id])}\")"
  group_assignments = [for group_name in each.value["target groups"] : okta_group.groups[group_name].id]

  depends_on = [okta_group.groups]

  lifecycle {
    #prevent_destroy = true
  }
}