output "cp4a_url" {
  description = "Access your Cloud Pak for Business Automation deployment at this URL."
  value = module.cp4a.cp4a_endpoint
}

output "cp4a_user" {
  description = "Username for your Cloud Pak for Business Automation deployment."
  value = module.cp4a.cp4a_user
}

output "cp4a_pass" {
  description = "Password for your Cloud Pak for Business Automation deployment."
  value = module.cp4a.cp4a_password
}

// Namespace
# output "namespace" {
#   value = var.namespace
# }