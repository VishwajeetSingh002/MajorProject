#Requires -Version 5.1
<#
.SYNOPSIS
  Local GitOps CD Agent - watches GitHub Actions for successful CI runs and
  auto-deploys changes to the local Kubernetes cluster.

.DESCRIPTION
  Polls the GitHub REST API for the latest workflow run on the main branch.
  When a run completes successfully, it pulls the latest code and runs
  deploy.ps1 to rebuild and redeploy all services.

  For reliable polling, set $env:GITHUB_TOKEN to a GitHub Personal Access Token
  (fine-grained or classic with "repo" or "public_repo" scope). Without a token
  the API is rate-limited to 60 requests/hour.

.PARAMETER PollInterval
  Seconds between API polls. Default 30 (with token) or 60 (without).

.EXAMPLE
  $env:GITHUB_TOKEN = "ghp_xxxx"; .\auto-deploy-agent.ps1
  .\auto-deploy-agent.ps1 -PollInterval 15
#>
param(
    [int]$PollInterval = 0
)

# --- Configuration -----------------------------------------------------------
$Owner = "VishwajeetSingh002"
$Repo  = "MajorProject"
$Branch = "main"
$DeployScript = Join-Path $PSScriptRoot "deploy.ps1"
$ApiUrl = "https://api.github.com/repos/$Owner/$Repo/actions/runs?per_page=10&branch=$Branch&event=push"

# Ensure TLS 1.2 for GitHub API on older PowerShell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Headers ----------------------------------------------------------------
$Headers = @{
    "Accept"    = "application/vnd.github+json"
    "User-Agent" = "auto-deploy-agent-powershell"
}
if ($env:GITHUB_TOKEN) {
    $Headers["Authorization"] = "Bearer $env:GITHUB_TOKEN"
    Write-Host "Using GITHUB_TOKEN for authenticated API access (5000 req/hr)." -ForegroundColor Green
    if ($PollInterval -eq 0) { $PollInterval = 30 }
} else {
    Write-Warning "No GITHUB_TOKEN set. Unauthenticated API calls are rate-limited to 60/hr."
    Write-Host "Set `$env:GITHUB_TOKEN to a GitHub PAT for reliable polling." -ForegroundColor Gray
    if ($PollInterval -eq 0) { $PollInterval = 65 }
}

# --- Helpers ----------------------------------------------------------------
function Get-TimeStamp {
    return "[$(Get-Date -Format 'HH:mm:ss')]"
}

function Invoke-Deploy {
    Write-Host "$(Get-TimeStamp) Pulling latest code from origin/$Branch..." -ForegroundColor Cyan
    git pull --quiet origin $Branch 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "$(Get-TimeStamp) git pull failed. Trying plain pull..." -ForegroundColor Yellow
        git pull --quiet 2>$null
    }

    Write-Host "$(Get-TimeStamp) Running local deployment..." -ForegroundColor Cyan
    & $DeployScript
    if ($LASTEXITCODE -ne 0) {
        Write-Host "$(Get-TimeStamp) deploy.ps1 reported an error (exit $LASTEXITCODE)." -ForegroundColor Red
    }
}

# --- Main Loop ---------------------------------------------------------------
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Local CD Agent (GitOps Mode)" -ForegroundColor Cyan
Write-Host "  Repo: $Owner/$Repo  |  Branch: $Branch" -ForegroundColor Cyan
Write-Host "  Poll interval: ${PollInterval}s" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# On startup, arm with the current latest run so we don't re-deploy old code
$lastProcessedRunId = $null
$pendingRunId = $null

try {
    $initial = Invoke-RestMethod -Uri $ApiUrl -Headers $Headers -ErrorAction Stop
    $initialRuns = @($initial.workflow_runs)
    if ($initialRuns.Count -gt 0) {
        $lastProcessedRunId = $initialRuns[0].id
        Write-Host "$(Get-TimeStamp) [Armed] Tracking from run #$lastProcessedRunId." -ForegroundColor Cyan
        Write-Host "$(Get-TimeStamp) Will deploy on the NEXT successful CI run." -ForegroundColor Gray
    } else {
        Write-Host "$(Get-TimeStamp) No previous runs found. Will deploy on first successful CI." -ForegroundColor Gray
    }
} catch {
    Write-Host "$(Get-TimeStamp) Could not fetch initial runs: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "$(Get-TimeStamp) Agent will retry on next poll cycle." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "$(Get-TimeStamp) Listening for new CI runs..." -ForegroundColor Cyan

while ($true) {
    try {
        $response = Invoke-RestMethod -Uri $ApiUrl -Headers $Headers -ErrorAction Stop
        $runs = @($response.workflow_runs)

        if ($runs.Count -gt 0) {
            $latest = $runs[0]

            # New run we haven't processed or are not already waiting on
            if ($latest.id -ne $lastProcessedRunId -and $latest.id -ne $pendingRunId) {
                if ($latest.status -ne "completed") {
                    Write-Host "$(Get-TimeStamp) New CI run #$($latest.id) started (status: $($latest.status)). Waiting for completion..." -ForegroundColor Yellow
                    $pendingRunId = $latest.id
                } else {
                    # Already completed before we saw it (fast CI)
                    if ($latest.conclusion -eq "success") {
                        Write-Host "$(Get-TimeStamp) CI PASSED for run #$($latest.id)!" -ForegroundColor Green
                        Invoke-Deploy
                    } else {
                        Write-Host "$(Get-TimeStamp) CI $($latest.conclusion.ToUpper()) for run #$($latest.id). Skipping deploy." -ForegroundColor Red
                    }
                    $lastProcessedRunId = $latest.id
                }
            }
            # Check if a pending run has now completed
            elseif ($latest.id -eq $pendingRunId -and $latest.status -eq "completed") {
                if ($latest.conclusion -eq "success") {
                    Write-Host "$(Get-TimeStamp) CI PASSED for run #$($latest.id)!" -ForegroundColor Green
                    Invoke-Deploy
                } else {
                    Write-Host "$(Get-TimeStamp) CI $($latest.conclusion.ToUpper()) for run #$($latest.id). Skipping deploy." -ForegroundColor Red
                }
                $lastProcessedRunId = $latest.id
                $pendingRunId = $null
                Write-Host "$(Get-TimeStamp) Resuming listen mode..." -ForegroundColor Cyan
            }
        }
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 403) {
            Write-Host "$(Get-TimeStamp) API rate limit hit. Backing off 120s..." -ForegroundColor Yellow
            Start-Sleep -Seconds 120
            continue
        }
        Write-Host "$(Get-TimeStamp) Network error: $($_.Exception.Message)" -ForegroundColor DarkGray
    }

    Start-Sleep -Seconds $PollInterval
}
