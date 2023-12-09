
# *************************************************************************
#    Locals
# *************************************************************************

locals {
  ##### General Usage ######
  project_id = "km1-runcloud"
  region     = "us-central1"
  zone       = "us-central1-a"

  ##### Utilities ######
  gcp_service_list = [
    "compute.googleapis.com",
    "dataflow.googleapis.com",
    "cloudkms.googleapis.com"
  ]

  ##### GCS #####
  gcs_bucket_name = "tmp-dir-bucket-${random_id.random_suffix.hex}"
  force_destroy   = true
}

# *************************************************************************
#    Utilities
# *************************************************************************

resource "google_project_service" "gcp_services" {
  for_each = toset(local.gcp_service_list)
  project  = local.project_id
  service  = each.value

  disable_dependent_services = true
}

data "google_project" "project" {
  project_id = local.project_id
}

resource "random_id" "random_suffix" {
  byte_length = 4
}

# *************************************************************************
#    Network
# *************************************************************************

module "vpc" {
  source       = "terraform-google-modules/network/google"
  version      = "~> 4.0"
  project_id   = local.project_id
  network_name = "dataflow-network"

  subnets = [
    {
      subnet_name           = "dataflow-subnetwork"
      subnet_ip             = "10.1.3.0/24"
      subnet_region         = local.region
      subnet_private_access = "true"
    },
  ]

  secondary_ranges = {
    dataflow-subnetwork = [
      {
        range_name    = "dataflow-secondary-range"
        ip_cidr_range = "192.168.64.0/24"
      },
    ]
  }

  depends_on = [
    google_project_service.gcp_services
  ]
}

# *************************************************************************
#    Service Account and IAM
# *************************************************************************

resource "google_service_account" "service_account" {
  project      = local.project_id
  account_id   = "dataflow-service-account"
  display_name = "Dataflow Service Account"
}

# https://cloud.google.com/dataflow/docs/concepts/security-and-permissions#controller_service_account
#     Dataflow permissions reference

// This allows the dataflow worker service account to run jobs
resource "google_project_iam_member" "dataflow_worker" {
  project = local.project_id
  role    = "roles/dataflow.worker"
  member  = "serviceAccount:${google_service_account.service_account.email}"

  depends_on = [
    google_project_service.gcp_services
  ]
}

// This allows the dataflow worker service account to administer objects in gcs during the jobs execution
resource "google_project_iam_member" "gcs_storage" {
  project = local.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.service_account.email}"

  depends_on = [
    google_project_service.gcp_services
  ]
}

// This allows the dataflow worker service account to write monitoring metrics
// Totally optional
resource "google_project_iam_member" "dataflow_metrics" {
  project = local.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.service_account.email}"

  depends_on = [
    google_project_service.gcp_services
  ]
}

// This allows the dataflow worker service account to use KMS for the jobs
// Only required when using KMS
resource "google_project_iam_member" "dataflow_custom_sa_kms" {
  project = local.project_id
  role    = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member  = "serviceAccount:${google_service_account.service_account.email}"

  depends_on = [
    google_project_service.gcp_services
  ]
}

// This allows the dataflow service agent account to use KMS for the jobs
// Only required when using KMS
resource "google_project_iam_member" "dataflow_service_agent_kms" {
  project = local.project_id
  role    = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member  = "serviceAccount:service-${data.google_project.project.number}@dataflow-service-producer-prod.iam.gserviceaccount.com"

  depends_on = [
    google_project_service.gcp_services
  ]
}

// This allows the compute engine service agent account to use KMS for the jobs
// Only required when using KMS
resource "google_project_iam_member" "compute_service_agent_kms" {
  project = local.project_id
  role    = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member  = "serviceAccount:service-${data.google_project.project.number}@compute-system.iam.gserviceaccount.com"

  depends_on = [
    google_project_service.gcp_services
  ]
}

# *************************************************************************
#    GCS
# *************************************************************************

module "dataflow_bucket" {
  source        = "./modules/dataflow-bucket"
  project_id    = local.project_id
  name          = local.gcs_bucket_name
  region        = local.region
  force_destroy = local.force_destroy
}

# *************************************************************************
#    KMS
# *************************************************************************

resource "google_kms_key_ring" "dataflow_keyring" {
  project  = local.project_id
  name     = "dataflow-keyring"
  location = local.region

  depends_on = [
    google_project_service.gcp_services
  ]
}

resource "google_kms_crypto_key" "dataflow_key" {
  name            = "dataflow-crypto-key"
  key_ring        = google_kms_key_ring.dataflow_keyring.id
  rotation_period = "86400s" // Every 24hs

  lifecycle {
    prevent_destroy = true
  }
}

# *************************************************************************
#    Dataflow
# *************************************************************************

// Usage example
module "dataflow_job" {
  source     = "./modules/dataflow"
  project_id = local.project_id
  region     = local.region
  zone       = local.zone

  service_account_email = google_service_account.service_account.email

  name         = "wordcount-terraform-example"
  on_delete    = "cancel"
  max_workers  = 1
  machine_type = "n1-standard-1"

  template_gcs_path = "gs://dataflow-templates/latest/Word_Count"
  temp_gcs_location = module.dataflow_bucket.name

  network    = module.vpc.network_name
  subnetwork = module.vpc.subnets_names[0]

  parameters = {
    inputFile = "gs://dataflow-samples/shakespeare/kinglear.txt"
    output    = "gs://${local.gcs_bucket_name}/output/my_output"
  }

  kms_key_name = google_kms_crypto_key.dataflow_key.id

  labels = {
    optional-key   = "optional-value",
    optional-key-2 = "optional-value-2",
  }

  depends_on = [
    google_project_service.gcp_services
  ]
}