#!/bin/bash
# سكربت حلقة التصحيح الذاتي (Linux / Kwork)
# الاستخدام: JOBS_DIR=/path/to/jobs ./scripts/auto-fix.sh <jobId>

JOB_ID=$1
JOBS_BASE="${JOBS_DIR:-/home/user/jobs}"
JOB_DIR="$JOBS_BASE/$JOB_ID"
PROJECT_DIR="$JOB_DIR/project"
LOG_FILE="$JOB_DIR/logs.txt"
STATUS_FILE="$JOB_DIR/status.json"

MAX_ATTEMPTS=5
ATTEMPT=0

if [ ! -d "$PROJECT_DIR" ]; then
  echo "[$(date -Iseconds)] ❌ لا يوجد مجلد project للمهمة $JOB_ID" >> "$LOG_FILE"
  exit 1
fi

cd "$PROJECT_DIR" || exit 1

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))
  echo "[$(date -Iseconds)] 🔄 محاولة build رقم $ATTEMPT..." >> "$LOG_FILE"

  BUILD_OUTPUT=$(npx next build 2>&1)
  BUILD_EXIT=$?

  if [ $BUILD_EXIT -eq 0 ]; then
    echo "[$(date -Iseconds)] ✅ build نجح في المحاولة $ATTEMPT" >> "$LOG_FILE"
    echo "{\"status\":\"build_success\",\"attempts\":$ATTEMPT}" > "$STATUS_FILE"
    exit 0
  fi

  echo "[$(date -Iseconds)] ❌ فشل build في المحاولة $ATTEMPT" >> "$LOG_FILE"

  # استخراج آخر 20 سطر من الخطأ
  ERROR_MSG=$(echo "$BUILD_OUTPUT" | tail -20)
  echo "[$(date -Iseconds)] آخر 20 سطر من الخطأ:" >> "$LOG_FILE"
  echo "$ERROR_MSG" >> "$LOG_FILE"

  # إذا كان aider متاحاً ومفعلاً، نحاول الإصلاح بالذكاء الاصطناعي
  if command -v aider >/dev/null 2>&1 && [ -n "$ANTHROPIC_API_KEY" ]; then
    echo "[$(date -Iseconds)] 🧠 محاولة إصلاح الخطأ عبر Aider..." >> "$LOG_FILE"
    aider \
      --message "فشل npm run build بالخطأ التالي. أصلح المشروع:\n$ERROR_MSG" \
      --yes \
      --auto-commits \
      --no-auto-lint \
      --model claude-sonnet-4-20250514 \
      2>&1 >> "$LOG_FILE"
  else
    echo "[$(date -Iseconds)] (محاكاة) Aider غير متوفر؛ سيتم إعادة المحاولة بدون إصلاح آلي." >> "$LOG_FILE"
  fi

  # انتظار بسيط قبل المحاولة التالية
  sleep 3
done

echo "[$(date -Iseconds)] ❌ فشل build بعد $MAX_ATTEMPTS محاولات" >> "$LOG_FILE"
echo "{\"status\":\"build_failed\",\"attempts\":$MAX_ATTEMPTS}" > "$STATUS_FILE"
exit 1

