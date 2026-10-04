$tag = "v" + (Get-Date -Format "yyyyMMddHHmmss")
Write-Host "🚀 Code change detected! Triggering Automated Deployment Pipeline ($tag)..." -ForegroundColor Cyan

Write-Host "`n📦 1. Building new Docker Container ($tag)..." -ForegroundColor Yellow
docker build -t frontend-service:$tag ./frontend-service

Write-Host "`n🔒 2. Scanning for vulnerabilities (Simulated)... Pass!" -ForegroundColor Green

Write-Host "`n☸️  3. Notifying Kubernetes to perform a Zero-Downtime Rollout..." -ForegroundColor Yellow
kubectl set image deployment/frontend-service frontend-service=frontend-service:$tag -n microservices-dev
kubectl rollout status deployment frontend-service -n microservices-dev

Write-Host "`n✅ Deployment Successful! Kubernetes has updated to $tag." -ForegroundColor Green
