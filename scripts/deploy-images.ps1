# Build, push, and deploy both microservice images to Artifact Registry +
# Cloud Run, replacing the cloudrun/container/hello placeholder that
# Terraform installs on first apply.
#
# Reads project/region/repo names from `terraform output` so it works in
# any environment Terraform has been applied in.
#
# Usage:
#   .\scripts\deploy-images.ps1                  # both services
#   .\scripts\deploy-images.ps1 user-manager     # one service
#   .\scripts\deploy-images.ps1 expense-service

#Requires -Version 5
[CmdletBinding()]
param(
    [ValidateSet("all", "user-manager", "expense-service")]
    [string]$Service = "all"
)

$ErrorActionPreference = "Stop"

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$InfraDir    = Resolve-Path (Join-Path $ScriptDir "..")
$ProjectRoot = Resolve-Path (Join-Path $InfraDir "..")
$TfDir       = Join-Path $InfraDir "terraform"

foreach ($cmd in @("terraform", "gcloud", "docker")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        throw "$cmd not found in PATH"
    }
}

function Get-TfOutput([string]$name) {
    $val = & terraform "-chdir=$TfDir" output -raw $name
    if ($LASTEXITCODE -ne 0) { throw "terraform output -raw $name failed" }
    return $val
}

$ProjectId = Get-TfOutput project_id
$Region    = Get-TfOutput region
$ArRepo    = Get-TfOutput artifact_registry_repo
$ArHost    = "$Region-docker.pkg.dev"
$ArPath    = "$ArHost/$ProjectId/$ArRepo"

Write-Host "Project: $ProjectId  Region: $Region  AR: $ArPath"

& gcloud auth configure-docker $ArHost --quiet | Out-Null
if ($LASTEXITCODE -ne 0) { throw "gcloud auth configure-docker failed" }

function Deploy-One([string]$folder, [string]$svc) {
    $svcDir = Join-Path $ProjectRoot $folder
    if (-not (Test-Path $svcDir)) { throw "$svcDir not found" }

    Push-Location $svcDir
    try {
        $sha = & git rev-parse --short HEAD 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $sha) {
            $sha = "manual-" + [int64]([DateTime]::UtcNow - [DateTime]"1970-01-01T00:00:00Z").TotalSeconds
        }
    } finally {
        Pop-Location
    }

    $tagged = "${ArPath}/${svc}:${sha}"
    $latest = "${ArPath}/${svc}:latest"

    Write-Host ""
    Write-Host "==> [$svc] build  ($sha)"
    & docker build --platform=linux/amd64 -t $tagged -t $latest $svcDir
    if ($LASTEXITCODE -ne 0) { throw "docker build failed for $svc" }

    Write-Host "==> [$svc] push"
    & docker push $tagged
    if ($LASTEXITCODE -ne 0) { throw "docker push (tagged) failed for $svc" }
    & docker push $latest
    if ($LASTEXITCODE -ne 0) { throw "docker push (latest) failed for $svc" }

    Write-Host "==> [$svc] deploy to Cloud Run"
    & gcloud run deploy $svc --image $tagged --region $Region --project $ProjectId --quiet
    if ($LASTEXITCODE -ne 0) { throw "gcloud run deploy failed for $svc" }
}

switch ($Service) {
    "user-manager"    { Deploy-One "expense-tracker-user-manager"    "user-manager" }
    "expense-service" { Deploy-One "expense-tracker-expense-service" "expense-service" }
    "all" {
        Deploy-One "expense-tracker-user-manager"    "user-manager"
        Deploy-One "expense-tracker-expense-service" "expense-service"
    }
}

Write-Host ""
Write-Host "Done. Service URLs:"
Write-Host "  user-manager   : $(Get-TfOutput user_manager_url)"
Write-Host "  expense-service: $(Get-TfOutput expense_service_url)"
Write-Host "  gateway (use this from clients): $(Get-TfOutput gateway_url)"
