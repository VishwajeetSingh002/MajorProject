$repo = "VishwajeetSingh002/MajorProject"
$apiUrl = "https://api.github.com/repos/$repo/actions/runs?per_page=1"

Write-Host "🤖 Starting Local CD Agent (GitOps Mode)..." -ForegroundColor Cyan
Write-Host "Listening for successful GitHub Actions on $repo..." -ForegroundColor Gray

$lastRunId = ""

while ($true) {
    try {
        # Fetch the latest GitHub Actions run
        $response = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
        if ($response.workflow_runs.Count -gt 0) {
            $latestRun = $response.workflow_runs[0]
            
            # Initialize tracking on first loop
            if ($lastRunId -eq "") {
                $lastRunId = $latestRun.id
                Write-Host "[System Armed] Tracking latest run ID: $lastRunId" -ForegroundColor DarkGray
            }
            
            # Check if there is a NEW run that just completed successfully
            if ($latestRun.id -ne $lastRunId -and $latestRun.status -eq "completed") {
                
                if ($latestRun.conclusion -eq "success") {
                    Write-Host "`n🎉 SUCCESSFUL CI PIPELINE DETECTED IN CLOUD!" -ForegroundColor Green
                    Write-Host "Triggering local automated deployment...`n" -ForegroundColor Yellow
                    
                    # Execute the deployment script
                    .\deploy.ps1
                } else {
                    Write-Host "`n❌ CI PIPELINE FAILED IN CLOUD!" -ForegroundColor Red
                    Write-Host "Deployment blocked to protect the cluster.`n" -ForegroundColor Red
                }
                
                $lastRunId = $latestRun.id
                Write-Host "`n🤖 Resuming listening mode..." -ForegroundColor Cyan
            }
        }
    } catch {
        # Ignore network blips or API rate limits silently
    }
    
    # Check GitHub every 10 seconds
    Start-Sleep -Seconds 10
}
