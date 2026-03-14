# HappyDiet — Terraform Infrastructure

Optional infrastructure-as-code for GCP. Use this for reproducible setup or when you prefer Terraform over bash scripts.

## What it creates

- Enables required APIs (Vertex AI, Firestore, Cloud Run, etc.)
- Creates Firestore (default) database
- Creates `happydiet-cicd` service account with deploy permissions

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- `gcloud auth application-default login`

## Usage

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your project_id

terraform init
terraform plan
terraform apply
```

## After apply

1. Create SA key for GitHub: `gcloud iam service-accounts keys create key.json --iam-account=YOUR_SA_EMAIL`
2. Add to GitHub secrets: `GCP_PROJECT_ID`, `GCP_SA_KEY` (contents of key.json)
3. Run first deploy: `../../scripts/deploy.sh` or push to main

## Note

Cloud Run deployment is done by CI/CD (GitHub Actions or Cloud Build), not Terraform. This Terraform only provisions the supporting infrastructure.
