import { NextRequest, NextResponse } from "next/server";
import { readFileSync, existsSync } from "fs";
import path from "path";

const JOBS_DIR = path.join(process.cwd(), "..", "..", "jobs");

export async function GET(
  _req: NextRequest,
  context: { params: Promise<{ jobId: string }> }
) {
  const { jobId } = await context.params;
  const statusFile = path.join(JOBS_DIR, jobId, "status.json");

  if (!existsSync(statusFile)) {
    return NextResponse.json({ error: "Job not found" }, { status: 404 });
  }

  const status = JSON.parse(readFileSync(statusFile, "utf-8"));
  return NextResponse.json(status);
}
