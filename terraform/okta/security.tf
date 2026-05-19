# NOTE: This file uses the legacy okta_factor resource.
# For modern authenticator management, see authenticators.tf which uses okta_authenticator resources.
# Your Okta organization uses the modern Authenticators API.
# The okta_factor resources below are kept for backwards compatibility but may be deprecated.

locals {
  general        = yamldecode(file("../../settings/security/general.yaml"))
  authentication = yamldecode(file("../../settings/security/authentication.yaml"))
  multifactor    = yamldecode(file("../../settings/security/multifactor.yaml"))
  authenticators = yamldecode(file("../../settings/authenticators/${var.deployment_env}.yaml"))

  multifactor_provider_id_matchings = {
    "Okta Verify (Push Notification)" : "okta_push"
    "SMS Verification" : "okta_sms"
    "Voice Call Authentication" : "okta_call"
    "Google Authenticator" : "google_otp"
    "FIDO2 (WebAuthn)" : "fido_webauthn"
    "YubiKey" : "yubikey_token"
    "Duo Security" : "duo"
    "Symantec VIP" : "symantec_vip"
    "RSA SecurID" : "rsa_token"
    "Security Question" : "okta_question"
    "Email Authentication" : "okta_email"
  }
}

resource "okta_authenticator" "authenticators" {
  for_each = local.authenticators

  name   = each.key
  key    = each.value["key"]
  status = each.value["active?"] ? "ACTIVE" : "INACTIVE"

  settings = can(each.value["settings"]) ? jsonencode(each.value["settings"]) : null

  lifecycle {
    prevent_destroy = true
  }
}

resource "okta_security_notification_emails" "security_notification_emails" {
  send_email_for_new_device_enabled        = local.general["Security notification emails"]["New sign-on notification email"]
  send_email_for_password_changed_enabled  = local.general["Security notification emails"]["Password changed notification email"]
  send_email_for_factor_enrollment_enabled = local.general["Security notification emails"]["MFA enrolled notification email"]
  send_email_for_factor_reset_enabled      = local.general["Security notification emails"]["MFA reset notification email"]
  report_suspicious_activity_enabled       = local.general["Security notification emails"]["Report suspicious activity via email"]

  lifecycle {
    prevent_destroy = true
  }
}

resource "okta_threat_insight_settings" "threat_insight_settings" {
  action = local.general["Okta ThreatInsight settings"]["Action"]

  lifecycle {
    prevent_destroy = true
  }
}

resource "okta_policy_password_default" "default" {
  password_min_length = local.authentication["Password"]["Default Policy"]["Password Settings"]["Minimum length"]

  # complexity
  password_min_lowercase      = local.authentication["Password"]["Default Policy"]["Password Settings"]["Complexity requirements"]["Lower case letter"] ? 1 : 0
  password_min_uppercase      = local.authentication["Password"]["Default Policy"]["Password Settings"]["Complexity requirements"]["Upper case letter"] ? 1 : 0
  password_min_number         = local.authentication["Password"]["Default Policy"]["Password Settings"]["Complexity requirements"]["Number (0-9)"] ? 1 : 0
  password_min_symbol         = local.authentication["Password"]["Default Policy"]["Password Settings"]["Complexity requirements"]["Symbol"] ? 1 : 0
  password_exclude_username   = local.authentication["Password"]["Default Policy"]["Password Settings"]["Complexity requirements"]["Does not contain part of username"]
  password_exclude_first_name = local.authentication["Password"]["Default Policy"]["Password Settings"]["Complexity requirements"]["Does not contain first name"]
  password_exclude_last_name  = local.authentication["Password"]["Default Policy"]["Password Settings"]["Complexity requirements"]["Does not contain last name"]

  # common password check
  password_dictionary_lookup = local.authentication["Password"]["Default Policy"]["Password Settings"]["Common password check"]["Restrict use of common passwords"]

  # password age
  password_history_count    = local.authentication["Password"]["Default Policy"]["Password Settings"]["Password age"]["Enforce password history for last `n` passwords"]
  password_min_age_minutes  = 60 * local.authentication["Password"]["Default Policy"]["Password Settings"]["Password age"]["Minimum password age in hours"]
  password_max_age_days     = local.authentication["Password"]["Default Policy"]["Password Settings"]["Password age"]["Password expires after `n` days"]
  password_expire_warn_days = local.authentication["Password"]["Default Policy"]["Password Settings"]["Password age"]["Prompt user `n ` days before password expires"]

  # lock out
  password_max_lockout_attempts          = local.authentication["Password"]["Default Policy"]["Password Settings"]["Lock out"]["Lock out user after `n` unsuccessful attempts"]
  password_auto_unlock_minutes           = local.authentication["Password"]["Default Policy"]["Password Settings"]["Lock out"]["Account is automatically unlocked after `n` minutes"]
  password_show_lockout_failures         = local.authentication["Password"]["Default Policy"]["Password Settings"]["Lock out"]["Show lock out failures"]
  password_lockout_notification_channels = local.authentication["Password"]["Default Policy"]["Password Settings"]["Lock out"]["Send lockout email to user"] ? ["EMAIL"] : []

  # self-service recovery options
  sms_recovery         = local.authentication["Password"]["Default Policy"]["Account Recovery"]["Self-service recovery options"]["SMS"] ? "ACTIVE" : "INACTIVE"
  call_recovery        = local.authentication["Password"]["Default Policy"]["Account Recovery"]["Self-service recovery options"]["Voice call"] ? "ACTIVE" : "INACTIVE"
  email_recovery       = local.authentication["Password"]["Default Policy"]["Account Recovery"]["Self-service recovery options"]["Email"] ? "ACTIVE" : "INACTIVE"
  recovery_email_token = local.authentication["Password"]["Default Policy"]["Account Recovery"]["Self-service recovery options"]["Reset/Unlock recovery emails are valid for `n` minutes"]

  question_recovery = local.authentication["Password"]["Default Policy"]["Account Recovery"]["Additional self-service recovery option"]["Security question"] ? "ACTIVE" : "INACTIVE"

  lifecycle {
    prevent_destroy = true
  }
}

resource "okta_factor" "multifactor_auth_options" {
  for_each = local.multifactor

  provider_id = local.multifactor_provider_id_matchings[each.key]
  active      = each.value

  lifecycle {
    prevent_destroy = true
  }
}
