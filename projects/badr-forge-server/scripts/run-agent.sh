#!/bin/bash
# سكربت تشغيل الوكيل المنفذ (Linux / Kwork)
# الاستخدام: JOBS_DIR=/path/to/jobs ./scripts/run-agent.sh <jobId>

JOB_ID=$1
JOBS_BASE="${JOBS_DIR:-/home/user/jobs}"
JOB_DIR="$JOBS_BASE/$JOB_ID"
PROJECT_DIR="$JOB_DIR/project"
BLUEPRINT="$JOB_DIR/blueprint.json"
LOG_FILE="$JOB_DIR/logs.txt"

if [ ! -f "$BLUEPRINT" ]; then
  echo "[$(date -Iseconds)] ❌ لا يوجد blueprint.json للمهمة $JOB_ID" >> "$LOG_FILE"
  exit 1
fi

mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR" || exit 1

echo "[$(date -Iseconds)] تهيئة Next.js..." >> "$LOG_FILE"
npx create-next-app@latest . --typescript --app --tailwind --eslint --no-git --yes 2>&1 >> "$LOG_FILE"

echo "[$(date -Iseconds)] تثبيت Prisma..." >> "$LOG_FILE"
npm install prisma @prisma/client 2>&1 >> "$LOG_FILE"
npx prisma init 2>&1 >> "$LOG_FILE"

echo "[$(date -Iseconds)] 🚀 بدء تنفيذ البلوبرنت عبر Aider..." >> "$LOG_FILE"
BLUEPRINT_CONTENT=$(cat "$BLUEPRINT")
aider \
  --message "اقرأ محتوى البلوبرنت التالي وابنِ المشروع كاملاً بناءً عليه. البلوبرنت: $BLUEPRINT_CONTENT" \
  --yes \
  --auto-commits \
  --no-auto-lint \
  --model claude-sonnet-4-20250514 \
  2>&1 >> "$LOG_FILE"

echo "[$(date -Iseconds)] ✅ انتهى الوكيل من التنفيذ" >> "$LOG_FILE"

# المرحلة 4: حلقة التصحيح الذاتي (auto-fix)
AUTO_FIX_EXIT=0
if [ -x "$(command -v bash)" ] && [ -f "$(dirname "$0")/auto-fix.sh" ]; then
  echo "[$(date -Iseconds)] تشغيل auto-fix للمهمة $JOB_ID..." >> "$LOG_FILE"
  JOBS_DIR="$JOBS_BASE" bash "$(dirname "$0")/auto-fix.sh" "$JOB_ID"
  AUTO_FIX_EXIT=$?
fi

# المرحلة 5: النشر التلقائي (deploy) — اختيارياً إذا FORGE_RUN_DEPLOY=1 وكانت نتيجة auto-fix ناجحة
if [ "$AUTO_FIX_EXIT" -eq 0 ] && [ "$FORGE_RUN_DEPLOY" = "1" ] && [ -f "$(dirname "$0")/deploy.sh" ]; then
  echo "[$(date -Iseconds)] تشغيل deploy للمهمة $JOB_ID..." >> "$LOG_FILE"
  JOBS_DIR="$JOBS_BASE" bash "$(dirname "$0")/deploy.sh" "$JOB_ID"
fi

exit $AUTO_FIX_EXIT
