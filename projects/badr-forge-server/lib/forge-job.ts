/**
 * نظام إدارة المهام (المرحلة 2)
 * هيكل مجلد المهمة وسلسلة الحالات الموحّدة.
 */

/** سلسلة حالات المهمة من البدء حتى النشر */
export const JOB_STATUS_FLOW = [
  "started",
  "generating_blueprint",
  "generating",
  "blueprint_ready",
  "building",
  "build_fixing",
  "build_success",
  "build_failed",
  "deploying",
  "deployed",
  "error",
] as const;

export type JobStatus = (typeof JOB_STATUS_FLOW)[number];

/** وصف الحالات للمراحل الحالية (Sprint 1–2) */
export const STATUS_DESCRIPTIONS: Record<string, string> = {
  started: "المهمة بدأت، جاري تهيئة المجلد",
  generating_blueprint: "جاري توليد البلوبرنت (6 مراحل)",
  generating: "جاري تنفيذ مرحلة من مراحل البلوبرنت",
  blueprint_ready: "البلوبرنت جاهز",
  building: "جاري بناء المشروع (الوكيل)",
  build_fixing: "جاري التصحيح الذاتي بعد فشل البناء",
  build_success: "البناء نجح",
  build_failed: "فشل البناء بعد الحد الأقصى للمحاولات",
  deploying: "جاري النشر",
  deployed: "تم النشر بنجاح",
  error: "حدث خطأ",
};

/**
 * هيكل مجلد المهمة (معيار ثابت):
 *
 * jobs/{jobId}/
 *   ├── input.json       مدخلات المستخدم الأصلية
 *   ├── status.json      حالة المهمة الحالية
 *   ├── stage1_prd.json  … stage6_blueprint.json  مخرجات المراحل
 *   ├── blueprint.json   البلوبرنت النهائي المجمع
 *   ├── logs.txt        سجلات تنفيذ المهمة والوكيل
 *   └── project/        المشروع المبني (كود فعلي) — من Sprint 3
 */
export const JOB_FOLDER_FILES = [
  "input.json",
  "status.json",
  "blueprint.json",
  "logs.txt",
] as const;

export const JOB_STAGE_PREFIX = "stage";

/** كائن الحالة كما يُحفظ في status.json */
export interface JobStatusPayload {
  status: JobStatus | string;
  startedAt?: string;
  completedAt?: string;
  currentStage?: string;
  error?: string;
  url?: string;
  deployedAt?: string;
  attempts?: number;
}
