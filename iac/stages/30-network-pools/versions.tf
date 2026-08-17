terraform {
  required_version = ">= 1.7.0"
  required_providers {
    vcf = {
      source  = "vmware/vcf"
      version = "0.18.1"
    }
  }
}
