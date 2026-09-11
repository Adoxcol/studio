param(
  [Parameter(Mandatory = $true)]
  [string]$Path
)

$ErrorActionPreference = 'Stop'

if (
  -not $env:WINDOWS_SIGNTOOL_PATH -or
  -not $env:WINDOWS_SIGN_TIMESTAMP_URL -or
  -not $env:WINDOWS_SIGN_CERT_BASE64 -or
  -not $env:WINDOWS_SIGN_CERT_PASSWORD
) {
  Write-Warning 'Windows signing configuration is absent; leaving the release unsigned.'
  exit 0
}

$cert = Join-Path $env:RUNNER_TEMP 'studio-signing.pfx'
[IO.File]::WriteAllBytes(
  $cert,
  [Convert]::FromBase64String($env:WINDOWS_SIGN_CERT_BASE64)
)
try {
  Get-ChildItem -Path $Path -Recurse -File |
    Where-Object { $_.Extension -in '.exe', '.dll' } |
    ForEach-Object {
      & $env:WINDOWS_SIGNTOOL_PATH sign `
        /fd sha256 /td sha256 `
        /tr $env:WINDOWS_SIGN_TIMESTAMP_URL `
        /f $cert /p $env:WINDOWS_SIGN_CERT_PASSWORD `
        $_.FullName
      if ($LASTEXITCODE -ne 0) { throw "Signing failed: $($_.FullName)" }
      & $env:WINDOWS_SIGNTOOL_PATH verify /pa $_.FullName
      if ($LASTEXITCODE -ne 0) { throw "Signature verification failed: $($_.FullName)" }
    }
} finally {
  Remove-Item $cert -Force -ErrorAction SilentlyContinue
}
