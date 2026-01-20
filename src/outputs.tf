output "account_id" {
  value       = try(aws_organizations_account.this[0].id, null)
  description = "The ID of the AWS account"
}

output "account_arn" {
  value       = try(aws_organizations_account.this[0].arn, null)
  description = "The ARN of the AWS account"
}

output "account_name" {
  value       = try(aws_organizations_account.this[0].name, null)
  description = "The name of the AWS account"
}

output "account_email" {
  value       = try(aws_organizations_account.this[0].email, null)
  description = "The email of the AWS account"
}

output "parent_id" {
  value       = var.parent_id
  description = "The parent ID of the account"
}
