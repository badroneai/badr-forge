# سكربت تشغيل الوكيل المنفذ (Windows)
# الاستخدام: $env:JOBS_DIR = "c:\path\to\jobs"; .\scripts\run-agent.ps1 -JobId "abc12345"

param([Parameter(Mandatory=$true)][string]$JobId)

$JobsBase = if ($env:JOBS_DIR) { $env:JOBS_DIR } else { Join-Path (Get-Location) "..\..\jobs" }
$JobDir = Join-Path $JobsBase $JobId
$ProjectDir = Join-Path $JobDir "project"
$BlueprintPath = Join-Path $JobDir "blueprint.json"
$LogFile = Join-Path $JobDir "logs.txt"

function Log { param([string]$Msg); $ts = (Get-Date).ToString("o"); Add-Content -Path $LogFile -Value "[$ts] $Msg" }

if (-not (Test-Path $BlueprintPath)) {
  Log "لا يوجد blueprint.json للمهمة $JobId"
  exit 1
}

New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null
Set-Location $ProjectDir

Log "تهيئة Next.js..."
npx create-next-app@latest . --typescript --app --tailwind --eslint --no-git --yes 2>&1 | Add-Content -Path $LogFile

Log "تثبيت Prisma..."
npm install prisma @prisma/client 2>&1 | Add-Content -Path $LogFile
npx prisma init 2>&1 | Add-Content -Path $LogFile

Log "بدء تنفيذ البلوبرنت عبر Aider..."
$blueprintContent = Get-Content $BlueprintPath -Raw
aider --message "اقرأ محتوى البلوبرنت وابنِ المشروع بناءً عليه. البلوبرنت: $blueprintContent" --yes --auto-commits --no-auto-lint --model claude-sonnet-4-20250514 2>&1 | Add-Content -Path $LogFile

Log "انتهى الوكيل من التنفيذ"

# المرحلة 4: حلقة التصحيح الذاتي (auto-fix)
$autoFixPath = Join-Path (Split-Path $MyInvocation.MyCommand.Path) "auto-fix.ps1"
$autoFixExit = 0
if (Test-Path $autoFixPath) {
  Log "تشغيل auto-fix للمهمة $JobId..."
  $env:JOBS_DIR = $JobsBase
  & $autoFixPath -JobId $JobId
  $autoFixExit = $LASTEXITCODE
}

# المرحلة 5: النشر التلقائي (deploy) — اختيارياً إذا FORGE_RUN_DEPLOY=1 ونجح auto-fix
$deployPath = Join-Path (Split-Path $MyInvocation.MyCommand.Path) "deploy.ps1"
if (($autoFixExit -eq 0) -and $env:FORGE_RUN_DEPLOY -eq "1" -and (Test-Path $deployPath)) {
  Log "تشغيل deploy للمهمة $JobId..."
  $env:JOBS_DIR = $JobsBase
  & $deployPath -JobId $JobId
}

exit $autoFixExit
