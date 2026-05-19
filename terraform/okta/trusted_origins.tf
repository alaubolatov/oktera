resource "okta_trusted_origin" "trusted_origins" {
  for_each = jsondecode(file("../../settings/security/trusted_origins/${var.deployment_env}.json"))

  name   = each.key
  origin = each.value["origin"]
  scopes = each.value["scopes"]

  lifecycle {
    prevent_destroy = true
  }
}
