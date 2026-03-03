import { NextRequest, NextResponse } from "next/server";
import { randomUUID } from "crypto";
import { writeFileSync, appendFileSync, mkdirSync } from "fs";
import path from "path";
import { exec } from "child_process";
import type { JobStatusPayload } from "@/lib/forge-job";

// مجلد المهام: من جذر b11 (مستوى أعلى من مشروع الخادم)
const JOBS_DIR = path.join(process.cwd(), "..", "..", "jobs");

function writeJobStatus(jobDir: string, payload: JobStatusPayload, logLine?: string) {
  const statusPath = path.join(jobDir, "status.json");
  const logPath = path.join(jobDir, "logs.txt");
  writeFileSync(statusPath, JSON.stringify(payload, null, 2), "utf-8");
  const ts = new Date().toISOString();
  if (logLine !== undefined) {
    appendFileSync(logPath, `[${ts}] ${logLine}\n`, "utf-8");
  }
}

export async function POST(req: NextRequest) {
  const apiKey = process.env.CLAUDE_API_KEY;
  if (!apiKey) {
    return NextResponse.json(
      { error: "CLAUDE_API_KEY غير معرّف في .env.local" },
      { status: 500 }
    );
  }

  const jobId = randomUUID().slice(0, 8);
  const jobDir = path.join(JOBS_DIR, jobId);

  mkdirSync(jobDir, { recursive: true });
  mkdirSync(path.join(jobDir, "project"), { recursive: true });
  writeFileSync(path.join(jobDir, "logs.txt"), "", "utf-8");

  let body: { projectName?: string; description?: string; features?: string[] };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json(
      { error: "طلب غير صالح: body يجب أن يكون JSON" },
      { status: 400 }
    );
  }

  writeFileSync(
    path.join(jobDir, "input.json"),
    JSON.stringify(body, null, 2),
    "utf-8"
  );

  writeJobStatus(
    jobDir,
    { status: "generating_blueprint", startedAt: new Date().toISOString() },
    "status: started → generating_blueprint"
  );

  generateBlueprint(jobId, body, apiKey).catch((err) => {
    writeJobStatus(
      jobDir,
      { status: "error", error: String(err?.message ?? err) },
      `status: error — ${err?.message ?? err}`
    );
  });

  return NextResponse.json({ jobId, status: "started" });
}

async function generateBlueprint(
  jobId: string,
  input: Record<string, unknown>,
  apiKey: string
) {
  const jobDir = path.join(JOBS_DIR, jobId);
  const projectName = String(input?.projectName ?? "مشروع");
  const description = String(input?.description ?? "");

  const STAGES = [
    {
      name: "stage1_prd",
      prompt: `أنت مهندس متطلبات. أنشئ PRD كاملاً لـ: ${projectName}. الوصف: ${description}`,
    },
    {
      name: "stage2_architecture",
      prompt: `بناءً على PRD التالي، صمم الهيكل المعماري للمشروع.`,
    },
    {
      name: "stage3_database",
      prompt: `صمم مخطط قاعدة البيانات (Prisma Schema) للمشروع.`,
    },
    {
      name: "stage4_api",
      prompt: `صمم نقاط API endpoints للمشروع.`,
    },
    {
      name: "stage5_ui",
      prompt: `صمم مكونات واجهة المستخدم للمشروع.`,
    },
    {
      name: "stage6_blueprint",
      prompt: `اجمع كل المخرجات السابقة في ملف blueprint.json واحد منظم.`,
    },
  ];

  const results: Record<string, string> = {};

  for (const stage of STAGES) {
    await new Promise((r) => setTimeout(r, 2000));

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 60000);

    try {
      const res = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": apiKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: "claude-sonnet-4-20250514",
          max_tokens: 4096,
          messages: [{ role: "user", content: stage.prompt }],
        }),
        signal: controller.signal,
      });

      clearTimeout(timeout);
      const data = (await res.json()) as {
        content?: Array<{ text?: string }>;
        error?: { message?: string };
      };

      if (!res.ok) {
        results[stage.name] = `ERROR: ${data?.error?.message ?? res.statusText}`;
      } else {
        results[stage.name] = data.content?.[0]?.text ?? "";
      }

      writeFileSync(
        path.join(jobDir, `${stage.name}.json`),
        JSON.stringify(results[stage.name], null, 2),
        "utf-8"
      );

      writeJobStatus(
        jobDir,
        { status: "generating", currentStage: stage.name },
        `status: generating — ${stage.name}`
      );
    } catch (err: unknown) {
      clearTimeout(timeout);
      results[stage.name] = `ERROR: ${err instanceof Error ? err.message : String(err)}`;
    }
  }

  writeFileSync(
    path.join(jobDir, "blueprint.json"),
    JSON.stringify(results, null, 2),
    "utf-8"
  );

  writeJobStatus(
    jobDir,
    { status: "blueprint_ready", completedAt: new Date().toISOString() },
    "status: blueprint_ready"
  );

  // المرحلة 3: تشغيل الوكيل المنفذ (run-agent) بعد جاهزية البلوبرنت (إن كان مفعّلاً)
  if (process.env.FORGE_RUN_AGENT !== "1") {
    return; // لا تشغيل الوكيل إلا إذا FORGE_RUN_AGENT=1
  }

  writeJobStatus(
    jobDir,
    { status: "building" },
    "status: building (starting agent)"
  );

  const scriptsDir = path.join(process.cwd(), "scripts");
  const isWin = process.platform === "win32";
  const runAgentCmd = isWin
    ? `powershell -ExecutionPolicy Bypass -File "${path.join(scriptsDir, "run-agent.ps1")}" -JobId ${jobId}`
    : `bash "${path.join(scriptsDir, "run-agent.sh")}" ${jobId}`;
  const runEnv = { ...process.env, JOBS_DIR: JOBS_DIR };

  exec(runAgentCmd, { env: runEnv, cwd: process.cwd() }, (error, _stdout, stderr) => {
    if (error) {
      writeJobStatus(
        jobDir,
        { status: "build_failed", error: String(stderr || error.message) },
        `status: build_failed — ${stderr || error.message}`
      );
    } else {
      writeJobStatus(
        jobDir,
        { status: "build_success" },
        "status: build_success"
      );
    }
  });
}
