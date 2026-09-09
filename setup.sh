#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$ROOT/bin/cfst"
LOG_DIR="$ROOT/logs"
PLIST="$HOME/Library/LaunchAgents/com.local.indiacf.plist"

mkdir -p "$BIN_DIR" "$LOG_DIR" "$HOME/Library/LaunchAgents"

ARCH="$(uname -m)"
case "$ARCH" in
  arm64|aarch64) ASSET="cfst_darwin_arm64.zip" ;;
  x86_64|amd64) ASSET="cfst_darwin_amd64.zip" ;;
  *) echo "不支持的 Mac 架构: $ARCH"; exit 1 ;;
esac

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

URL="https://github.com/XIU2/CloudflareSpeedTest/releases/latest/download/$ASSET"
echo "下载 CloudflareSpeedTest: $URL"
curl -fL --retry 3 "$URL" -o "$TMP/cfst.zip"
rm -rf "$BIN_DIR"/*

# Mac 上自带的 unzip 遇到非 ASCII (比如中文) 压缩包内文件名时会报编码错误导致 "Bad file descriptor"
# 改用 macOS 自带的 ditto 工具解压，它可以完美处理 zip 里的中文文件名编码
ditto -V -x -k "$TMP/cfst.zip" "$BIN_DIR"

CFST="$(find "$BIN_DIR" -type f \( -name 'cfst' -o -name 'CloudflareST' \) | head -n 1)"
if [ -z "${CFST:-}" ]; then
  echo "未找到 cfst 可执行文件。"
  exit 1
fi
chmod +x "$CFST"

cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.local.indiacf</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$ROOT/scripts/run_india_cfst.sh</string>
  </array>
  <key>WorkingDirectory</key><string>$ROOT</string>
  <key>StartCalendarInterval</key>
  <array>
    <dict><key>Hour</key><integer>6</integer><key>Minute</key><integer>0</integer></dict>
    <dict><key>Hour</key><integer>18</integer><key>Minute</key><integer>0</integer></dict>
  </array>
  <key>StandardOutPath</key><string>$LOG_DIR/launchd.out.log</string>
  <key>StandardErrorPath</key><string>$LOG_DIR/launchd.err.log</string>
</dict>
</plist>
PLIST_EOF

chmod +x "$ROOT/scripts/run_india_cfst.sh" "$ROOT/scripts/publish.sh"
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

echo "安装完成。"
echo "定时任务：每天 06:00 / 18:00"
echo "手动运行：$ROOT/scripts/run_india_cfst.sh"
