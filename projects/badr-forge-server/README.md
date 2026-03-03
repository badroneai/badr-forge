# Badr Forge Server

خادم وسيط لتوليد Blueprints ومشاريع Next.js (بدر فورج).

## خطوات التشغيل الأولى

يُنصح بتشغيل سكربت التحقق من البيئة قبل التشغيل لأول مرة:

1. **التحقق من البيئة**
   - **Windows (PowerShell):** من مجلد الخادم `projects/badr-forge-server`:
     ```powershell
     .\scripts\check-env.ps1
     ```
   - **Linux / macOS:**
     ```bash
     chmod +x scripts/check-env.sh
     ./scripts/check-env.sh
     ```
   السكربت يتحقق من: Node.js، npm، مجلد `jobs/` (وينشئه إن لم يوجد)، ووجود `.env.local` مع `CLAUDE_API_KEY`. إن ظهرت أخطاء، أصلحها قبل المتابعة.

2. **إعداد المفتاح:**  
   انسخ `.env.example` إلى `.env.local` في مجلد الخادم وضع مفتاح Claude:
   ```
   CLAUDE_API_KEY=sk-ant-xxxxx
   ```

3. **تثبيت التبعيات (مرة واحدة):**
   ```bash
   cd projects/badr-forge-server
   npm install
   ```

4. **تشغيل الخادم:**
   ```bash
   npm run dev
   ```

5. **الوصول:**  
   - الصفحة الرئيسية: http://localhost:3000  
   - بدء مهمة: `POST http://localhost:3000/api/forge/run`  
   - حالة مهمة: `GET http://localhost:3000/api/forge/status/{jobId}`

## اختبار الـ API (بعد التشغيل)

استبدل `JOB_ID_HERE` بـ الـ jobId الذي يعيده طلب البدء.

### بدء مهمة (POST)

**curl (Bash / WSL):**
```bash
curl -X POST http://localhost:3000/api/forge/run \
  -H "Content-Type: application/json" \
  -d '{"projectName":"تطبيق تجريبي","description":"تطبيق ويب بسيط","features":["تسجيل دخول","لوحة تحكم"]}'
# النجاح: {"jobId":"xxxxxxxx","status":"started"}
```

**PowerShell:**
```powershell
$body = @{ projectName = "تطبيق تجريبي"; description = "تطبيق ويب بسيط"; features = @("تسجيل دخول","لوحة تحكم") } | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:3000/api/forge/run" -Method POST -Body $body -ContentType "application/json"
```

### استعلام الحالة (GET)

**curl:**
```bash
curl http://localhost:3000/api/forge/status/JOB_ID_HERE
```

**PowerShell:**
```powershell
Invoke-RestMethod -Uri "http://localhost:3000/api/forge/status/JOB_ID_HERE" -Method GET
```

### اختبار التحقق من المدخلات (يجب أن يعيد 400)

**اسم مشروع فارغ:**
```bash
curl -X POST http://localhost:3000/api/forge/run -H "Content-Type: application/json" -d '{"projectName":"","description":"وصف"}'
```
**PowerShell:** `Invoke-RestMethod ... -Body '{"projectName":"","description":"وصف"}' ...` — يتوقع `400` ورسالة "اسم المشروع مطلوب".

## المرحلة 3: تشغيل الوكيل (Aider)

بعد جاهزية البلوبرنت يمكن للخادم تشغيل الوكيل لبناء المشروع فعلياً في `jobs/{jobId}/project/`.

1. **تثبيت Aider:** `pip install aider-chat`
2. **مفتاح الوكيل:** تعيين `ANTHROPIC_API_KEY` في البيئة (نفس مفتاح Claude أو مفتاح منفصل).
3. **تفعيل التشغيل التلقائي:** في `.env.local` أضف `FORGE_RUN_AGENT=1` لتفعيل تشغيل run-agent بعد كل blueprint_ready.
4. **بدون تفعيل:** إذا لم تضف `FORGE_RUN_AGENT=1` تبقى الحالة عند `blueprint_ready` ولا يُشغّل الوكيل (مناسب عندما Aider غير مثبت).

