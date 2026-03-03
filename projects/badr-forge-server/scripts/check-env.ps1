# Check environment for Badr Forge Server
# Run from: projects/badr-forge-server (e.g. .\scripts\check-env.ps1)

$ErrorCount = 0
$RootDir = Join-Path (Split-Path (Split-Path $MyInvocation.MyCommand.Path)) "..\.."
$JobsDir = Join-Path $RootDir "jobs"
$ProjectsDir = Join-Path $RootDir "projects"
$ServerDir = Split-Path (Split-Path $MyInvocation.MyCommand.Path)
$EnvLocal = Join-Path $ServerDir ".env.local"

Write-Host "Badr Forge - Environment check" -ForegroundColor Cyan
Write-Host ""

# 1. Node.js
try {
  $nodeVer = node -v 2>&1
  if ($LASTEXITCODE -ne 0) { throw "not found" }
  Write-Host "[OK] Node.js: $nodeVer" -ForegroundColor Green
} catch {
  Write-Host "[FAIL] Node.js not found. Install from https://nodejs.org" -ForegroundColor Red
  $ErrorCount++
}

# 2. npm
try {
  $npmVer = npm -v 2>&1
  if ($LASTEXITCODE -ne 0) { throw "not found" }
  Write-Host "[OK] npm: $npmVer" -ForegroundColor Green
} catch {
  Write-Host "[FAIL] npm not found." -ForegroundColor Red
  $ErrorCount++
}

# 3. Python (optional, for Aider)
try {
  $py = $null
  if (Get-Command python -ErrorAction SilentlyContinue) { $py = "python" }
  elseif (Get-Command python3 -ErrorAction SilentlyContinue) { $py = "python3" }
  elseif (Get-Command py -ErrorAction SilentlyContinue) { $py = "py -3" }
  if ($py) {
    $pyVer = Invoke-Expression "$py --version 2>&1"
    Write-Host "[OK] Python (optional): $pyVer" -ForegroundColor Green
  } else {
    Write-Host "[SKIP] Python not found (optional; needed for Aider)" -ForegroundColor Yellow
  }
} catch {
  Write-Host "[SKIP] Python (optional)" -ForegroundColor Yellow
}

# 4. jobs directory
if (Test-Path $JobsDir) {
  try {
    $testFile = Join-Path $JobsDir ".write-test"
    "test" | Set-Content -Path $testFile -Force
    Remove-Item $testFile -Force
    Write-Host "[OK] jobs directory exists and writable: $JobsDir" -ForegroundColor Green
  } catch {
    Write-Host "[FAIL] jobs directory not writable: $JobsDir" -ForegroundColor Red
    $ErrorCount++
  }
} else {
  try {
    New-Item -ItemType Directory -Path $JobsDir -Force | Out-Null
    Write-Host "[OK] jobs directory created: $JobsDir" -ForegroundColor Green
  } catch {
    Write-Host "[FAIL] Could not create jobs directory: $JobsDir" -ForegroundColor Red
    $ErrorCount++
  }
}

# 5. projects directory (optional)
if (Test-Path $ProjectsDir) {
  Write-Host "[OK] projects directory exists: $ProjectsDir" -ForegroundColor Green
} else {
  Write-Host "[SKIP] projects directory not found (optional): $ProjectsDir" -ForegroundColor Yellow
}

# 6. .env.local and CLAUDE_API_KEY
if (-not (Test-Path $EnvLocal)) {
  Write-Host "[FAIL] .env.local not found. Copy from .env.example and set CLAUDE_API_KEY." -ForegroundColor Red
  $ErrorCount++
} else {
  $content = Get-Content $EnvLocal -Raw
  if ($content -match "CLAUDE_API_KEY=\s*(\S+)" -and $Matches[1].Length -gt 10) {
    Write-Host "[OK] .env.local exists and CLAUDE_API_KEY is set" -ForegroundColor Green
  } else {
    Write-Host "[FAIL] .env.local exists but CLAUDE_API_KEY is missing or empty." -ForegroundColor Red
    $ErrorCount++
  }
}

Write-Host ""
if ($ErrorCount -eq 0) {
  Write-Host "All required checks passed. You can run: npm run dev" -ForegroundColor Green
  exit 0
} else {
  Write-Host "$ErrorCount required check(s) failed. Fix them before running the server." -ForegroundColor Red
  exit 1
}
