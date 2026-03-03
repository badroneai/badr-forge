"use client";

import { useState, useCallback, useEffect } from "react";

type JobStatus = {
  status: string;
  jobId?: string;
  currentStage?: string;
  url?: string;
  deployedAt?: string;
  error?: string;
  completedAt?: string;
};

const POLL_INTERVAL_MS = 4000;
const TERMINAL_STATUSES = ["blueprint_ready", "build_success", "build_failed", "deployed", "error"];

export default function ForgeUI() {
  const [projectName, setProjectName] = useState("");
  const [description, setDescription] = useState("");
  const [features, setFeatures] = useState("");
  const [loading, setLoading] = useState(false);
  const [jobId, setJobId] = useState<string | null>(null);
  const [status, setStatus] = useState<JobStatus | null>(null);
  const [error, setError] = useState<string | null>(null);

  const fetchStatus = useCallback(async (id: string) => {
    const res = await fetch(`/api/forge/status/${id}`);
    if (!res.ok) return null;
    return (await res.json()) as JobStatus;
  }, []);

  useEffect(() => {
    if (!jobId || !status || TERMINAL_STATUSES.includes(status.status)) return;
    const t = setInterval(async () => {
      const next = await fetchStatus(jobId);
      if (next) setStatus(next);
    }, POLL_INTERVAL_MS);
    return () => clearInterval(t);
  }, [jobId, status, fetchStatus]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setStatus(null);
    setJobId(null);
    setLoading(true);
    try {
      const body: { projectName: string; description: string; features?: string[] } = {
        projectName: projectName.trim() || "مشروع",
        description: description.trim() || "",
      };
      if (features.trim()) body.features = features.split(/[,،]/).map((s) => s.trim()).filter(Boolean);
      const res = await fetch("/api/forge/run", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      const data = (await res.json()) as { jobId?: string; status?: string; error?: string };
      if (!res.ok) {
        setError(data.error || "فشل الطلب");
        return;
      }
      if (data.jobId) {
        setJobId(data.jobId);
        const initial = await fetchStatus(data.jobId);
        if (initial) setStatus(initial);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "خطأ في الاتصال");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-zinc-50 dark:bg-zinc-950 text-zinc-900 dark:text-zinc-100 p-6 md:p-10">
      <div className="max-w-2xl mx-auto">
        <h1 className="text-2xl font-bold mb-2">بدر فورج</h1>
        <p className="text-zinc-600 dark:text-zinc-400 mb-8">أدخل بيانات المشروع ثم اضغط ابدأ التوليد. سنولّد البلوبرنت ثم نتابع الحالة حتى النشر.</p>

        <form onSubmit={handleSubmit} className="space-y-4 mb-8">
          <div>
            <label className="block text-sm font-medium mb-1">اسم المشروع</label>
            <input
              type="text"
              value={projectName}
              onChange={(e) => setProjectName(e.target.value)}
              placeholder="مثال: تطبيق المهام"
              className="w-full rounded-lg border border-zinc-300 dark:border-zinc-600 bg-white dark:bg-zinc-900 px-3 py-2"
            />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">الوصف</label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="وصف مختصر للمشروع"
              rows={3}
              className="w-full rounded-lg border border-zinc-300 dark:border-zinc-600 bg-white dark:bg-zinc-900 px-3 py-2"
            />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">الميزات (اختياري، مفصولة بفاصلة)</label>
            <input
              type="text"
              value={features}
              onChange={(e) => setFeatures(e.target.value)}
              placeholder="قوائم، بحث، تصفية"
              className="w-full rounded-lg border border-zinc-300 dark:border-zinc-600 bg-white dark:bg-zinc-900 px-3 py-2"
            />
          </div>
          {error && <p className="text-red-600 dark:text-red-400 text-sm">{error}</p>}
          <button
            type="submit"
            disabled={loading}
            className="rounded-lg bg-zinc-900 dark:bg-zinc-100 text-white dark:text-zinc-900 px-4 py-2 font-medium disabled:opacity-50"
          >
            {loading ? "جاري الإرسال…" : "ابدأ التوليد"}
          </button>
        </form>

        {jobId && status && (
          <section className="rounded-lg border border-zinc-200 dark:border-zinc-700 bg-white dark:bg-zinc-900 p-4 space-y-2">
            <p className="text-sm text-zinc-500">المهمة: <code className="bg-zinc-100 dark:bg-zinc-800 px-1 rounded">{jobId}</code></p>
            <p className="font-medium">الحالة: {status.status}</p>
            {status.currentStage && <p className="text-sm text-zinc-600">المرحلة: {status.currentStage}</p>}
            {status.error && <p className="text-sm text-red-600">{status.error}</p>}
            {status.status === "deployed" && status.url && (
              <p className="pt-2">
                <a href={status.url} target="_blank" rel="noopener noreferrer" className="text-blue-600 dark:text-blue-400 underline">
                  فتح المشروع المنشور
                </a>
              </p>
            )}
          </section>
        )}
      </div>
    </div>
  );
}
