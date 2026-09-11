param(
  [Parameter(Mandatory = $true)]
  [string]$Version,
  [string]$Output = 'dist\windows'
)

$ErrorActionPreference = 'Stop'

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
  throw "Version must be semantic MAJOR.MINOR.PATCH: $Version"
}

$build = 'build\windows\x64\runner\Release'
if (-not (Test-Path $build)) {
  $build = 'build\windows\runner\Release'
}
if (-not (Test-Path (Join-Path $build 'studio.exe'))) {
  throw "Flutter Windows release was not found. Run flutter build windows --release first."
}

New-Item -ItemType Directory -Force $Output | Out-Null
vpk pack `
  --packId 'com.adoxcol.studio' `
  --packTitle 'Studio' `
  --packAuthors 'Adoxcol' `
  --packVersion $Version `
  --packDir $build `
  --mainExe 'studio.exe' `
  --outputDir $Output

$setup = Get-ChildItem -Path $Output -Filter '*Setup.exe' | Select-Object -First 1
if ($null -eq $setup) {
  throw "Velopack did not produce a Setup.exe installer."
}
Copy-Item $setup.FullName (Join-Path $Output 'studio-windows-setup.exe') -Force
