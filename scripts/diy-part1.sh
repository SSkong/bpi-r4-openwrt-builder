#!/bin/bash
#
# diy-part1.sh —— 在 feeds update 之前执行
# 用途：注入第三方软件源 + git clone 自定义软件包
# 环境：当前目录为 OpenWrt 源码根目录
#
set -e

# ============================================================
# 一、科学上网软件源（上游 Openwrt-Passwall + fw876/helloworld）
# passwall-packages: 代理核心（xray/sing-box/hysteria/shadowsocks-rust 等）
# passwall:          luci-app-passwall / luci-app-passwall2
# helloworld:        luci-app-ssr-plus + 额外核心（分支 dev）
# 三源同名包由 feeds install 按声明顺序去重，先声明者优先
# ============================================================

# 注入 feeds（幂等：先删旧条目再追加）
sed -i '/passwall_packages/d; /openwrt-passwall-packages/d; /src-git passwall /d; /Openwrt-Passwall\/openwrt-passwall\.git/d; /src-git helloworld/d; /fw876\/helloworld/d; /sbwml\/openwrt_helloworld/d' feeds.conf.default
echo 'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main' >> feeds.conf.default
echo 'src-git passwall https://github.com/Openwrt-Passwall/openwrt-passwall.git;main' >> feeds.conf.default
echo 'src-git helloworld https://github.com/fw876/helloworld.git;dev' >> feeds.conf.default

# ============================================================
# 二、自定义 LuCI 应用与工具包（从 SSkong/openwrt-packages monorepo 拉取）
#
# 所有第三方包聚合在 SSkong/openwrt-packages 仓库中（Git submodule 镜像），
# monorepo 每周自动同步上游更新，编译时只需 clone 一次即可获取全部包。
# 仓库地址: https://github.com/SSkong/openwrt-packages
# 包含: 55 个 submodule + luci-app-ap-modem（从 OpenWrt-Add 提取）
#       + luci-app-model-gateway（预编译 Makefile + .lmo，非 git 仓库）
# ============================================================

rm -rf package/custom
mkdir -p package/custom

# 单次 clone 获取全部第三方包（含子模块，--depth 1 浅克隆）
# monorepo: https://github.com/SSkong/openwrt-packages（55 submodules + 本地文件）
git clone -q --depth 1 --recurse-submodules \
  https://github.com/SSkong/openwrt-packages.git /tmp/openwrt-packages

# 复制所有包目录到 package/custom/，排除 .git 目录减小体积
for d in /tmp/openwrt-packages/*/; do
  name=$(basename "$d")
  [ "$name" = ".github" ] && continue
  mkdir -p "package/custom/$name"
  cp -a "$d". "package/custom/$name/"
  rm -rf "package/custom/$name/.git"
done

# fancontrol 锁定 commit 7655e6d（上游 HEAD 有破坏性变更，同步工作流也锁定此 commit）
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

# 清理临时目录
rm -rf /tmp/openwrt-packages

echo "===== 自定义包 Makefile 扫描结果 ====="
find package/custom -maxdepth 3 -name Makefile -not -path '*/.git/*' \
  -exec grep -l 'call BuildPackage\|Build/DefaultTargets\|KernelPackage' {} + \
  || { echo "❌ 自定义包 clone 后未发现任何有效 Makefile"; exit 1; }

echo "✅ diy-part1: 自定义软件源注入 + 自定义包 clone 完成"