تشغيل يدوي للوكيل على مهمة جاهزة:
- **Windows:** `$env:JOBS_DIR="c:\Users\b.alsalman\b11\jobs"; .\scripts\run-agent.ps1 -JobId 615805be`
- **Linux:** `JOBS_DIR=/path/to/jobs ./scripts/run-agent.sh 615805be`

## المرحلة 4: حلقة التصحيح الذاتي (Auto-Fix)

بعد انتهاء الوكيل من كتابة المشروع في `project/`، يتم تشغيل سكربت auto-fix:

- **Linux:** يستدعي `scripts/auto-fix.sh` تلقائياً من `run-agent.sh`.
- **Windows:** يستدعي `scripts/auto-fix.ps1` تلقائياً من `run-agent.ps1`.

ما يفعله auto-fix:
- تشغيل `npm run build` حتى 5 مرات كحد أقصى.
- عند النجاح: يكتب في `status.json` حالة `build_success` مع عدد المحاولات.
- عند الفشل: يكتب `build_failed` بعد 5 محاولات.
- إذا كان Aider مثبتاً ومفتاح `ANTHROPIC_API_KEY` موجوداً:
  - يرسل آخر 20 سطر من خطأ الـ build إلى Aider لمحاولة الإصلاح.
- إذا لم يكن Aider متوفراً:
  - يعمل في وضع **محاكاة** (يسجّل في `logs.txt` أنه يعيد المحاولة بدون إصلاح آلي).

تشغيل auto-fix يدوياً على مشروع موجود:
- **Windows:** `$env:JOBS_DIR="c:\Users\b.alsalman\b11\jobs"; .\scripts\auto-fix.ps1 -JobId 615805be`
- **Linux:** `JOBS_DIR=/path/to/jobs ./scripts/auto-fix.sh 615805be`

## الربط بالواجهة (Forge UI)

الصفحة الرئيسية `http://localhost:3000` تعرض واجهة Forge:
- نموذج: اسم المشروع، الوصف، الميزات (اختياري).
- زر «ابدأ التوليد» يرسل POST `/api/forge/run`.
- بعد الإرسال: عرض jobId وتحديث الحالة تلقائياً كل 4 ثوانٍ (polling).
- عند الحالة `deployed`: عرض رابط المشروع المنشور.

## هيكل المشروع

- `app/page.tsx` — الصفحة الرئيسية (تعرض Forge UI)
- `app/components/ForgeUI.tsx` — مكوّن الواجهة (نموذج + polling + عرض الرابط)
- `app/api/forge/run/route.ts` — استقبال الطلب، توليد البلوبرنت، وتشغيل الوكيل (إن فُعّل)
- `app/api/forge/status/[jobId]/route.ts` — قراءة حالة المهمة
- `lib/forge-job.ts` — سلسلة الحالات وهيكل مجلد المهمة
- `scripts/check-env.sh` / `check-env.ps1` — التحقق من البيئة قبل التشغيل
- `scripts/run-agent.sh` / `run-agent.ps1` — الوكيل + auto-fix + deploy
- `scripts/auto-fix.sh` / `auto-fix.ps1` — حلقة التصحيح
- `scripts/deploy.sh` / `deploy.ps1` — النشر (Vercel أو محاكاة)
- مجلد المهام: `b11/jobs/`

### هيكل مجلد المهمة (jobs/{jobId}/)

| الملف/المجلد | الغرض |
|--------------|--------|
| `input.json` | مدخلات المستخدم |
| `status.json` | الحالة الحالية (started → generating_blueprint → … → blueprint_ready) |
| `stage1_prd.json` … `stage6_blueprint.json` | مخرجات المراحل |
| `blueprint.json` | البلوبرنت النهائي |
| `logs.txt` | سجل تنفيذ المهمة (مع طابع زمني) |
| `project/` | المشروع المبني (من Sprint 3) |
