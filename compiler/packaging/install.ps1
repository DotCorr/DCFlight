# dcflight installer (Windows PowerShell).
# Usage:  irm https://github.com/dotcorr/dcflight/releases/latest/download/install.ps1 | iex
# Or:     .\install.ps1 [-Version latest]
param([string]$Version = $env:DCFLIGHT_VERSION, [string]$Repo = $env:DCFLIGHT_REPO)
$ErrorActionPreference = 'Stop'
if (-not $Repo) { $Repo = 'dotcorr/dcflight' }
if (-not $Version) { $Version = 'latest' }

$Root = Join-Path $env:USERPROFILE '.dcflight'
New-Item -ItemType Directory -Force (Join-Path $Root 'bin') | Out-Null

$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command py -ErrorAction SilentlyContinue }
if (-not $py) {
  Write-Host 'Python 3.9+ is required. Install it first:' -ForegroundColor Yellow
  Write-Host '  winget install Python.Python.3.12'
  Write-Host '  (or https://www.python.org/downloads/ - check "Add python.exe to PATH")'
  exit 1
}
if ((Split-Path $py.Source -Leaf) -eq 'py.exe') { $PyCmd = @('py', '-3') } else { $PyCmd = @($py.Source) }
$Prefix = @()
if ($PyCmd.Count -gt 1) { $Prefix = $PyCmd[1..($PyCmd.Count - 1)] }

$Tmp = New-Item -ItemType Directory -Force (Join-Path $env:TEMP 'dcflight-install')
if ($Version -eq 'latest') {
  $Url = "https://github.com/$Repo/releases/latest/download/dcflight_compiler-py3-none-any.whl"
} else {
  $Url = "https://github.com/$Repo/releases/download/$Version/dcflight_compiler-py3-none-any.whl"
}
Write-Host "Downloading $Url"
$Whl = Join-Path $Tmp 'dcflight.whl'
Invoke-WebRequest $Url -OutFile $Whl

& $PyCmd[0] @Prefix -m pip install --user --upgrade $Whl
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Stable launchers in %USERPROFILE%\.dcflight\bin (plain -m module shims).
$Install = @'
import os, sys
from dcflight import __version__
target = sys.argv[1]
os.makedirs(target, exist_ok=True)
py = sys.executable
for name, module in (
    ('dcflight.cmd', 'dcflight.cli'),
    ('dcflight-mcp.cmd', 'dcflight.mcp_server')):
    with open(os.path.join(target, name), 'w', newline='\r\n') as f:
        f.write('@echo off\r\n"%s" -m %s %%*\r\n' % (py, module))
print('installed dcflight', __version__)
'@
& $PyCmd[0] @Prefix -c $Install (Join-Path $Root 'bin')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Add to user PATH (idempotent).
$Bin = Join-Path $Root 'bin'
$UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($UserPath -split ';') -notcontains $Bin) {
  [Environment]::SetEnvironmentVariable('Path', "$UserPath;$Bin", 'User')
}

Write-Host ''
Write-Host 'dcflight installed. Open a NEW terminal so PATH changes apply.'
Write-Host 'Check native toolchains (Android SDK, JDK):   dcflight doctor'
Write-Host 'Auto-install missing dev toolchains (dart):   dcflight doctor --install'
Write-Host 'Create an app:                                dcflight create my-app; cd my-app'
Write-Host 'Wire an MCP agent client:                     dcflight mcp-config --client vscode'
