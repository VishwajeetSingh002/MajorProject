$repoUrl = "https://github.com/VishwajeetSingh002/MajorProject/actions"

Write-Host "🤖 Starting Local CD Agent (GitOps Unlimited Mode)..." -ForegroundColor Cyan
Write-Host "Listening for successful GitHub Actions on $repoUrl..." -ForegroundColor Gray

$lastRunId = ""

while ($true) {
    try {
        $raw = (curl.exe -s $repoUrl) -join "`n"
        if ($raw -match 'actions/runs/(\d+)[\s\S]*?aria-label="([^"]+)"') {
            $latestRunId = $matches[1]
            $statusText = $matches[2]

            if ($lastRunId -eq "") {
                $lastRunId = $latestRunId
                Write-Host "[System Armed] Tracking latest run ID: $lastRunId" -ForegroundColor DarkGray
            }

            if ($latestRunId -ne $lastRunId) {
                if ($statusText -like "*completed successfully*") {
                    Write-Host "`n🎉 SUCCESSFUL CI PIPELINE DETECTED IN CLOUD!" -ForegroundColor Green
                    Write-Host "$statusText" -ForegroundColor Yellow
                    Write-Host "Triggering local automated deployment...`n" -ForegroundColor Yellow

                    # Pull latest code and trigger deployment
                    git pull --quiet
                    .\deploy.ps1

                    $lastRunId = $latestRunId
                    Write-Host "`n🤖 Resuming listening mode..." -ForegroundColor Cyan
                } elseif ($statusText -like "*failed*" -or $statusText -like "*cancelled*") {
                    Write-Host "`n❌ CI PIPELINE FAILED OR CANCELLED IN CLOUD!" -ForegroundColor Red
                    Write-Host "$statusText" -ForegroundColor Red
                    $lastRunId = $latestRunId
                    Write-Host "`n🤖 Resuming listening mode..." -ForegroundColor Cyan
                }
            }
        }
    } catch {
        # Silently continue on momentary network glitches
    }

    Start-Sleep -Seconds 5
}
