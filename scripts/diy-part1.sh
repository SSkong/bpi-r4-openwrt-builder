#!/bin/bash
#
# diy-part1.sh —— 在 feeds update 之前执行
# 用途：注入第三方软件源 + git clone 自定义软件包
# 环境：当前目录为 OpenWrt 源码根目录
#
set -e

# ============================================================
# 一、从 monorepo 获取全部第三方包 + feeds 源
#
# SSkong/openwrt-packages 聚合了全部自定义包（submodule）与三个 feeds 仓库
# （openwrt-passwall-packages / openwrt-passwall / helloworld），
# 每天自动同步上游更新，编译时只需 clone 一次。
# feeds 仓库用 src-link 指向本地 clone 路径，feeds update 无需再次网络 clone。
# ============================================================

MONOREPO_DIR="/tmp/openwrt-packages"

# 单次 clone 获取全部第三方包 + feeds 源（含子模块，--depth 1 浅克隆）
rm -rf "$MONOREPO_DIR"
git clone -q --depth 1 --recurse-submodules \
  https://github.com/SSkong/openwrt-packages.git "$MONOREPO_DIR"

# --- feeds 注入（src-link 指向 monorepo 本地路径，无需再次 clone）---
# passwall-packages: 代理核心（xray/sing-box/hysteria/shadowsocks-rust 等）
# passwall:          luci-app-passwall / luci-app-passwall2
# helloworld:        luci-app-ssr-plus + 额外核心（分支 dev）
# 三源同名包由 feeds install 按声明顺序去重，先声明者优先
sed -i '/passwall_packages/d; /openwrt-passwall/d; /src-git passwall /d; /src-link passwall /d; /helloworld/d; /sbwml\/openwrt_helloworld/d' feeds.conf.default
echo "src-link passwall_packages $MONOREPO_DIR/openwrt-passwall-packages" >> feeds.conf.default
echo "src-link passwall $MONOREPO_DIR/openwrt-passwall" >> feeds.conf.default
echo "src-link helloworld $MONOREPO_DIR/helloworld" >> feeds.conf.default

# ============================================================
# 二、自定义 LuCI 应用与工具包（从 monorepo 复制到 package/custom/）
# ============================================================

rm -rf package/custom
mkdir -p package/custom

# 复制所有包目录到 package/custom/，排除 feeds 仓库与 .github/.git
for d in "$MONOREPO_DIR"/*/; do
  name=$(basename "$d")
  case "$name" in
    .github|openwrt-passwall-packages|openwrt-passwall|helloworld) continue ;;
  esac
  mkdir -p "package/custom/$name"
  cp -a "$d". "package/custom/$name/"
  rm -rf "package/custom/$name/.git"
done

# fancontrol 锁定 commit 7655e6d（上游 HEAD 有破坏性变更，monorepo 同步工作流也锁定此 commit）
FANCTRL_SHA="7655e6d624e7d277cf5cb617584a638b08b672d7"
if ! grep -q "$FANCTRL_SHA" package/custom/luci-app-fancontrol/.git/HEAD 2>/dev/null; then
  rm -rf package/custom/luci-app-fancontrol
  git clone -q --depth 1 https://github.com/bigmalloy/luci-app-fancontrol.git /tmp/fancontrol
  cd /tmp/fancontrol
  git fetch -q --depth 1 origin "$FANCTRL_SHA"
  git checkout -q "$FANCTRL_SHA"
  cd - >/dev/null
  cp -a /tmp/fancontrol package/custom/luci-app-fancontrol
  rm -rf package/custom/luci-app-fancontrol/.git /tmp/fancontrol
fi

# 注意：MONOREPO_DIR 不在此处清理——feeds update 需要读取 src-link 指向的本地路径
# 清理在 diy-part2.sh（feeds install 之后）执行

echo "===== 自定义包 Makefile 扫描结果 ====="
find package/custom -maxdepth 3 -name Makefile -not -path '*/.git/*' \
  -exec grep -l 'call BuildPackage\|Build/DefaultTargets\|KernelPackage' {} + \
  || { echo "❌ 自定义包 clone 后未发现任何有效 Makefile"; exit 1; }

echo "✅ diy-part1: 自定义软件源注入 + 自定义包 clone 完成"
