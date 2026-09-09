#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ ! -d .git ]; then
  echo "当前目录不是 Git 仓库，跳过自动上传。"
  exit 0
fi

git add public/india.txt public/india.json public/result.csv

if git diff --cached --quiet; then
  echo "结果与上次相同，无需提交。"
  exit 0
fi

if ! git config user.name >/dev/null; then
  git config user.name "India CF Optimizer"
fi
if ! git config user.email >/dev/null; then
  git config user.email "actions@local"
fi

git commit -m "Update India Cloudflare IPs $(date '+%Y-%m-%d %H:%M')"
BRANCH="$(git branch --show-current)"
git push origin "$BRANCH"

echo "已推送到 GitHub：$BRANCH"
