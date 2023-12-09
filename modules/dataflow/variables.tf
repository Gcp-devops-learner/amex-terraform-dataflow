/**
 * Copyright 2019 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
variable "project_id" {
  type        = string
  description = "The project in which the resource belongs. If it is not provided, the provider project is used."
}

variable "name" {
  type        = string
  description = "The name of the dataflow job"
}

variable "template_gcs_path" {
  type        = string
  description = "The GCS path to the Dataflow job template."
}

variable "temp_gcs_location" {
  type        = string
  description = "A writeable location on GCS for the Dataflow job to dump its temporary data."
}

variable "parameters" {
  type        = map(string)
  description = "Key/Value pairs to be passed to the Dataflow job (as used in the template)."
  default     = {}
}

variable "max_workers" {
  type        = number
  description = " The number of workers permitted to work on the job. More workers may improve processing speed at additional cost."
}

variable "on_delete" {
  type        = string
  description = "One of drain or cancel. Specifies behavior of deletion during terraform destroy. The default is cancel."
  default     = "cancel"
}

variable "skip_wait_on_job_termination" {
  type        = bool
  description = "If set to true, terraform will treat DRAINING and CANCELLING as terminal states when deleting the resource, and will remove the resource from terraform state and move on."
  default     = false
}

variable "region" {
  type        = string
  description = "The region in which the created job should run. Also determines the location of the staging bucket if created."
}

variable "zone" {
  type        = string
  description = "The zone in which the created job should run."
}

variable "service_account_email" {
  type        = string
  description = "The Service Account email that will be used to identify the VMs in which the jobs are running"
  default     = ""

  validation {
    condition     = var.service_account_email != ""
    error_message = "[!] ERROR: Jobs must run as a specific, custom service account with limited permissions and users must only be granted ability to use that service account (no project-wide iam.serviceAccount.actAs) - including the service accounts specified in job templates. See Dataflow Security Certification."
  }
}

variable "subnetwork" {
  type        = string
  description = "The subnetwork to which VMs will be assigned."
}

variable "network" {
  type        = string
  description = "The network to which VMs will be assigned."
}

variable "machine_type" {
  type        = string
  description = "The machine type to use for the job."
  default     = "n1-standard-1"
}

variable "additional_experiments" {
  type        = list(string)
  description = "List of experiments that should be used by the job."
  default     = []
}

variable "enable_streaming_engine" {
  type        = bool
  description = "Enable/disable the use of Streaming Engine for the job. Note that Streaming Engine is enabled by default for pipelines developed against the Beam SDK for Python v2.21.0 or later when using Python 3."
  default     = false

  validation {
    condition     = var.enable_streaming_engine == false
    error_message = "[!] ERROR: Streaming engine must not be used. See Dataflow Security Certification."
  }
}

variable "kms_key_name" {
  type        = string
  description = "The name for the Cloud KMS key for the job. Key format is: projects/PROJECT_ID/locations/LOCATION/keyRings/KEY_RING/cryptoKeys/KEY."
}

variable "labels" {
  description = "User labels to be specified for the job. Keys and values should follow the restrictions specified in the labeling restrictions page."
  type        = map(any)
}