output "vpc_id" {
  description = "hermes-vpc ID — same design as Chapter 8"
  value       = module.network.vpc_id
}

output "public_subnet_id" {
  description = "Subnet for hermes-controlplane-01 (Chapter 9 module next)"
  value       = module.network.public_subnet_id
}

output "internet_gateway_id" {
  value = module.network.internet_gateway_id
}
