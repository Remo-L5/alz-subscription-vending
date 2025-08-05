variable "application_name" {
    description = "The name of the Application or Workload."
    type        = string
}

variable "application_short_name" {
    description = "The short name of the Application or Workload."
    type        = string
}

variable "location" {
    description = "The location name."
    type        = string
    default     = "westus2"
    validation {
        condition     = contains(["westus2", "westus3"], var.location)
        error_message  = "The location name must be either 'westus2' or 'westus3'."
    }
}

variable "management_group_name" {
    description = "The name of the Management Group."
    type        = string
    default     = "alz-landingzones"
}

variable "subscription_developer_group_object_id" {
    description = "The Object ID of the subscription developer group."
    type        = string
}

variable "subscription_owner_object_id" {
    description = "The Object ID of the staff member owning the subscription."
    type        = string
}
