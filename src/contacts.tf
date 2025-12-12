locals {
  contacts_enabled = try(var.contacts.enabled, false)
  primary_contact  = try(var.contacts.primary, null)

  # Filter alternate contacts that are defined
  alternate_contacts = {
    for type, contact in try(var.contacts.alternates, {}) :
    type => contact if local.contacts_enabled && contact != null
  }

  # Flatten alternate contacts for all sub-accounts
  alternate_contacts_accounts = merge([
    for type, contact in local.alternate_contacts : {
      for account_name, account_id in local.account_names_account_ids :
      "${type}-${account_name}" => {
        type       = upper(type)
        account_id = account_id
        contact    = contact
      }
    }
  ]...)
}

# Primary contact for master account
resource "aws_account_primary_contact" "master" {
  count = local.contacts_enabled && local.primary_contact != null ? 1 : 0

  address_line_1     = local.primary_contact.address_line_1
  address_line_2     = local.primary_contact.address_line_2
  address_line_3     = local.primary_contact.address_line_3
  city               = local.primary_contact.city
  company_name       = local.primary_contact.company_name
  country_code       = local.primary_contact.country_code
  district_or_county = local.primary_contact.district_or_county
  full_name          = local.primary_contact.full_name
  phone_number       = local.primary_contact.phone_number
  postal_code        = local.primary_contact.postal_code
  state_or_region    = local.primary_contact.state_or_region
  website_url        = local.primary_contact.website_url
}

# Primary contact for all sub-accounts
resource "aws_account_primary_contact" "accounts" {
  for_each = local.contacts_enabled && local.primary_contact != null ? local.account_names_account_ids : {}

  account_id         = each.value
  address_line_1     = local.primary_contact.address_line_1
  address_line_2     = local.primary_contact.address_line_2
  address_line_3     = local.primary_contact.address_line_3
  city               = local.primary_contact.city
  company_name       = local.primary_contact.company_name
  country_code       = local.primary_contact.country_code
  district_or_county = local.primary_contact.district_or_county
  full_name          = local.primary_contact.full_name
  phone_number       = local.primary_contact.phone_number
  postal_code        = local.primary_contact.postal_code
  state_or_region    = local.primary_contact.state_or_region
  website_url        = local.primary_contact.website_url

  depends_on = [
    aws_organizations_account.organization_accounts,
    aws_organizations_account.organizational_units_accounts
  ]
}

# Alternate contacts for master account
resource "aws_account_alternate_contact" "master" {
  for_each = local.alternate_contacts

  alternate_contact_type = upper(each.key)
  email_address          = each.value.email_address
  name                   = each.value.name
  phone_number           = each.value.phone_number
  title                  = each.value.title
}

# Alternate contacts for all sub-accounts
resource "aws_account_alternate_contact" "accounts" {
  for_each = local.alternate_contacts_accounts

  account_id             = each.value.account_id
  alternate_contact_type = each.value.type
  email_address          = each.value.contact.email_address
  name                   = each.value.contact.name
  phone_number           = each.value.contact.phone_number
  title                  = each.value.contact.title

  depends_on = [
    aws_organizations_account.organization_accounts,
    aws_organizations_account.organizational_units_accounts
  ]
}
