variable "contacts" {
  description = "AWS account contacts configuration including primary and alternate contacts. The `primary.country_code` must be a 2-letter ISO 3166-1 alpha-2 country code (e.g., 'US', 'GB'). The `alternates` map keys must be one of: billing, operations, or security."
  type = object({
    enabled = optional(bool, false)

    primary = optional(object({
      address_line_1     = string
      address_line_2     = optional(string)
      address_line_3     = optional(string)
      city               = string
      company_name       = optional(string)
      country_code       = string
      district_or_county = optional(string)
      full_name          = string
      phone_number       = string
      postal_code        = string
      state_or_region    = optional(string)
      website_url        = optional(string)
    }))

    alternates = optional(map(object({
      email_address = string
      name          = string
      phone_number  = string
      title         = string
    })), {})
  })

  default = {}

  validation {
    condition = alltrue([
      for key in keys(try(var.contacts.alternates, {})) :
      contains(["billing", "operations", "security"], lower(key))
    ])
    error_message = "Alternate contact keys must be one of: billing, operations, security."
  }

  validation {
    condition = (
      try(var.contacts.primary, null) == null ||
      can(regex("^[A-Z]{2}$", try(var.contacts.primary.country_code, "")))
    )
    error_message = "Primary contact country_code must be a 2-letter ISO country code (e.g., 'US', 'GB')."
  }
}
