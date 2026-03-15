# Service account permissions for HappyDiet backend
# This script grants the necessary permissions to the service account to allow it to deploy the backend to Cloud Run.

# Replace these with your actual values
PROJECT_ID="happydiet-1-490118"
SA_EMAIL=happydiet-cicd@happydiet-1-490118.iam.gserviceaccount.com
REGION="us-central1"

# Grant Cloud Build permission to submit builds
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:$SA_EMAIL \
  --role=roles/cloudbuild.builds.editor

# Grant permission to write logs
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:$SA_EMAIL \
  --role=roles/logging.logWriter

# Grant permission to view/stream logs (fixes gcloud builds submit exit code 1 in GitHub Actions)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:$SA_EMAIL \
  --role=roles/logging.viewer

# Grant permission to deploy to Cloud Run
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:$SA_EMAIL \
  --role=roles/run.admin

# Grant service account user permission
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:$SA_EMAIL \
  --role=roles/iam.serviceAccountUser

  #logging viewer permission
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:$SA_EMAIL \
  --role=roles/logging.viewer

# Allow unauthenticated access (browser / API calls without login)
gcloud run services add-iam-policy-binding happydiet-backend \
  --region=$REGION \
  --member=allUsers \
  --role=roles/run.invoker \
  --project=$PROJECT_ID

gcloud run services add-iam-policy-binding happydiet-backend-dev \
  --region=$REGION \
  --member=allUsers \
  --role=roles/run.invoker \
  --project=$PROJECT_ID

# --- Cloud Run runtime identity (default compute SA) ---
# Cloud Run uses this SA when handling requests. Without these, /analyze-meal fails on cloud but works locally.
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

echo "Granting Vertex AI + Firestore to Cloud Run runtime SA: $COMPUTE_SA"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:$COMPUTE_SA \
  --role=roles/aiplatform.user

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:$COMPUTE_SA \
  --role=roles/datastore.user

# verify the permissions granted to the compute SA
PROJECT_ID="happydiet-1-490118"
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${COMPUTE_SA}" \
  --format="table(bindings.role)"

gcloud run services describe happydiet-backend --region=$REGION --project=$PROJECT_ID --format='value(spec.template.spec.serviceAccountName)'

# Create key for CI (e.g. GCP_SA_KEY in GitHub Actions) — run once, then add to secrets
# gcloud iam service-accounts keys create ~/happydiet-sa-key.json --iam-account=$SA_EMAIL

#allow unauthenticated access to the dev service
gcloud run services add-iam-policy-binding happydiet-backend-dev \
  --region=$REGION \
  --member=allUsers \
  --role=roles/run.invoker \
  --project=$PROJECT_ID

gcloud run services add-iam-policy-binding happydiet-backend-dev \
  --region=us-central1 \
  --member=allUsers \
  --role=roles/run.invoker \
  --project=happydiet-1-490118 