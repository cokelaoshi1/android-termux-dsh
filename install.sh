#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# dsh-termux-installer
# 在 Termux (Android) 上一键安装 DeepSeek Harness (@deepseek-ai/dsh)
# 面向【全新安装的 Termux】：跑完本脚本即可直接使用，无需任何手动步骤。
# 涵盖：pkg 更新 → 基础工具/编译链/Node → npm 配置与镜像 → common.gypi 补丁
#       → dsh 全局安装（原生模块源码编译）→ sharp wasm 兜底 → 启动包装器
#       → sdcard 存储授权与默认工作区 → 逐项验证
#
# 已解决的关键问题：
#   - koffi / node-pty 无 android 预编译，需现场编译
#   - Termux clang 默认 target API 24，statx() 需 API >= 30（-target ...android30）
#   - node-gyp 在 Termux 上报 android_ndk_path 未定义（common.gypi 补丁）
#   - npm install-scripts 安全门跳过构建脚本（allow-scripts 放行）
#   - sharp 无 android-arm64 预编译（@img/sharp-wasm32 WebAssembly 兜底）
#   - HMR 插件硬要求 --expose-internals（dsh 启动包装器）
#
# 用法： bash install.sh [--skip-upgrade] [--cn]
#        --cn            使用 npmmirror 镜像源（中国大陆网络推荐）
# 环境： Termux（F-Droid 版），Android 11+，arm64 / armv7
# =============================================================================
set -euo pipefail

SKIP_UPGRADE=0
CN_MODE=0
for arg in "$@"; do
  case "$arg" in
    --skip-upgrade) SKIP_UPGRADE=1 ;;
    --cn) CN_MODE=1 ;;
    -h|--help) sed -n '1,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数: $arg（可用 --skip-upgrade / --cn）"; exit 1 ;;
  esac
done

log()  { printf '\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m  ✓ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m  ✗ %s\033[0m\n' "$*"; }

# ---- 0. 环境预检 --------------------------------------------------------------
if [ -z "${PREFIX:-}" ]; then
  echo "错误: 未检测到 Termux 环境（\$PREFIX 为空）。请在手机 Termux 里运行本脚本。"
  exit 1
fi

ARCH="$(uname -m)"
case "$ARCH" in
  aarch64) TARGET="aarch64-linux-android30" ;;
  armv7l|armv8l) TARGET="armv7a-linux-androideabi30" ;;
  *)
    warn "未知架构 $ARCH，按 arm64 处理，如编译失败请提交 issue"
    TARGET="aarch64-linux-android30" ;;
esac
log "架构: $ARCH   编译目标: $TARGET"

# 构建很耗时，尽量保持屏幕常亮
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock

# ---- 1. 系统更新与编译工具链 ---------------------------------------------------
if [ "$SKIP_UPGRADE" -eq 0 ]; then
  log "pkg update && pkg upgrade（首次运行较久，务必等它完成）"
  pkg update -y && pkg upgrade -y
else
  warn "已跳过 pkg update/upgrade"
fi

log "安装基础工具与编译工具链: git curl cmake clang make python binutils pkg-config libandroid-spawn"
pkg install -y git curl cmake clang make python binutils pkg-config libandroid-spawn

# ---- 2. Node.js >= 22.12（dsh 依赖 commander 15 的硬性要求）-------------------
if ! command -v node >/dev/null 2>&1; then
  log "安装 nodejs"
  pkg install -y nodejs
fi
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
NODE_MINOR="$(node -p 'process.versions.node.split(".")[1]')"
if [ "$NODE_MAJOR" -lt 22 ] || { [ "$NODE_MAJOR" -eq 22 ] && [ "$NODE_MINOR" -lt 12 ]; }; then
  echo "错误: dsh 需要 Node >= 22.12，当前是 $(node -v)。请先执行 pkg upgrade -y && pkg install nodejs 再重跑本脚本。"
  exit 1
fi
ok "Node $(node -v)"

# ---- 3. npm 镜像与 install-scripts 放行 -----------------------------------------
ALLOW_LIST="@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs"
log "配置 npm allow-scripts 放行原生模块构建脚本"
npm config set allow-scripts="$ALLOW_LIST" --location=user || warn "npm 不支持 allow-scripts 配置（旧版 npm，忽略）"

if [ "$CN_MODE" -eq 1 ]; then
  log "使用 npmmirror 镜像源（--cn）"
  npm config set registry https://registry.npmmirror.com --location=user
  warn "若 pkg 更新源也慢/失败，可运行 termux-change-repo 选择国内镜像"
fi

