param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("origin", "reactive", "escrow", "configure")]
    [string]$Stage
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repo

$envFile = Join-Path $repo ".env"
if (-not (Test-Path $envFile)) {
    throw "Missing .env. Copy .env.example to .env and fill in the deployment addresses."
}

# Load only non-empty dotenv values into this PowerShell process.
foreach ($line in Get-Content $envFile) {
    if ($line -match '^\s*#' -or $line -notmatch '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') {
        continue
    }
    $key = $matches[1]
    $value = $matches[2].Trim()
    if ($value.Length -ge 2 -and $value.StartsWith('"') -and $value.EndsWith('"')) {
        $value = $value.Substring(1, $value.Length - 2)
    }
    if (-not [string]::IsNullOrWhiteSpace($value)) {
        [Environment]::SetEnvironmentVariable($key, $value, "Process")
    }
}

$account = $env:FOUNDRY_ACCOUNT
if ([string]::IsNullOrWhiteSpace($account)) {
    throw "Set FOUNDRY_ACCOUNT in .env to a locally configured Foundry account alias before running a deployment stage."
}
$baseRpc = if ([string]::IsNullOrWhiteSpace($env:BASE_SEPOLIA_RPC_URL)) { "https://sepolia.base.org" } else { $env:BASE_SEPOLIA_RPC_URL }
$reactiveRpc = if ([string]::IsNullOrWhiteSpace($env:REACTIVE_LASNA_RPC_URL)) { "https://lasna-rpc.rnk.dev/" } else { $env:REACTIVE_LASNA_RPC_URL }

function Assert-Chain([string]$Rpc, [string]$Expected) {
    $actualOutput = & cast chain-id --rpc-url $Rpc 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "RPC preflight failed for $Rpc : $actualOutput"
    }
    $actual = ($actualOutput | Select-Object -Last 1).ToString().Trim()
    if ($actual -ne $Expected) {
        throw "Wrong chain at $Rpc. Expected $Expected, got $actual. No transaction sent."
    }
    Write-Host "RPC preflight PASS: chain $actual"
}

function Require-Value([string]$Name, [string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "Set $Name in .env before running stage '$Stage'."
    }
}

function Invoke-Deployment([string]$Target, [string]$Rpc, [string]$Chain) {
    Assert-Chain $Rpc $Chain
    Write-Host "Stage: $Stage | Account: $account | Chain: $Chain"
    Write-Host "Foundry will simulate first, then broadcast only if simulation succeeds."
    & forge script $Target --rpc-url $Rpc --account $account --broadcast
    if ($LASTEXITCODE -ne 0) {
        throw "Forge script failed at stage '$Stage'."
    }
}

switch ($Stage) {
    "origin" {
        Invoke-Deployment "script/DeployOrigin.s.sol:DeployOrigin" $baseRpc "84532"
    }
    "reactive" {
        Require-Value "ORIGIN_CONTRACT_ADDRESS" $env:ORIGIN_CONTRACT_ADDRESS
        Invoke-Deployment "script/DeployReactive.s.sol:DeployReactive" $reactiveRpc "5318007"
    }
    "escrow" {
        Require-Value "REACTIVE_CONTRACT_ADDRESS" $env:REACTIVE_CONTRACT_ADDRESS
        Invoke-Deployment "script/DeployEscrow.s.sol:DeployEscrow" $baseRpc "84532"
    }
    "configure" {
        Require-Value "REACTIVE_CONTRACT_ADDRESS" $env:REACTIVE_CONTRACT_ADDRESS
        Require-Value "SETTLEMENT_ESCROW_ADDRESS" $env:SETTLEMENT_ESCROW_ADDRESS
        Invoke-Deployment "script/ConfigureReactive.s.sol:ConfigureReactive" $reactiveRpc "5318007"
    }
}
