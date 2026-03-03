#!/bin/bash
# Check environment for Badr Forge Server
# Run from: projects/badr-forge-server (e.g. ./scripts/check-env.sh)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SERVER_DIR/../.." && pwd)"
JOBS_DIR="$ROOT_DIR/jobs"
PROJECTS_DIR="$ROOT_DIR/projects"
ENV_LOCAL="$SERVER_DIR/.env.local"

ERRORS=0

echo "Badr Forge - Environment check"
echo ""

# 1. Node.js
if command -v node >/dev/null 2>&1; then
  echo "[OK] Node.js: $(node -v)"
else
  echo "[FAIL] Node.js not found. Install from https://nodejs.org"
  ERRORS=$((ERRORS + 1))
fi

# 2. npm
if command -v npm >/dev/null 2>&1; then
  echo "[OK] npm: $(npm -v)"
else
  echo "[FAIL] npm not found."
  ERRORS=$((ERRORS + 1))
fi

# 3. Python (optional)
if command -v python3 >/dev/null 2>&1; then
  echo "[OK] Python (optional): $(python3 --version 2>&1)"
elif command -v python >/dev/null 2>&1; then
  echo "[OK] Python (optional): $(python --version 2>&1)"
else
  echo "[SKIP] Python not found (optional; needed for Aider)"
fi

# 4. jobs directory
if [ -d "$JOBS_DIR" ]; then
  if [ -w "$JOBS_DIR" ]; then
    echo "[OK] jobs directory exists and writable: $JOBS_DIR"
  else
    echo "[FAIL] jobs directory not writable: $JOBS_DIR"
    ERRORS=$((ERRORS + 1))
  fi
else
  if mkdir -p "$JOBS_DIR" 2>/dev/null; then
    echo "[OK] jobs directory created: $JOBS_DIR"
  else
    echo "[FAIL] Could not create jobs directory: $JOBS_DIR"
    ERRORS=$((ERRORS + 1))
  fi
fi

# 5. projects directory (optional)
if [ -d "$PROJECTS_DIR" ]; then
  echo "[OK] projects directory exists: $PROJECTS_DIR"
else
  echo "[SKIP] projects directory not found (optional): $PROJECTS_DIR"
fi

# 6. .env.local and CLAUDE_API_KEY
if [ ! -f "$ENV_LOCAL" ]; then
  echo "[FAIL] .env.local not found. Copy from .env.example and set CLAUDE_API_KEY."
  ERRORS=$((ERRORS + 1))
else
  if grep -qE 'CLAUDE_API_KEY=\s*[^[:space:]]{10,}' "$ENV_LOCAL" 2>/dev/null; then
    echo "[OK] .env.local exists and CLAUDE_API_KEY is set"
  else
    echo "[FAIL] .env.local exists but CLAUDE_API_KEY is missing or empty."
    ERRORS=$((ERRORS + 1))
  fi
fi

echo ""
if [ $ERRORS -eq 0 ]; then
  echo "All required checks passed. You can run: npm run dev"
  exit 0
else
  echo "$ERRORS required check(s) failed. Fix them before running the server."
  exit 1
fi
