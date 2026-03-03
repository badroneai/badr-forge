# سكربت حلقة التصحيح الذاتي (Windows)
# الاستخدام:
#   $env:JOBS_DIR = "c:\path\to\jobs"
#   .\scripts\auto-fix.ps1 -JobId "abc12345"

param([Parameter(Mandatory = $true)][string]$JobId)

$JobsBase = if ($env:JOBS_DIR) { $env:JOBS_DIR } else { Join-Path (Get-Location) "..\..\jobs" }
$JobDir = Join-Path $JobsBase $JobId
$ProjectDir = Join-Path $JobDir "project"
$LogFile = Join-Path $JobDir "logs.txt"
$StatusFile = Join-Path $JobDir "status.json"

function Log { param([string]$Msg); $ts = (Get-Date).ToString("o"); "[$ts] $Msg" | Out-File -FilePath $LogFile -Append -Encoding utf8 }

if (-not (Test-Path $ProjectDir)) {
  Log "ERROR: no project folder for job $JobId"
  exit 1
}

Set-Location $ProjectDir

$MaxAttempts = 5
$Attempt = 0

while ($Attempt -lt $MaxAttempts) {
  $Attempt++
  Log "Build attempt $Attempt of $MaxAttempts..."

  $buildOutput = npx next build 2>&1
  $buildExit = $LASTEXITCODE

  if ($buildExit -eq 0) {
    Log "Build succeeded on attempt $Attempt"
    Set-Content -Path $StatusFile -Value ("{`"status`":`"build_success`",`"attempts`":$Attempt}") -Encoding UTF8
    exit 0
  }

  Log "Build failed on attempt $Attempt"
  $errorLines = $buildOutput | Select-Object -Last 20
  Log "Last 20 lines of error:"
  $errorLines | ForEach-Object { Log $_ }

  # إذا كان aider متاحاً في PATH ومفتاح ANTHROPIC_API_KEY موجود، نحاول الإصلاح
  $aiderPath = Get-Command "aider" -ErrorAction SilentlyContinue
  if ($aiderPath -and $env:ANTHROPIC_API_KEY) {
    Log "Trying Aider to fix build error..."
    $msg = "npm run build failed. Fix the project. Error:`n" + ($errorLines -join "`n")
    aider --message $msg --yes --auto-commits --no-auto-lint --model claude-sonnet-4-20250514 2>&1 | ForEach-Object { Log $_ }
  }
  else {
    Log "(simulation) Aider not available; retrying without auto-fix."
  }

  Start-Sleep -Seconds 3
}

Log "Build failed after $MaxAttempts attempts"
Set-Content -Path $StatusFile -Value ("{`"status`":`"build_failed`",`"attempts`":$MaxAttempts}") -Encoding UTF8
exit 1

