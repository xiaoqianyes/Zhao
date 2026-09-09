#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$ROOT/bin/cfst"
WORK="$ROOT/.work"
PUBLIC="$ROOT/public"
LOG="$ROOT/logs/cfst.log"

COLOS="BOM,DEL,BLR,MAA,HYD,CCU,AMD"
TOP_N=20

mkdir -p "$WORK" "$PUBLIC" "$ROOT/logs"

CFST="$(find "$BIN_DIR" -type f \( -name 'cfst' -o -name 'CloudflareST' \) | head -n 1)"
IPFILE="$(find "$BIN_DIR" -type f -name 'ip.txt' | head -n 1)"

if [ -z "${CFST:-}" ] || [ ! -x "$CFST" ]; then
  echo "cfst 不存在，请先执行 ./setup.sh" | tee -a "$LOG"
  exit 1
fi
if [ -z "${IPFILE:-}" ]; then
  echo "未找到 CloudflareSpeedTest 自带的 ip.txt，请重新执行 ./setup.sh" | tee -a "$LOG"
  exit 1
fi

unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY || true

RESULT="$WORK/result.csv"
rm -f "$RESULT"

echo "[$(date '+%F %T')] 开始印度 Cloudflare 优选: $COLOS" | tee -a "$LOG"

"$CFST" \
  -f "$IPFILE" \
  -httping \
  -cfcolo "$COLOS" \
  -n 80 \
  -t 4 \
  -tl 600 \
  -tlr 0.25 \
  -dn 20 \
  -dt 5 \
  -sl 0.01 \
  -o "$RESULT" \
  2>&1 | tee -a "$LOG"

if [ ! -s "$RESULT" ]; then
  echo "[$(date '+%F %T')] 没有筛到印度 IP，本次保留旧结果。" | tee -a "$LOG"
  exit 2
fi

TMP_IP="$WORK/india.txt.new"
tail -n +2 "$RESULT" \
  | awk -F',' '{gsub(/[[:space:]\r]/,"",$1); if ($1 != "") print $1}' \
  | awk '!seen[$0]++' \
  | head -n "$TOP_N" \
  > "$TMP_IP"

if [ ! -s "$TMP_IP" ]; then
  echo "[$(date '+%F %T')] 结果为空，本次保留旧结果。" | tee -a "$LOG"
  exit 3
fi

mv "$TMP_IP" "$PUBLIC/india.txt"
cp "$RESULT" "$PUBLIC/result.csv"

COUNT="$(wc -l < "$PUBLIC/india.txt" | tr -d ' ')"
{
  echo '{'
  echo "  \"updated_at\": \"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\","
  echo '  "source": "local-mac-network",'
  echo "  \"colos\": \"$COLOS\","
  echo "  \"count\": $COUNT,"
  echo '  "ips": ['
  awk -v n="$COUNT" '{printf "    \"%s\"%s\n", $0, (NR==n ? "" : ",")}' "$PUBLIC/india.txt"
  echo '  ]'
  echo '}'
} > "$PUBLIC/india.json"

echo "[$(date '+%F %T')] 完成：$COUNT 个印度优选 IP" | tee -a "$LOG"
"$ROOT/scripts/publish.sh" | tee -a "$LOG"
