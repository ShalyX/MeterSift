param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^0x[0-9a-fA-F]{40}$')]
    [string]$Wallet,

    [decimal]$Amount = 0.1,

    [string]$Account = $env:FOUNDRY_ACCOUNT
)

$ErrorActionPreference = "Stop"
$rpc = "https://sepolia.base.org"
$faucet = "0x2afaFD298b23b62760711756088F75B7409f5967"
if ([string]::IsNullOrWhiteSpace($Account)) {
    throw "Pass -Account or set FOUNDRY_ACCOUNT to a locally configured Foundry account alias. No default account is assumed."
}
$log = Join-Path $env:TEMP "reactive-testnet-faucet.log"

if ($Amount -le 0 -or $Amount -gt 5) {
    throw "Amount must be greater than zero and no more than 5 Base Sepolia ETH."
}

$chain = (& cast chain-id --rpc-url $rpc --rpc-timeout 15 | Select-Object -Last 1).ToString().Trim()
if ($LASTEXITCODE -ne 0 -or $chain -ne "84532") {
    throw "Base Sepolia chain check failed. No transaction sent."
}

Write-Host "Reactive Lasna testnet faucet"
Write-Host "Wallet: $Wallet"
Write-Host "Network: Base Sepolia (84532)"
Write-Host "Request: $Amount test ETH -> approximately $([double]$Amount * 100) lREACT"
Write-Host "Faucet: $faucet"
Write-Host "The Foundry keystore password is entered locally at the prompt; it is not stored."
Write-Host ""

Start-Transcript -Path $log -Append | Out-Null
try {
    $value = $Amount.ToString([Globalization.CultureInfo]::InvariantCulture) + "ether"
    & cast send $faucet "request(address)" $Wallet --value $value --rpc-url $rpc --account $Account
    if ($LASTEXITCODE -ne 0) {
        throw "Faucet transaction failed."
    }
    Write-Host ""
    Write-Host "FAUCET_REQUEST_SUBMITTED"
    Write-Host "Check the Lasna balance after the Reactive callback is processed."
}
finally {
    Stop-Transcript | Out-Null
}
Read-Host "Press Enter to close this window"
