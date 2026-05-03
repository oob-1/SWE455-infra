# Read terraform outputs and set the four CI/CD variables in each service
# repo on GitHub:
#   GCP_PROJECT_ID, GCP_REGION, WIF_PROVIDER, DEPLOYER_SA_EMAIL
#
# Run after every `terraform apply` that rotates the random_id suffix
# (i.e. every fresh post-destroy apply), since WIF_PROVIDER changes.
#
# Usage:
#   .\scripts\set-github-vars.ps1

#Requires -Version 5
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InfraDir  = Resolve-Path (Join-Path $ScriptDir "..")
$TfDir     = Join-Path $InfraDir "terraform"

foreach ($cmd in @("terraform", "gh")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        throw "$cmd not found in PATH"
    }
}

& gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "gh is not authenticated; run 'gh auth login' first" }

function Get-TfOutput([string]$name) {
    $val = & terraform "-chdir=$TfDir" output -raw $name
    if ($LASTEXITCODE -ne 0) { throw "terraform output -raw $name failed" }
    return $val
}

$ProjectId          = Get-TfOutput project_id
$Region             = Get-TfOutput region
$WifProvider        = Get-TfOutput wif_provider
$DeployerSaEmail    = Get-TfOutput deployer_sa_email
$Owner              = Get-TfOutput github_owner
$UserManagerRepo    = Get-TfOutput user_manager_repo
$ExpenseServiceRepo = Get-TfOutput expense_service_repo

Write-Host "Setting CI vars from terraform outputs:"
Write-Host "  GCP_PROJECT_ID    = $ProjectId"
Write-Host "  GCP_REGION        = $Region"
Write-Host "  WIF_PROVIDER      = $WifProvider"
Write-Host "  DEPLOYER_SA_EMAIL = $DeployerSaEmail"

function Set-RepoVars([string]$repo) {
    $full = "$Owner/$repo"
    Write-Host ""
    Write-Host "==> $full"
    & gh repo view $full 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "  skip: repo $full not found (have you pushed it to GitHub yet?)"
        return
    }
    & gh variable set GCP_PROJECT_ID    --body $ProjectId       --repo $full
    if ($LASTEXITCODE -ne 0) { throw "gh variable set GCP_PROJECT_ID failed for $full" }
    & gh variable set GCP_REGION        --body $Region          --repo $full
    if ($LASTEXITCODE -ne 0) { throw "gh variable set GCP_REGION failed for $full" }
    & gh variable set WIF_PROVIDER      --body $WifProvider     --repo $full
    if ($LASTEXITCODE -ne 0) { throw "gh variable set WIF_PROVIDER failed for $full" }
    & gh variable set DEPLOYER_SA_EMAIL --body $DeployerSaEmail --repo $full
    if ($LASTEXITCODE -ne 0) { throw "gh variable set DEPLOYER_SA_EMAIL failed for $full" }
}

Set-RepoVars $UserManagerRepo
Set-RepoVars $ExpenseServiceRepo

Write-Host ""
Write-Host "Done."
