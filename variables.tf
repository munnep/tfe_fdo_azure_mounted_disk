variable "tag_prefix" {
  description = "default prefix of names"
}

variable "vnet_cidr" {
  description = "which private subnet do you want to use for the VPC. Subnet mask of /16"
}

variable "tfe_os" {
  description = "which OS to use ubuntu or redhat"

  validation {
    condition     = contains(["ubuntu", "redhat"], lower(var.tfe_os))
    error_message = "tfe_os must be either 'ubuntu' or 'redhat'."
  }
}

variable "azure_subscription_id" {
  description = "azure subscription id to use"
}

variable "azure_images_subscription_id" {
  description = "azure subscription id where the images are located that has to be used by IBM"
}

variable "public_key" {
  description = "public key to use on the instances"
}

variable "tfe_password" {
  description = "password for tfe user"
}

variable "dns_hostname" {
  type        = string
  description = "DNS name you use to access the website"
}

variable "dns_zonename" {
  type        = string
  description = "DNS zone the record should be created in"
}

variable "tfe_release" {
  description = "Which release version of TFE to install"
}

variable "tfe_license" {
  description = "the TFE license as a string"
}

variable "region" {
  description = "region to create the environment"
}

variable "certificate_email" {
  description = "email address to register the certificate"
}