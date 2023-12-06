variable "pcc_url" {
  description = "Prisma Cloud Compute URL"
}

variable "pcc_username" {
  description = "Prisma Cloud Access Key"
  sensitive   = true
}

variable "pcc_password" {
  description = "Prisma Cloud Secret Access Key"
  sensitive   = true
}

variable "registry_to_scan" {
    description = "Container Regsitry to perform On Demand scan"
}

variable "repository_to_scan" {
  description = "Container Repository to perform On Demand scan"
}

variable "ec2_key_name" {
    description = "aws ec2 key name"
}

variable "tag_to_scan" {
  description = "Container Tag to perform on Demand Scan on"  
}