# ---- 4. node-gyp common.gypi 补丁（android_ndk_path）--------------------------
log "预下载 Node 头文件并修补 common.gypi"
NODE_GYP="$(npm root -g)/npm/node_modules/node-gyp/bin/node-gyp.js"
if [ -f "$NODE_GYP" ]; then
  node "$NODE_GYP" install || warn "node-gyp 头文件预下载失败（安装过程会自动重试）"
fi

patch_common_gypi() {
  local patched=0
  local f
  for f in "$HOME"/.cache/node-gyp/*/include/node/common.gypi; do
    [ -f "$f" ] || continue
    if grep -q "android_ndk_path%'" "$f"; then
      patched=1
      continue
    fi
    python3 - "$f" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
i = s.index("'variables': {") + len("'variables': {")
s = s[:i] + "\n    'android_ndk_path%': ''," + s[i:]
open(p, "w").write(s)
PY
    ok "已修补 $f"
    patched=1
  done
  [ "$patched" -eq 0 ] && warn "未找到 node-gyp 缓存；若安装时 node-pty 报 android_ndk_path，重跑本脚本即可"
}
patch_common_gypi

# ---- 5. 全局安装 @deepseek-ai/dsh ---------------------------------------------
log "npm install -g @deepseek-ai/dsh（koffi 源码编译需要几分钟）"
export CFLAGS="-target $TARGET"
export CXXFLAGS="-target $TARGET"
if ! npm install -g --foreground-scripts @deepseek-ai/dsh; then
  warn "首次安装失败，修补 common.gypi 后重试一次"
  patch_common_gypi
  if [ "$CN_MODE" -eq 0 ]; then
    warn "仍失败则自动切换 npmmirror 镜像源再试（中国大陆网络常见）"
    npm config set registry https://registry.npmmirror.com --location=user || true
  fi
  npm install -g --foreground-scripts @deepseek-ai/dsh
fi
unset CFLAGS CXXFLAGS

# 硬性检查：npm 装完必须有 dsh 命令，否则立刻报错（而不是最后才暴露）
if ! command -v dsh >/dev/null 2>&1; then
  echo ""
  echo "✗✗ 错误: npm 安装结束后仍未找到 dsh 命令 ✗✗"
  echo "   说明上面 npm install 实际失败了（常见原因）："
  echo "   1) 网络问题：npm 官方源超时/断连 —— 中国大陆网络请加 --cn 参数重跑，或先: npm config set registry https://registry.npmmirror.com"
  echo "   2) 磁盘空间不足 —— 检查: df -h \$PREFIX"
  echo "   3) 编译失败 —— 向上翻终端找 \"npm error\" 开头的行，把最后 20 行发到仓库 issue"
  echo "   4) 若反复失败，可重跑本脚本（幂等，会自动续上）"
  exit 1
fi
ok "dsh 命令已就位: $(command -v dsh)"

D="$PREFIX/lib/node_modules/@deepseek-ai/dsh"
[ -d "$D" ] || { echo "错误: 安装完成后未找到 $D"; exit 1; }

# ---- 6. sharp WebAssembly 兜底（sharp 无 android-arm64 预编译）-----------------
SHARP_VER="$(python3 -c "import json;print(json.load(open('$D/node_modules/sharp/package.json'))['version'])")"
log "安装 sharp@$SHARP_VER 的 WebAssembly 兜底 (@img/sharp-wasm32)"
mkdir -p "$HOME/.dsh-termux-sw" && cd "$HOME/.dsh-termux-sw" && npm init -y >/dev/null 2>&1
npm install --no-save "@img/sharp-wasm32@$SHARP_VER" >/dev/null
rm -rf "$D/node_modules/@img/sharp-wasm32" "$D/node_modules/@emnapi"
cp -r node_modules/@img/sharp-wasm32 "$D/node_modules/@img/"
cp -r node_modules/@emnapi "$D/node_modules/"
cd "$HOME" && rm -rf "$HOME/.dsh-termux-sw"
ok "sharp wasm 兜底已就位"

# ---- 7. dsh 启动包装器（HMR 插件硬要求 --expose-internals）---------------------
log "安装 dsh 启动包装器（--expose-internals）"
rm -f "$PREFIX/bin/dsh"
cat > "$PREFIX/bin/dsh" <<EOF
#!$PREFIX/bin/sh
exec node --expose-internals $D/lib/bin.js "\$@"
EOF
chmod +x "$PREFIX/bin/dsh"
ok "包装器已写入 $PREFIX/bin/dsh"

# ---- 8. pnpm（dsh plugin 子命令依赖）------------------------------------------
if ! command -v pnpm >/dev/null 2>&1; then
  log "安装 pnpm（dsh plugin 管理用）"
  npm install -g pnpm
fi

# ---- 8.5 sdcard 存储权限 + 默认工作区（Android 11+ 作用域存储）------------------
# 网页版无法读 sdcard 通常有两层原因：
#   1) Termux 应用没有存储权限 -> termux-setup-storage 授权并生成 ~/storage/shared
#   2) dsh 默认工作区是启动目录 -> 在 cordis.patch.yml 里把 fs-sandbox.cwd
#      固定到 sdcard，浏览器 UI 的文件树/工作区就直接落在手机存储上
# 可用环境变量覆盖：DSH_WORKSPACE=/path/to/dir  或  DSH_WORKSPACE="" 跳过此步
log "配置 sdcard 访问（默认工作区 = ~/storage/shared）"
if command -v termux-setup-storage >/dev/null 2>&1; then
  echo "  → 若弹出存储权限对话框，请点击“允许”；Android 11+ 会跳转“所有文件访问”设置页"
  termux-setup-storage || warn "termux-setup-storage 未完成，请手动授权后重跑本脚本"
fi

WORKSPACE="${DSH_WORKSPACE:-$HOME/storage/shared}"
if [ -n "$WORKSPACE" ]; then
  if [ -d "$WORKSPACE" ]; then
    mkdir -p "$HOME/.dsh/profiles/web"
    PATCH="$HOME/.dsh/profiles/web/cordis.patch.yml"
    if grep -q "id: fs-sandbox" "$PATCH" 2>/dev/null; then
      ok "cordis.patch.yml 已含 fs-sandbox 工作区配置"
    elif [ -s "$PATCH" ] && ! grep -qE '^[[:space:]]*\[\][[:space:]]*$' "$PATCH"; then
      printf '\n- id: fs-sandbox\n  config:\n    cwd: %s\n' "$WORKSPACE" >> "$PATCH"
      ok "已追加 fs-sandbox 工作区配置 -> $WORKSPACE"
    else
      cat > "$PATCH" <<EOF
# dsh profile patch layer (generated by android-termux-dsh)
# 默认工作区固定在 sdcard；如需修改请改下面 cwd，或删除本段恢复默认
- id: fs-sandbox
  config:
    cwd: $WORKSPACE
EOF
      ok "已写入默认工作区配置 -> $WORKSPACE"
    fi
  else
    warn "未找到 $WORKSPACE —— sdcard 权限未生效。"
    warn "请到 系统设置 → 应用 → Termux → 权限，允许“文件和媒体”（Android 11+ 为“所有文件访问”），然后重跑本脚本"
  fi
else
  warn "已跳过 sdcard 工作区配置（DSH_WORKSPACE 为空）"
fi

# ---- 9. 验证 --------------------------------------------------------------------
echo ""
echo "==================== 验证 ===================="
FAIL=0
if dsh --version >/dev/null 2>&1; then ok "dsh"; else fail "dsh"; FAIL=1; fi
if (cd "$D" && node --input-type=module -e "await import('koffi')" >/dev/null 2>&1); then
  ok "koffi（原生 FFI 可加载）"
else
  fail "koffi 无法加载"; FAIL=1
fi
if [ -f "$D/node_modules/node-pty/build/Release/pty.node" ]; then
  ok "node-pty（pty.node 已编译）"
else
  fail "node-pty 未编译"; FAIL=1
fi
if (cd "$D" && node --input-type=module -e "const s=(await import('sharp')).default; if(!s.versions)process.exit(1)" >/dev/null 2>&1); then
  ok "sharp（WebAssembly 版可加载）"
else
  fail "sharp 无法加载"; FAIL=1
fi
if [ -d "$HOME/storage/shared" ]; then
  ok "sdcard（$HOME/storage/shared）可访问，默认工作区已就绪"
else
  warn "sdcard 暂不可访问——运行 dsh web 后如无法读取手机存储，请先执行 termux-setup-storage 并授权"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "✅ 全部通过！启动方式："
  echo ""
  echo "   dsh web"
  echo ""
  echo "   然后："
  echo "   - 手机浏览器打开 http://127.0.0.1:3080"
  echo "   - 或在 Termux 里执行:  termux-open-url http://127.0.0.1:3080"
  echo "   - 电脑访问:  dsh web --host 0.0.0.0  然后用 http://手机局域网IP:3080"
  echo ""
  echo "   首次使用请在 Web UI 的 设置 → 模型 里配置 LLM API Key。"
  echo "   默认工作区已固定在 sdcard（~/storage/shared），网页版可直接读写手机存储。"
  echo "   注意：重新 npm 安装 dsh 后，需重跑本脚本恢复 sharp 兜底、启动包装器与工作区配置。"
else
  echo "⚠️ 部分验证未通过，请查看上方 ✗ 项，或到 GitHub 仓库提交 issue。"
  exit 1
fi
