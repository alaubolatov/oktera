data "okta_brands" "brands" {}

locals {
  okta_knauf_brand_id = [for brand in data.okta_brands.brands.brands : brand["id"] if startswith(brand["name"], "Knauf Digital")][0]
}
