variable "workload" {
  description = "The name of workload to deploy."
  default     = "clpdevsecops"
}

variable "environment" {
  description = "The name of the environment to deploy."
  default     = "test"
}

variable "location" {
  description = "The Azure region to deploy resources"
  default     = "eastus"
}

variable "docker_image" {
  description = "The Docker image to deploy."
  default     = "tbeit/juice-shop:12419828744"
}