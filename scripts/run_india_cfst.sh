#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$ROOT/bin/cfst"
WORK="$ROOT/.work"
PUBLIC="$ROOT/public"
LOG="$ROOT/logs/cfst.log"

COLOS="BOM,DEL,BLR,MAA,HYD,CCU,AMD"
ROUNDS=6
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

CANDIDATES="$WORK/india_candidates.txt"
: > "$CANDIDATES"

echo "[$(date '+%F %T')] 开始印度 Cloudflare 深度优选: $COLOS, 共 $ROUNDS 轮" | tee -a "$LOG"

for i in $(seq 1 "$ROUNDS"); do
  ROUND_RESULT="$WORK/round_${i}.csv"
  rm -f "$ROUND_RESULT"
  echo "[$(date '+%F %T')] 第 $i/$ROUNDS 轮：随机扫描每个 /24 的一个 IP" | tee -a "$LOG"

  "$CFST" \
    -f "$IPFILE" \
    -httping \
    -cfcolo "$COLOS" \
    -n 40 \
    -t 2 \
    -tl 1500 \
    -tlr 0.50 \
    -dd \
    -o "$ROUND_RESULT" \
    2>&1 | tee -a "$LOG" || true

  if [ -s "$ROUND_RESULT" ]; then
    tail -n +2 "$ROUND_RESULT" \
      | awk -F',' '{gsub(/[[:space:]\r]/,"",$1); if ($1 != "") print $1}' \
      >> "$CANDIDATES"
  fi

  sleep 8
done

sort -u "$CANDIDATES" -o "$CANDIDATES"
COUNT_CANDIDATES="$(wc -l < "$CANDIDATES" | tr -d ' ')"

echo "[$(date '+%F %T')] 累计发现印度候选 IP: $COUNT_CANDIDATES" | tee -a "$LOG"

if [ "$COUNT_CANDIDATES" -eq 0 ]; then
  echo "[$(date '+%F %T')] 仍未发现印度 PoP。说明你当前网络路由没有把这些 Cloudflare Anycast IP 导向印度；本次保留旧结果。" | tee -a "$LOG"
  exit 2
fi

FINAL_RESULT="$WORK/result.csv"
rm -f "$FINAL_RESULT"

echo "[$(date '+%F %T')] 对候选 IP 做最终下载测速" | tee -a "$LOG"

"$CFST" \
  -f "$CANDIDATES" \
  -httping \
  -cfcolo "$COLOS" \
  -n 20 \
  -t 4 \
  -tl 1500 \
  -tlr 0.50 \
  -dn 20 \
  -dt 5 \
  -sl 0.01 \
  -o "$FINAL_RESULT" \
  2>&1 | tee -a "$LOG" || true

if [ ! -s "$FINAL_RESULT" ]; then
  echo "[$(date '+%F %T')] 最终测速没有可用印度 IP，本次保留旧结果。" | tee -a "$LOG"
  exit 3
fi

TMP_IP="$WORK/india.txt.new"
tail -n +2 "$FINAL_RESULT" \
  | awk -F',' '{gsub(/[[:space:]\r]/,"",$1); if ($1 != "") print $1}' \
  | awk '!seen[$0]++' \
  | head -n "$TOP_N" \
  > "$TMP_IP"

if [ ! -s "$TMP_IP" ]; then
  echo "[$(date '+%F %T')] 最终结果为空，本次保留旧结果。" | tee -a "$LOG"
  exit 4
fi

mv "$TMP_IP" "$PUBLIC/india.txt"
cp "$FINAL_RESULT" "$PUBLIC/result.csv"

COUNT="$(wc -l < "$PUBLIC/india.txt" | tr -d ' ')"
{
  echo '{'
  echo "  \"updated_at\": \"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\","
  echo '  "source": "local-mac-network-deep-scan",'
  echo "  \"colos\": \"$COLOS\","
  echo "  \"rounds\": $ROUNDS,"
  echo "  \"count\": $COUNT,"
  echo '  "ips": ['
  awk -v n="$COUNT" '{printf "    \"%s\"%s\n", $0, (NR==n ? "" : ",")}' "$PUBLIC/india.txt"
  echo '  ]'
  echo '}'
} > "$PUBLIC/india.json"

echo "[$(date '+%F %T')] 完成：$COUNT 个印度优选 IP" | tee -a "$LOG"
"$ROOT/scripts/publish.sh" | tee -a "$LOG"
