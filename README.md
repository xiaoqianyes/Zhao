# India Cloudflare 优选（macOS 本地网络自动版）

这个仓库用于在你的 **Mac 当前网络** 上自动运行 CloudflareSpeedTest，只保留印度 Cloudflare PoP，然后把结果推送回 GitHub，供 Cloudflare Pages 发布。

保留的印度 PoP：`BOM,DEL,BLR,MAA,HYD,CCU,AMD`。

> 关键点：测速必须在你的 Mac 上跑，GitHub Actions 不参与测速。这样结果才基于你自己的宽带/Wi‑Fi 路由。

## 第一次使用

在 Mac 终端执行：

```bash
git clone git@github.com:xiaoqianyes/Zhao.git
cd Zhao
chmod +x setup.sh scripts/*.sh
./setup.sh
```

`setup.sh` 会自动：

- 判断 Apple Silicon / Intel Mac
- 下载 XIU2/CloudflareSpeedTest 最新 macOS 版本
- 安装本机 `launchd` 定时任务
- 默认每天本地时间 **06:00** 和 **18:00** 运行

测速前请关闭 Mac 上的 VPN/代理，否则测到的会是代理线路。

## 立即手动跑一次

```bash
cd ~/Zhao
./scripts/run_india_cfst.sh
```

如果你 clone 到别的位置，进入那个仓库目录执行即可。

运行完成后：

```bash
cat public/india.txt
```

会得到筛选后的印度 Cloudflare 优选 IP。

同时生成：

- `public/india.txt` — 纯 IP，一行一个
- `public/india.json` — JSON 版本
- `public/result.csv` — CloudflareSpeedTest 完整测速结果

成功后脚本会自动 `git commit` + `git push`。

## Cloudflare Pages

把 Cloudflare Pages 连接到本仓库 `xiaoqianyes/Zhao`：

- Framework preset：None
- Build command：留空
- Build output directory：`public`
- Production branch：`master`

部署后可直接访问：

```text
https://你的项目.pages.dev/india.txt
```

## 定时任务

默认每天：

- 06:00
- 18:00

配置文件：

```text
~/Library/LaunchAgents/com.local.indiacf.plist
```

## 日志

仓库内：

```text
logs/launchd.out.log
logs/launchd.err.log
logs/cfst.log
```

## 注意

Cloudflare 是 Anycast。同一个 IP 在不同运营商、不同网络或不同时间可能进入不同 PoP，因此这份结果只代表 **运行测速时这台 Mac 所在网络** 的实际路径。
