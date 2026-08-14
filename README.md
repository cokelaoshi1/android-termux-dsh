# android-termux-dsh

> One-click installer for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (`@deepseek-ai/dsh`) on **Android / Termux**
> 在 **Android / Termux** 上一键安装 DeepSeek Harness（`@deepseek-ai/dsh`）的脚本

![platform](https://img.shields.io/badge/platform-Android%20%2F%20Termux-green)
![arch](https://img.shields.io/badge/arch-arm64%20%7C%20armv7-blue)
![license](https://img.shields.io/badge/license-MIT-yellow)

[中文](#中文) | [English](#english)

---

## 中文

### 简介

在 **Android Termux** 上无痛安装 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（`@deepseek-ai/dsh`），解决官方 `npm i -g` 在 Android/arm64 上无法完成的一连串原生编译与运行时问题。**无需 root**（有 root 也不影响），已在 **Android 16 / aarch64 / Termux** 实测通过。

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
- 架构：arm64（主流）或 armv7（脚本自动适配）

### 快速开始

```sh
pkg install -y git
git clone https://github.com/cokelaoshi1/android-termux-dsh.git
cd android-termux-dsh
bash install.sh
```

或一行流（免 clone）：

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/cokelaoshi1/android-termux-dsh/main/install.sh)"
```

> 脚本会执行 `pkg upgrade`，**务必等它跑完**。想跳过系统更新：`bash install.sh --skip-upgrade`。
>
> 🇨🇳 **中国大陆网络**：npm 官方源可能超时，加 `--cn` 参数改用 npmmirror 镜像：`bash install.sh --cn`；`pkg` 更新源慢可运行 `termux-change-repo` 选国内镜像。
>
> 安装结束后若提示 `No command dsh found`，说明 npm 安装步骤失败了——脚本现在会在失败点直接报错并给出排查提示（网络/磁盘/编译），或把最后 20 行输出发到 issue。

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

### 脚本做了什么

1. 环境预检（Termux / 架构）
2. `pkg update && pkg upgrade`
3. 安装编译工具链
4. 检查 Node >= 22.12（dsh 的硬性要求）
5. 放行 npm install-scripts
6. 修补 node-gyp `common.gypi`（`android_ndk_path`）
7. `npm i -g @deepseek-ai/dsh`（带 API 30 编译参数，koffi 源码编译）
8. 安装 sharp WebAssembly 兜底
9. 安装 `--expose-internals` 启动包装器 + pnpm
10. sdcard 存储授权 + 默认工作区配置（fs-sandbox.cwd → `~/storage/shared`）
11. 逐项验证（dsh / koffi / node-pty / sharp / sdcard）

脚本**幂等**：任何一步失败直接重跑即可续上；重新执行过 `npm i -g @deepseek-ai/dsh` 后，也建议重跑一次恢复第 8、9、10 步。

### 故障排查

| 现象 | 处理 |
|------|------|
| node 启动报 OpenSSL 符号错误 / `error while loading shared libraries` | 先 `pkg update && pkg upgrade -y`（Termux 不支持部分升级） |
| `CMake does not seem to be available` | 重跑脚本（会自动补装工具链） |
| node-pty 报 `android_ndk_path` | 重跑脚本（common.gypi 补丁幂等） |
| 网页版读不了 sdcard / 看不到手机存储 | 运行 `termux-setup-storage` 并允许权限（Android 11+ 需在系统设置中开启「所有文件访问」）；再确认 `~/.dsh/profiles/web/cordis.patch.yml` 里有 `fs-sandbox` 的 `cwd` 指向 `~/storage/shared` |
| 会话保存报 `EACCES: permission denied, link ...` | 部分定制 ROM 全局禁用 `link()`。参考 [discussion #248](https://github.com/deepseek-ai/deepseek-harness/discussions/248) 把 `link()` 改成 `rename()` |
| bash 工具报 `SANDBOX_UNAVAILABLE` | 沙箱需要 Landlock（内核 >= 5.13）。老内核机型需自建 proot runner，见 [discussion #136](https://github.com/deepseek-ai/deepseek-harness/discussions/136) |

### 原理简述

- Termux 的 clang 默认 target API 24，而 bionic 的 `statx()` 声明要 API >= 30 才可见，编译必须加 `-target aarch64-linux-android30`；
- Termux 的 Node 把 `process.platform` 报成 `android`，node-gyp 会解析引用 `android_ndk_path` 的 `common.gypi`，而该变量只在用 NDK 编译 Node 时才定义；
- npm 11.19+ 默认拦截 install-scripts，导致 koffi/node-pty 的构建脚本静默不执行；
- `sharp` 只提供 linux/darwin/win 预编译，Android 需用其 WebAssembly 版本 `@img/sharp-wasm32`；
- HMR 插件需要 `--expose-internals`，该参数无法通过 `NODE_OPTIONS` 传入，只能改启动命令行。

### 参考

- [deepseek-ai/deepseek-harness discussion #136 — Could not run in Android/Termux [SOLVED]](https://github.com/deepseek-ai/deepseek-harness/discussions/136)
- [deepseek-ai/deepseek-harness discussion #248 — link() fallback 提案](https://github.com/deepseek-ai/deepseek-harness/discussions/248)
- [sharp 安装文档](https://sharp.pixelplumbing.com/install)

---

## English

### About

Pain-free installation of [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (`@deepseek-ai/dsh`) on **Android via Termux**, fixing the chain of native build & runtime issues that make the official `npm i -g` fail on Android/arm64. **No root required.** Verified on **Android 16 / aarch64 / Termux**.

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
- arm64 (mainstream) or armv7 (auto-detected)

### Quick start

```sh
pkg install -y git
git clone https://github.com/cokelaoshi1/android-termux-dsh.git
cd android-termux-dsh
bash install.sh
```

One-liner (no clone):

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/cokelaoshi1/android-termux-dsh/main/install.sh)"
```

> The script runs `pkg upgrade` — **let it finish**. Skip it with `bash install.sh --skip-upgrade`.
>
> 🇨🇳 **Mainland China network**: npm's official registry may time out — add `--cn` to use the npmmirror mirror: `bash install.sh --cn`; if `pkg` mirrors are slow, run `termux-change-repo`.
>
> If you see `No command dsh found` after the install, the npm step failed — the script now aborts right there with hints (network / disk / build). Paste the last 20 lines into an issue.

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

### What the script does

1. Preflight checks (Termux / architecture)
2. `pkg update && pkg upgrade`
3. Install the build toolchain
4. Ensure Node >= 22.12 (hard requirement)
5. Allow npm install-scripts
6. Patch node-gyp `common.gypi` (`android_ndk_path`)
7. `npm i -g @deepseek-ai/dsh` (API 30 target; koffi built from source)
8. Install the sharp WebAssembly fallback
9. Install the `--expose-internals` launcher wrapper + pnpm
10. Grant sdcard storage + pin the workspace (`fs-sandbox.cwd` → `~/storage/shared`)
11. Verify each piece (dsh / koffi / node-pty / sharp / sdcard)

The script is **idempotent**: re-run it after any failure to continue; re-run it too after reinstalling dsh via npm to restore steps 8–10.

### Troubleshooting

| Symptom | Fix |
|---------|-----|
| Node fails with an OpenSSL symbol error / `error while loading shared libraries` | run `pkg update && pkg upgrade -y` first (partial upgrades are unsupported) |
| `CMake does not seem to be available` | re-run the script (toolchain is installed automatically) |
| node-pty: `android_ndk_path` | re-run the script (the common.gypi patch is idempotent) |
| Web UI cannot read the sdcard / phone storage | run `termux-setup-storage` and allow the permission (Android 11+ needs "All files access" in system settings); make sure `~/.dsh/profiles/web/cordis.patch.yml` pins `fs-sandbox.cwd` to `~/storage/shared` |
| `EACCES: permission denied, link ...` when saving sessions | some custom ROMs block `link()`. See [discussion #248](https://github.com/deepseek-ai/deepseek-harness/discussions/248) and switch `link()` → `rename()` |
| bash tool: `SANDBOX_UNAVAILABLE` | the sandbox needs Landlock (kernel >= 5.13). Older kernels need a custom proot runner — see [discussion #136](https://github.com/deepseek-ai/deepseek-harness/discussions/136) |

### How it works (short version)

- Termux clang targets API 24 by default; bionic only exposes `statx()` at API >= 30, hence the `-target aarch64-linux-android30` flag.
- Termux Node reports `process.platform === 'android'`, so node-gyp evaluates a `common.gypi` referencing `android_ndk_path`, which is only defined when Node itself is built with the NDK.
- npm 11.19+ skips install scripts by default, silently dropping koffi/node-pty builds.
- `sharp` ships prebuilds only for linux/darwin/win; Android uses the WebAssembly build `@img/sharp-wasm32`.
- The HMR plugin hard-requires `--expose-internals`, which cannot be set via `NODE_OPTIONS` — only on the command line.

### References

- [deepseek-ai/deepseek-harness discussion #136 — Could not run in Android/Termux [SOLVED]](https://github.com/deepseek-ai/deepseek-harness/discussions/136)
- [deepseek-ai/deepseek-harness discussion #248 — link() fallback proposal](https://github.com/deepseek-ai/deepseek-harness/discussions/248)
- [sharp installation docs](https://sharp.pixelplumbing.com/install)

---

## License

[MIT](./LICENSE)
