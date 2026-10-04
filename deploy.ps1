<#
.SYNOPSIS
  Builds both microservice Docker images and deploys them to the local
  Kubernetes cluster with zero-downtime rolling updates.

.DESCRIPTION
  1. Builds user-service and frontend-service Docker images
  2. Ensures the target namespace exists
  3. Applies all Kubernetes manifests (app + monitoring)
  4. Restarts both application deployments
  5. Waits for rollouts to complete

  Exits non-zero if a Docker build fails so the auto-deploy agent can report it.
#>

$ErrorActionPreference = "Continue"

function Write-Step {
    param([string]$Tag, [string]$Message)
    Write-Host ""
    Write-Host "[$Tag] $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Fail {
    param([string]$Message)
    Write-Host "  [FAIL] $Message" -ForegroundColor Red
}

# ------------------------------------------------------------------
# 1. Build Docker Images
# ------------------------------------------------------------------
Write-Step "BUILD" "Building Docker images..."

Write-Host "  Building user-service..." -ForegroundColor Gray
docker build -q -t user-service:latest ./user-service 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
if ($LASTEXITCODE -ne 0) {
    Write-Fail "user-service image build failed"
    exit 1
}
Write-Ok "user-service image built"

Write-Host "  Building frontend-service..." -ForegroundColor Gray
docker build -q -t frontend-service:latest ./frontend-service 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
if ($LASTEXITCODE -ne 0) {
    Write-Fail "frontend-service image build failed"
    exit 1
}
Write-Ok "frontend-service image built"

# ------------------------------------------------------------------
# 2. Ensure namespace exists (idempotent)
# ------------------------------------------------------------------
Write-Step "K8S" "Ensuring Kubernetes namespace exists..."

kubectl create namespace microservices-dev --dry-run=client -o yaml 2>$null | kubectl apply -f - 2>&1 | Out-Null
Write-Ok "Namespace microservices-dev ready"

# ------------------------------------------------------------------
# 3. Apply all Kubernetes manifests
# ------------------------------------------------------------------
Write-Step "APPLY" "Applying Kubernetes manifests..."

kubectl apply -f ./k8s/configmap.yaml                  2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
kubectl apply -f ./k8s/user-service-deployment.yaml     2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
kubectl apply -f ./k8s/frontend-service-deployment.yaml 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

Write-Step "MONITOR" "Applying monitoring stack..."
Get-ChildItem ./monitoring/*.yaml | ForEach-Object {
    kubectl apply -f $_.FullName 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
}
Write-Ok "All manifests applied"

# ------------------------------------------------------------------
# 4. Restart application deployments (triggers rolling update)
# ------------------------------------------------------------------
Write-Step "RESTART" "Restarting deployments for rolling update..."

kubectl rollout restart deployment/user-service    -n microservices-dev
kubectl rollout restart deployment/frontend-service -n microservices-dev

# ------------------------------------------------------------------
# 5. Wait for rollouts to complete
# ------------------------------------------------------------------
Write-Step "WAIT" "Waiting for rollouts to complete..."

Write-Host "  Waiting for user-service..." -ForegroundColor Gray
kubectl rollout status deployment/user-service -n microservices-dev --timeout=180s
if ($LASTEXITCODE -ne 0) {
    Write-Fail "user-service rollout timed out or failed"
} else {
    Write-Ok "user-service rollout complete"
}

Write-Host "  Waiting for frontend-service..." -ForegroundColor Gray
kubectl rollout status deployment/frontend-service -n microservices-dev --timeout=180s
if ($LASTEXITCODE -ne 0) {
    Write-Fail "frontend-service rollout timed out or failed"
} else {
    Write-Ok "frontend-service rollout complete"
}

# ------------------------------------------------------------------
# Done
# ------------------------------------------------------------------
Write-Host ""
Write-Host "[DONE] Deployment complete! Changes are live in the cluster." -ForegroundColor Green
Write-Host "       Frontend: http://localhost:3000" -ForegroundColor Gray
Write-Host "       User API: http://localhost:8000" -ForegroundColor Gray
Write-Host "       Grafana:  http://localhost:3001  (admin / admin)" -ForegroundColor Gray
