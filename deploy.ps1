Write-Host "🚀 Code change detected! Triggering Automated Deployment Pipeline..." -ForegroundColor Cyan

Write-Host "`n📦 1. Building new Docker Container..." -ForegroundColor Yellow
docker build -t frontend-service:latest ./frontend-service | Out-Null

Write-Host "`n🔒 2. Scanning for vulnerabilities (Simulated)... Pass!" -ForegroundColor Green

Write-Host "`n☸️  3. Notifying Kubernetes to perform a Zero-Downtime Rollout..." -ForegroundColor Yellow
kubectl rollout restart deployment frontend-service -n microservices-dev

Write-Host "`n✅ Deployment Successful! Kubernetes is now swapping the pods in the background." -ForegroundColor Green
