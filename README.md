# بدر فورج — Badr Forge

مصنع مشاريع: من وصف المشروع إلى Blueprint ثم مشروع Next.js جاهز للنشر.

## المحتويات

- **`projects/badr-forge-server/`** — خادم Next.js (API + واجهة Forge)
- **`خطة-العمل-بدر-فورج.md`** — خطة العمل المنهجية (المراحل 0–5 + الربط بالواجهة)
- **`المرحلة-0-التقرير.md`**، **`المرحلة-2-التقرير.md`**، **`تحقق-المراحل-0-1-2.md`** — تقارير تحقق

## التشغيل السريع

```bash
cd projects/badr-forge-server
cp .env.example .env.local   # ثم ضع CLAUDE_API_KEY
npm install
npm run dev
```

افتح http://localhost:3000 واستخدم واجهة Forge لبدء التوليد.

## رفع المشروع على GitHub

بعد إنشاء مستودع جديد على GitHub (فارغ، بدون README):

```bash
cd c:\Users\b.alsalman\b11
git remote add origin https://github.com/YOUR_USERNAME/badr-forge.git
git branch -M main
git push -u origin main
```

استبدل `YOUR_USERNAME/badr-forge` برابط المستودع الفعلي.
