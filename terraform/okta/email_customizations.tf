locals {
  index_files            = fileset(abspath("../../settings/emails"), "[^_]**/index.html") # folders starting with _ are ignored
  email_template_folders = flatten([for filename in local.index_files : regexall("(^[^/]+)/", filename)])

  defaults = { for template_folder in local.email_template_folders :
    "${template_folder}/en.yaml" => {
      "template_name" : template_folder,
      "filename" : "en.yaml"
    }
  }

  alternatives = merge(
    [for template_folder in local.email_template_folders :
      { for translation_file in fileset(abspath("../../settings/emails/${template_folder}/translations"), "**") :
        "${template_folder}/${translation_file}" => {
          "template_name" : template_folder,
          "filename" : translation_file
        } if translation_file != "en.yaml"
      }
  ]...)
}

resource "okta_email_customization" "default_translations" {
  # for_each = local.defaults # in free tier email customizations are not supported
  for_each = {}

  brand_id = local.okta_knauf_brand_id

  template_name = each.value["template_name"]
  is_default    = true

  language = yamldecode(file("../../settings/emails/${each.value["template_name"]}/translations/${each.value["filename"]}"))["languageCode"]
  subject  = "${yamldecode(file("../../settings/emails/${each.value["template_name"]}/translations/${each.value["filename"]}"))["subject"]} ${var.emailSubjectSuffix}"
  body = templatefile(
    "${path.module}/../../settings/emails/${each.value["template_name"]}/index.html",
    merge(
      {
        banner         = file("${path.module}/../../settings/emails/_banner/index.html"),
        accountLinkURL = var.accountLinkURL,
        supportEmail   = var.supportEmail
      },
      yamldecode(file("${path.module}/../../settings/emails/${each.value["template_name"]}/translations/${each.value["filename"]}"))
    )
  )
}

resource "okta_email_customization" "translations" {
  # for_each = local.alternatives # in free tier email customizations are not supported
  for_each = {}

  brand_id = local.okta_knauf_brand_id

  template_name = each.value["template_name"]
  is_default    = false

  language = yamldecode(file("../../settings/emails/${each.value["template_name"]}/translations/${each.value["filename"]}"))["languageCode"]
  subject  = "${yamldecode(file("../../settings/emails/${each.value["template_name"]}/translations/${each.value["filename"]}"))["subject"]} ${var.emailSubjectSuffix}"
  body = templatefile(
    "${path.module}/../../settings/emails/${each.value["template_name"]}/index.html",
    merge(
      {
        banner         = file("${path.module}/../../settings/emails/_banner/index.html"),
        accountLinkURL = var.accountLinkURL,
        supportEmail   = var.supportEmail
      },
      yamldecode(file("${path.module}/../../settings/emails/${each.value["template_name"]}/translations/${each.value["filename"]}"))
    )
  )

  depends_on = [okta_email_customization.default_translations]
}
