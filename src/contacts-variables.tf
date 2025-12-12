variable "contacts" {
  description = "AWS account contacts configuration including primary and alternate contacts."
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
}
