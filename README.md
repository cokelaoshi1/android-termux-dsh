# android-termux-dsh

> One-click installer for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (`@deepseek-ai/dsh`) on **Android / Termux**
> 在 **Android / Termux** 上一键安装 DeepSeek Harness（`@deepseek-ai/dsh`）的脚本

![platform](https://img.shields.io/badge/platform-Android%20%2F%20Termux-green)
![arch](https://img.shields.io/badge/arch-arm64%20%7C%20armv7-blue)
![tested](https://img.shields.io/badge/tested-Android%2016%20%2F%20aarch64-brightgreen)
![license](https://img.shields.io/badge/license-MIT-yellow)

[中文](#中文) | [English](#english)

---

## 中文

### 简介

在 **Android Termux** 上**从零一键安装** [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（`@deepseek-ai/dsh`）。**适用于全新安装的 Termux**：跑完 `install.sh` 一条命令，pkg 更新、工具链、Node、原生模块编译、运行时修补、存储权限全部自动完成，无需任何手动步骤。解决官方 `npm i -g` 在 Android/arm64 上无法完成的一连串原生编译与运行时问题。**无需 root**（有 root 也不影响），已在 **Android 16 / aarch64 / Termux** 实测通过。

### 功能特性

- ✅ **一站式**：全新 Termux 一条命令装到底，装完即用
- ✅ **幂等**：任何一步失败，直接重跑即可续上；不重复下载已装好的部分
- ✅ **网络自适应**：npm 官方源 8 秒连不通自动切 npmmirror；失败自动换源重试；下载超时/重试已调优
- ✅ **防 OOM**：koffi 编译限制并行度，低内存机型不易被系统杀掉
- ✅ **默认工作区 = sdcard**：网页版直接读写手机存储，无需手动配置
- ✅ **自动验证**：装完逐项检查 dsh / koffi / node-pty / sharp / sdcard，失败即红字报错，不再静默
- ✅ **中国大陆友好**：`--cn` 参数一键切换国内 npm 镜像

### 为什么需要它

`@deepseek-ai/dsh` 依赖多个**没有 android-arm64 预编译产物**的原生模块，逐个排查非常痛苦：

| # | 模块 | 报错 | 脚本的处理 |
|---|------|------|-----------|
| 1 | `koffi` | `CMake does not seem to be available` | 安装 `cmake clang make python binutils pkg-config libandroid-spawn` |
| 2 | `koffi` | `statx` 编译错误（bionic 头文件问题） | 编译目标提升到 API 30：`-target aarch64-linux-android30` |
| 3 | `node-pty` | `gyp: Undefined variable android_ndk_path` | 修补 node-gyp 缓存中的 `common.gypi` |
| 4 | 全部原生模块 | npm `install-scripts` 警告（构建脚本被静默跳过） | `npm config set allow-scripts=...` 放行 |
| 5 | `sharp` | `Could not load the "sharp" module using the android-arm64 runtime` | 安装 `@img/sharp-wasm32` WebAssembly 兜底 |
| 6 | `cordis-plugin-hmr` | `--expose-internals is required` | 用启动包装器替换 npm 生成的 `dsh` 软链 |

### 环境要求

- Android 11+（API 30+，`statx` 运行时可用）
- [Termux](https://f-droid.org/packages/com.termux/)（**必须 F-Droid 版**，Play 商店版已废弃）
- 建议 4GB+ 内存、2GB+ 空闲存储、稳定网络
- 架构：arm64（主流）/ armv7 / x86_64 / i686（脚本自动适配）

### 快速开始

在 Termux 里执行（免 clone，一行流）：

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/cokelaoshi1/android-termux-dsh/main/install.sh)"
```

或克隆后执行：

```sh
pkg install -y git
git clone https://github.com/cokelaoshi1/android-termux-dsh.git
cd android-termux-dsh
bash install.sh
```

> - 脚本会执行 `pkg upgrade`，**务必等它跑完**（Termux 不支持部分升级）。想跳过系统更新：`bash install.sh --skip-upgrade`
> - 🇨🇳 **中国大陆网络**：建议直接 `bash install.sh --cn` 使用 npmmirror 镜像；不传也会自动检测（官方源连不通自动切换）
> - 安装中最耗时的一步是 `npm install`（下载数百个包 + koffi 源码编译，约 5~15 分钟），**下载阶段长时间无输出属正常**，请保持屏幕常亮、不要关闭 Termux

### 安装完成后

```sh
dsh web
```

- 手机浏览器打开 `http://127.0.0.1:3080`，或在 Termux 里执行 `termux-open-url http://127.0.0.1:3080`
- 电脑访问：`dsh web --host 0.0.0.0`，浏览器打开 `http://手机局域网IP:3080`
- 首次使用请在 Web UI 的 **设置 → 模型** 里配置 LLM API Key

### 默认工作区 = sdcard（直接读写手机存储）

安装脚本默认做两件事，让网页版能直接读写手机存储：

1. **授权存储权限**：执行 `termux-setup-storage`，Android 11+ 会跳转「所有文件访问」设置页，允许后生成 `~/storage/shared` 等链接；
2. **固定工作区**：往 `~/.dsh/profiles/web/cordis.patch.yml` 写入：

```yaml
- id: fs-sandbox
  config:
    cwd: /data/data/com.termux/files/home/storage/shared
```

这样 Web UI 的文件树、工作区根目录就是 sdcard（`~/storage/shared`），不再局限于启动 `dsh web` 时的目录。

- 安装时自定义工作区：`DSH_WORKSPACE=/path/to/dir bash install.sh`；跳过：`DSH_WORKSPACE="" bash install.sh`
- 想改默认值：编辑上面那个 `cordis.patch.yml` 的 `cwd`，重启 `dsh web` 生效
- 若提示「未找到 ~/storage/shared」：到 系统设置 → 应用 → Termux → 权限，手动允许「文件和媒体」后重跑脚本

### 手机端适配（可选）

dsh 网页版在窄视口下会自动把侧栏折叠成图标栏，但右侧面板（预览/文件变更）不会自动收起，手机上聊天区会被挤占。仓库提供一套移动端样式（`mobile/` 目录），三种注入方式任选：

| 方式 | 适用 | 说明 |
|------|------|------|
| `mobile/dsh-mobile.user.js` | 支持扩展的浏览器（Kiwi / Firefox + Tampermonkey/Violentmonkey） | 打开页面自动注入，无需手动 |
| `mobile/bookmarklet.txt` | 任意浏览器 | 把 `javascript:` 代码存成书签，打开页面后点一下 |
| `mobile/mobile.css` | 手动 | 控制台 fetch 注入，或配合 Stylus 扩展 |

效果：窄屏强制单列布局、右侧面板自动隐藏（聊天区占满）、弹窗近全屏、触控目标加大、放开页面缩放。

### 脚本做了什么（全新 Termux 一站式）

1. 环境预检（Termux / 架构自动适配）
2. `pkg update && pkg upgrade`（必须先完整升级）
3. 安装基础工具与编译链：`git curl cmake clang make python binutils pkg-config libandroid-spawn`
4. 安装/检查 Node >= 22.12（dsh 的硬性要求）
5. 配置 npm：放行 install-scripts、加大下载超时与重试、`--cn` 切换 npmmirror
6. 预下载 Node 头文件并修补 node-gyp `common.gypi`（`android_ndk_path`）
7. 网络预检 → `npm i -g @deepseek-ai/dsh`（API 30 编译参数；koffi 源码编译，限并行防 OOM；失败自动换源重试；装完硬检查 `dsh` 命令）
8. 安装 sharp WebAssembly 兜底（`@img/sharp-wasm32`，失败自动换源，幂等跳过）
9. 应用 `link() → rename()` 补丁（部分定制 ROM 禁用 `link()` 系统调用）
10. 安装 `--expose-internals` 启动包装器 + pnpm
11. sdcard 存储授权 + 默认工作区配置（fs-sandbox.cwd → `~/storage/shared`）
12. 逐项验证（dsh / koffi / node-pty / sharp / sdcard）并输出启动指引

脚本**幂等**：任何一步失败直接重跑即可续上；重新执行过 `npm i -g @deepseek-ai/dsh` 后，也建议重跑一次恢复第 8、9、10 步。

### 参数与环境变量

| 参数 / 变量 | 说明 |
|-------------|------|
| `--skip-upgrade` | 跳过 `pkg update && pkg upgrade` |
| `--cn` | 强制使用 npmmirror 镜像源（中国大陆网络推荐） |
| `DSH_WORKSPACE=/path` | 安装时自定义默认工作区 |
| `DSH_WORKSPACE=""` | 跳过 sdcard 工作区配置 |
| `CMAKE_BUILD_PARALLEL_LEVEL=N` | 自定义 koffi 编译并行度（默认 2，内存小的手机可设 1） |

### 故障排查

| 现象 | 处理 |
|------|------|
| node 启动报 OpenSSL 符号错误 / `error while loading shared libraries` | 先 `pkg update && pkg upgrade -y`（Termux 不支持部分升级） |
| `npm error 'allow-scripts' is not a valid npm option` | **无害**：旧版 npm 没有该安全门，默认就会执行构建脚本，忽略即可 |
| `CMake does not seem to be available` | 重跑脚本（会自动补装工具链） |
| node-pty 报 `android_ndk_path` | 重跑脚本（common.gypi 补丁幂等） |
| 安装后 `No command dsh found` | npm 安装失败。脚本会在失败点红字提示（网络/磁盘/编译/OOM），按提示处理；也可加 `--cn` 重跑 |
| `npm install` 那步超过 15 分钟无任何输出 | 网络黑洞，Ctrl+C 后用 `--cn` 重跑，或检查代理/VPN |
| 安装中途无报错就退出（旧版本脚本） | 已修复：所有步骤现在失败必红字。若仍遇到，把停住前后 10 行发 issue |
| 网页版读不了 sdcard / 看不到手机存储 | 运行 `termux-setup-storage` 并允许权限（Android 11+ 需开启「所有文件访问」）；再确认 `cordis.patch.yml` 里 `fs-sandbox.cwd` 指向 `~/storage/shared` |
| 会话保存报 `EACCES: permission denied, link ...` | 部分定制 ROM 全局禁用 `link()`。脚本第 9 步已自动应用 `link() → rename()` 补丁，重跑脚本即可修复；见 [discussion #248](https://github.com/deepseek-ai/deepseek-harness/discussions/248) |
| 命令执行报 `[timed out after Xms]` / `[killed by signal: SIGTERM]` | bash 工具超时。慢设备上耗时命令请用 `run_in_background: true`；若每次都超时，确认内核 >= 5.13（Landlock），老内核的沙箱兜底会拖慢每次执行 |
| `Tool call Error unknown tool ""` | 模型/API 返回了畸形工具调用（流式 `tool_calls` 里 `name` 缺失或后到）。改用官方 `api.deepseek.com` + 模型 `deepseek-chat`（不要用 deepseek-reasoner 或工具支持差的第三方中转），新建会话重试 |
| bash 工具报 `SANDBOX_UNAVAILABLE` | 沙箱需要 Landlock（内核 >= 5.13）。老内核机型需自建 proot runner，见 [discussion #136](https://github.com/deepseek-ai/deepseek-harness/discussions/136) |

### 原理简述

- Termux 的 clang 默认 target API 24，而 bionic 的 `statx()` 声明要 API >= 30 才可见，编译必须加 `-target aarch64-linux-android30`；
- Termux 的 Node 把 `process.platform` 报成 `android`，node-gyp 会解析引用 `android_ndk_path` 的 `common.gypi`，而该变量只在用 NDK 编译 Node 时才定义；
- npm 11.19+ 默认拦截 install-scripts，导致 koffi/node-pty 的构建脚本静默不执行（旧版 npm 无此行为，会正常执行）；
- `sharp` 只提供 linux/darwin/win 预编译，Android 需用其 WebAssembly 版本 `@img/sharp-wasm32`；
- HMR 插件需要 `--expose-internals`，该参数无法通过 `NODE_OPTIONS` 传入，只能改启动命令行。

### 参考

- [deepseek-ai/deepseek-harness discussion #136 — Could not run in Android/Termux [SOLVED]](https://github.com/deepseek-ai/deepseek-harness/discussions/136)
- [deepseek-ai/deepseek-harness discussion #248 — link() fallback 提案](https://github.com/deepseek-ai/deepseek-harness/discussions/248)
- [sharp 安装文档](https://sharp.pixelplumbing.com/install)

---

## English

### About

Install [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (`@deepseek-ai/dsh`) on **Android via Termux** with a single command — from a **fresh Termux install** to a fully working web UI. Fixes the chain of native build & runtime issues that make the official `npm i -g` fail on Android/arm64. **No root required.** Verified on **Android 16 / aarch64 / Termux**.

### Features

- ✅ **All-in-one**: one command on a fresh Termux, ready to use
- ✅ **Idempotent**: re-run after any failure to continue; already-installed parts are reused
- ✅ **Network adaptive**: auto-switches to the npmmirror mirror if the official npm registry is unreachable (8s probe); auto-retries with the mirror on failure; tuned fetch timeouts/retries
- ✅ **OOM-safe**: koffi build parallelism is capped so low-RAM phones are less likely to get killed
- ✅ **Default workspace = sdcard**: the web UI reads/writes phone storage out of the box
- ✅ **Self-verifying**: checks dsh / koffi / node-pty / sharp / sdcard at the end; every failure prints a red error — no more silent deaths
- ✅ **Mainland-China friendly**: `--cn` flag switches to the npmmirror registry

### Why this exists

`@deepseek-ai/dsh` depends on native modules with **no android-arm64 prebuilds**:

| # | Module | Error | Handled by |
|---|--------|-------|-----------|
| 1 | `koffi` | `CMake does not seem to be available` | installs `cmake clang make python binutils pkg-config libandroid-spawn` |
| 2 | `koffi` | `statx` compile error (bionic header issue) | builds with `-target aarch64-linux-android30` (API 30) |
| 3 | `node-pty` | `gyp: Undefined variable android_ndk_path` | patches node-gyp's cached `common.gypi` |
| 4 | all | npm `install-scripts` warning (scripts silently skipped) | `npm config set allow-scripts=...` |
| 5 | `sharp` | `Could not load the "sharp" module using the android-arm64 runtime` | installs the `@img/sharp-wasm32` WebAssembly fallback |
| 6 | `cordis-plugin-hmr` | `--expose-internals is required` | replaces the npm `dsh` symlink with a launcher wrapper |

### Requirements

- Android 11+ (API 30+, for `statx` at runtime)
- [Termux](https://f-droid.org/packages/com.termux/) from **F-Droid** (the Play Store build is abandoned)
- ~4GB+ RAM, ~2GB+ free storage, stable network
- arm64 (mainstream) / armv7 / x86_64 / i686 (auto-detected)

### Quick start

One-liner (no clone) — run inside Termux:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/cokelaoshi1/android-termux-dsh/main/install.sh)"
```

Or clone and run:

```sh
pkg install -y git
git clone https://github.com/cokelaoshi1/android-termux-dsh.git
cd android-termux-dsh
bash install.sh
```

> - The script runs `pkg upgrade` — **let it finish** (partial upgrades are unsupported). Skip it with `bash install.sh --skip-upgrade`
> - 🇨🇳 **Mainland China network**: use `bash install.sh --cn` for the npmmirror registry; otherwise the script auto-detects (switches if the official registry is unreachable)
> - The `npm install` step is the longest (hundreds of packages + koffi source build, ~5–15 min). **No output for a while during downloads is normal** — keep the screen on and don't close Termux

### After install

```sh
dsh web
```

- On the phone: open `http://127.0.0.1:3080` (or run `termux-open-url http://127.0.0.1:3080`)
- From a PC: `dsh web --host 0.0.0.0`, then open `http://<phone-LAN-IP>:3080`
- Configure your LLM API key in the Web UI under **Settings → Models**

### Default workspace = sdcard (read/write phone storage)

The installer sets up two things by default so the web UI can read/write phone storage:

1. **Storage permission**: runs `termux-setup-storage` (on Android 11+ this opens the "All files access" settings page); this creates the `~/storage/shared` link.
2. **Pinned workspace**: writes to `~/.dsh/profiles/web/cordis.patch.yml`:

```yaml
- id: fs-sandbox
  config:
    cwd: /data/data/com.termux/files/home/storage/shared
```

The Web UI's file tree / workspace root is then the sdcard (`~/storage/shared`), regardless of where `dsh web` was launched.

- Custom workspace at install time: `DSH_WORKSPACE=/path/to/dir bash install.sh`; skip: `DSH_WORKSPACE="" bash install.sh`
- Change the default: edit `cwd` in `cordis.patch.yml` above and restart `dsh web`
- If you see "~/storage/shared not found": grant storage to Termux manually (Settings → Apps → Termux → Permissions → Files and media) and re-run the script

### Mobile adaptation (optional)

The dsh web UI auto-collapses the sidebar to a rail on narrow viewports, but the right-side panels (preview / file changes) stay open and squeeze the chat on phones. This repo ships a mobile stylesheet in `mobile/`, injectable three ways:

| Way | Browser | Notes |
|-----|---------|-------|
| `mobile/dsh-mobile.user.js` | extension-capable (Kiwi / Firefox + Tampermonkey/Violentmonkey) | auto-injects on page load |
| `mobile/bookmarklet.txt` | any browser | save the `javascript:` snippet as a bookmark and tap it after loading |
| `mobile/mobile.css` | manual | fetch-inject from the console, or use with the Stylus extension |

Effects: single-column layout on narrow screens, right panels hidden (chat fills the width), near-fullscreen modals, larger touch targets, zoom re-enabled.

### What the script does (all-in-one, fresh Termux)

1. Preflight checks (Termux / architecture, auto-detected)
2. `pkg update && pkg upgrade` (must finish first)
3. Install base tools + build chain: `git curl cmake clang make python binutils pkg-config libandroid-spawn`
4. Install / check Node >= 22.12 (hard requirement)
5. npm setup: allow install-scripts, tuned fetch timeouts/retries, `--cn` npmmirror
6. Pre-download Node headers and patch node-gyp `common.gypi` (`android_ndk_path`)
7. Network probe → `npm i -g @deepseek-ai/dsh` (API 30 target; koffi built from source with capped parallelism; auto-retries with the mirror; hard-checks the `dsh` command afterwards)
8. Install the sharp WebAssembly fallback (`@img/sharp-wasm32`; mirror retry; idempotent skip)
9. Apply the `link() → rename()` patch (some custom ROMs block the `link()` syscall)
10. Install the `--expose-internals` launcher wrapper + pnpm
11. Grant sdcard storage + pin the workspace (`fs-sandbox.cwd` → `~/storage/shared`)
12. Verify each piece (dsh / koffi / node-pty / sharp / sdcard) and print startup instructions

The script is **idempotent**: re-run it after any failure to continue; re-run it too after reinstalling dsh via npm to restore steps 8–10.

### Flags & env vars

| Flag / var | Meaning |
|------------|---------|
| `--skip-upgrade` | skip `pkg update && pkg upgrade` |
| `--cn` | force the npmmirror registry (recommended for Mainland China) |
| `DSH_WORKSPACE=/path` | custom default workspace at install time |
| `DSH_WORKSPACE=""` | skip the sdcard workspace setup |
| `CMAKE_BUILD_PARALLEL_LEVEL=N` | koffi build parallelism (default 2; set 1 on low-RAM phones) |

### Troubleshooting

| Symptom | Fix |
|---------|-----|
| Node fails with an OpenSSL symbol error / `error while loading shared libraries` | run `pkg update && pkg upgrade -y` first (partial upgrades are unsupported) |
| `npm error 'allow-scripts' is not a valid npm option` | **harmless**: older npm lacks the script gate and runs build scripts by default — ignore |
| `CMake does not seem to be available` | re-run the script (toolchain is installed automatically) |
| node-pty: `android_ndk_path` | re-run the script (the common.gypi patch is idempotent) |
| `No command dsh found` after install | the npm step failed; the script now aborts right there with hints (network / disk / build / OOM); add `--cn` and re-run |
| `npm install` step silent for >15 min | network blackhole — Ctrl+C, re-run with `--cn`, or check your proxy/VPN |
| Script exits mid-way without any error (older versions) | fixed: every step now fails loudly. If it still happens, paste the 10 lines around the stop into an issue |
| Web UI cannot read the sdcard / phone storage | run `termux-setup-storage` and allow the permission (Android 11+ needs "All files access" in system settings); make sure `cordis.patch.yml` pins `fs-sandbox.cwd` to `~/storage/shared` |
| `EACCES: permission denied, link ...` when saving sessions | some custom ROMs block `link()`. Step 9 of the script already applies the `link() → rename()` patch — re-run it to fix; see [discussion #248](https://github.com/deepseek-ai/deepseek-harness/discussions/248) |
| Commands fail with `[timed out after Xms]` / `[killed by signal: SIGTERM]` | bash-tool timeout. Use `run_in_background: true` for long commands on slow devices; if every call times out, make sure the kernel is >= 5.13 (Landlock) — the sandbox fallback on older kernels slows each call |
| `Tool call Error unknown tool ""` | the model/API returned a malformed tool call (the streamed `tool_calls` had a missing or late `name`). Use the official `api.deepseek.com` endpoint with model `deepseek-chat` (avoid `deepseek-reasoner` or poorly tool-capable third-party relays) and start a new session |
| bash tool: `SANDBOX_UNAVAILABLE` | the sandbox needs Landlock (kernel >= 5.13). Older kernels need a custom proot runner — see [discussion #136](https://github.com/deepseek-ai/deepseek-harness/discussions/136) |

### How it works (short version)

- Termux clang targets API 24 by default; bionic only exposes `statx()` at API >= 30, hence the `-target aarch64-linux-android30` flag.
- Termux Node reports `process.platform === 'android'`, so node-gyp evaluates a `common.gypi` referencing `android_ndk_path`, which is only defined when Node itself is built with the NDK.
- npm 11.19+ skips install scripts by default, silently dropping koffi/node-pty builds (older npm runs them normally).
- `sharp` ships prebuilds only for linux/darwin/win; Android uses the WebAssembly build `@img/sharp-wasm32`.
- The HMR plugin hard-requires `--expose-internals`, which cannot be set via `NODE_OPTIONS` — only on the command line.

### References

- [deepseek-ai/deepseek-harness discussion #136 — Could not run in Android/Termux [SOLVED]](https://github.com/deepseek-ai/deepseek-harness/discussions/136)
- [deepseek-ai/deepseek-harness discussion #248 — link() fallback proposal](https://github.com/deepseek-ai/deepseek-harness/discussions/248)
- [sharp installation docs](https://sharp.pixelplumbing.com/install)

---

## License

[MIT](./LICENSE)
