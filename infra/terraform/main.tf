# HappyDiet — GCP infrastructure (APIs, Firestore, IAM)
# Deploy: terraform init && terraform plan && terraform apply
# Cloud Run deployment is handled by CI/CD (GitHub Actions / Cloud Build)

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "aiplatform.googleapis.com",
    "firestore.googleapis.com",
    "texttospeech.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
  ])
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# Firestore database (default)
# location_id: us-central1, nam5, etc. See https://cloud.google.com/firestore/docs/locations
resource "google_firestore_database" "default" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"

  depends_on = [google_project_service.apis]
}

# Service account for CI/CD
resource "google_service_account" "cicd" {
  project      = var.project_id
  account_id   = "happydiet-cicd"
  display_name = "HappyDiet CI/CD"
}

# IAM bindings for CI/CD service account
resource "google_project_iam_member" "cicd_roles" {
  for_each = toset([
    "roles/run.admin",
    "roles/artifactregistry.writer",
    "roles/cloudbuild.builds.builder",
    "roles/iam.serviceAccountUser",
    "roles/aiplatform.user",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

output "project_id" {
  value = var.project_id
}

output "region" {
  value = var.region
}

output "cicd_service_account_email" {
  value       = google_service_account.cicd.email
  description = "Use this SA for GitHub Actions GCP_SA_KEY"
}
