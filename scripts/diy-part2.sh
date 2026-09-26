#!/bin/bash
#
# diy-part2.sh —— 在 feeds install 之后、make defconfig 之前执行
# 用途：修改源码默认设置 + 上游包兼容性修复 + feeds 源码替换
# 环境：当前目录为 OpenWrt 源码根目录
#
set -e

# ============================================================
# 固件默认设置定制
# ============================================================

# 修改默认登录 IP
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# 设置默认时区为东八区
sed -i "s|UTC|CST-8|g" package/base-files/files/bin/config_generate

# 设置默认主机名（按需取消注释）
# sed -i "s/ImmortalWrt/BPI-R4/g" package/base-files/files/bin/config_generate

# 修改固件版本号显示（按需取消注释）
# sed -i "s/DISTRIB_REVISION='.*'/DISTRIB_REVISION='BPI-R4-Custom'/" version.txt 2>/dev/null || true

# ============================================================
# 上游包兼容性修复
# ============================================================

# dae 预编译二进制下载：
#   498777/luci-app-dae 不含预编译二进制，需从 daeuniverse/dae release 下载 aarch64 静态二进制
DAE_VER=$(grep 'DAE_RELEASE:=' package/custom/luci-app-dae/dae/Makefile 2>/dev/null | sed "s/.*:=//; s/ //g")
if [ -n "$DAE_VER" ] && [ ! -f "package/custom/luci-app-dae/dae/files/prebuilt/aarch64/dae" ]; then
  echo "📥 下载 dae 预编译二进制 ($DAE_VER aarch64)..."
  mkdir -p package/custom/luci-app-dae/dae/files/prebuilt/aarch64
  wget -q "https://github.com/daeuniverse/dae/releases/download/${DAE_VER}/dae-linux-arm64.tar.xz" -O /tmp/dae-arm64.tar.xz \
    && tar -xf /tmp/dae-arm64.tar.xz -C /tmp/ --strip-components=1 \
    && mv /tmp/usr/bin/dae package/custom/luci-app-dae/dae/files/prebuilt/aarch64/dae \
    && rm -f /tmp/dae-arm64.tar.xz && rm -rf /tmp/usr \
    && echo "✅ dae 二进制就位" \
    || { echo "❌ dae 二进制下载失败"; rm -f /tmp/dae-arm64.tar.xz; }
fi

# dae ARCH_PACKAGES 匹配修复：
#   Makefile 只匹配 aarch64_generic，但 BPI-R4 的 ARCH_PACKAGES 是 aarch64_cortex-a53
#   追加 cortex-a53 分支指向同一预编译路径
sed -i 's/else ifeq ($(ARCH_PACKAGES),aarch64_generic)/else ifeq ($(ARCH_PACKAGES),aarch64_cortex-a53)\n  DAE_PREBUILT:=$(CURDIR)\/files\/prebuilt\/aarch64\/dae\nelse ifeq ($(ARCH_PACKAGES),aarch64_generic)/' \
  package/custom/luci-app-dae/dae/Makefile 2>/dev/null || true

# fancontrol 旧版子目录清理：
#   commit 7655e6d 仓库含两个 openwrt-feed 目录，深层的旧版 files/ 不完整会导致 install 失败
rm -rf package/custom/luci-app-fancontrol/luci-app-fancontrol/openwrt-feed

# 修复 luci.mk include 路径：
#   graphite / Obsidian-Theme 原始 Makefile 用相对路径 include ../../luci.mk，
#   放到 package/custom/ 后路径不对，修正为绝对路径
for pkg in luci-theme-graphite luci-app-graphite Obsidian-Theme; do
  [ -f "package/custom/$pkg/Makefile" ] && \
    sed -i 's|include ../../luci\.mk|include $(TOPDIR)/feeds/luci/luci.mk|' "package/custom/$pkg/Makefile"
done

# 修复 luci-theme-footstrap 被 luci feeds 同名包顶替：
#   删除 feeds 残留链接让 custom 版胜出
rm -f package/feeds/luci/luci-theme-footstrap

# ============================================================
# feeds 同名包冲突清理（防止 feeds 版顶替 custom 版）
# ============================================================

# ImmortalWrt 25.12 feeds 已内置 dae / open-app-filter / luci-app-dae，删除 feeds 链接
rm -f package/feeds/packages/dae
rm -f package/feeds/packages/open-app-filter
rm -f package/feeds/luci/luci-app-dae
# sbwml/luci-app-mosdns 含更新的 mosdns v5.3.4（feeds 为 v5.3.3）
rm -f package/feeds/packages/mosdns

# 移除 feeds 中与 helloworld 冲突的核心代理包源码（helloworld 自带更新版本）
rm -rf feeds/packages/net/{xray-core,v2ray-core,v2ray-geodata,sing-box}
# 删除 helloworld 中与 custom 冲突的 dae（保留 498777 fork 预编译版）
rm -rf package/helloworld/dae package/helloworld/luci-app-dae

# ============================================================
# feeds 源码替换
# ============================================================

# golang feeds 替换为 sbwml 26.x（Go 1.26.8）：
# - OpenList 4.2.6 要求 go >= 1.25，Go 1.26.8 满足
# - 27.x (Go 1.27.1) 下 GOTOOLCHAIN=local 部分包的 internal 模块依赖
#   无法解析（实测 AdGuardHome 0.107.78 报 no required module），26.x 兼容性最广
# - 该包无 BUILD_BOOTSTRAP，CI 上 EXTERNAL_BOOTSTRAP_ROOT 为空时自动下载官方引导；
#   ARM64 本机需指向外部 Go >= 1.24.6
rm -rf feeds/packages/lang/golang
git clone -q --depth 1 -b 26.x https://github.com/sbwml/packages_lang_golang.git feeds/packages/lang/golang

# Docker feeds 替换为 sbwml fork 版（适配 OpenWrt 25.12）：
# - 修复 docker/dockerd/containerd/runc 25.12 兼容性问题
# - luci-app-dockerman 使用 openwrt-25.12 分支
# - 替换的是 feeds 源码（非 package/custom/），不影响来源校验
rm -rf feeds/luci/applications/luci-app-dockerman
git clone -q --depth 1 -b openwrt-25.12 https://github.com/sbwml/luci-app-dockerman.git feeds/luci/applications/luci-app-dockerman

rm -rf feeds/packages/utils/{docker,dockerd,containerd,runc}
git clone -q --depth 1 https://github.com/sbwml/packages_utils_docker.git feeds/packages/utils/docker
git clone -q --depth 1 https://github.com/sbwml/packages_utils_dockerd.git feeds/packages/utils/dockerd
git clone -q --depth 1 https://github.com/sbwml/packages_utils_containerd.git feeds/packages/utils/containerd
git clone -q --depth 1 https://github.com/sbwml/packages_utils_runc.git feeds/packages/utils/runc

# 重新 feeds install 让所有替换与删除生效
./scripts/feeds install -a > /dev/null 2>&1 || true

# ============================================================
# 汉化与翻译目录修复
# ============================================================

# luci-app-hw-dashboard 中文汉化：
#   上游仅含 po/templates 模板，将预置翻译文件拷入 po/zh_Hans/
mkdir -p package/custom/luci-app-hw-dashboard/po/zh_Hans
cp files/po/zh_Hans/hw-dashboard.po package/custom/luci-app-hw-dashboard/po/zh_Hans/ 2>/dev/null || true
# touch Makefile 强制 scan.mk 重新扫描（否则 scan 缓存不包含新增的 i18n 包）
touch package/custom/luci-app-hw-dashboard/Makefile

# 通用翻译目录适配：OpenWrt 25.12 中文语言代码为 zh_Hans（非旧版 zh-cn）
#   上游仓库多按旧规范建 po/zh-cn，luci.mk 的 LUCI_LANG 只认 zh_Hans，
#   po/zh-cn 不会被扫描生成 i18n 包。递归查找统一重命名为 zh_Hans：
#   - 包本身已有 zh_Hans 目录（如 change-mac）→ 跳过，避免覆盖上游新版翻译
#   - Makefile 硬编码引用 po/zh-cn 的包（如 w9315273 adguardhome 自行
#     po2lmo 直接生成 .zh-cn.lmo，不走 luci.mk 流程）→ 跳过，改名会破坏路径
#   - honk 等包在二级子目录（repo/app/po），故用 find 递归而非固定路径
find package/custom -type d -name zh-cn | while read -r d; do
  pkgroot="${d%/po/zh-cn}"
  if grep -q -- 'po/zh-cn' "$pkgroot/Makefile" 2>/dev/null; then
    echo "  跳过翻译改名（Makefile 硬编码 po/zh-cn）: $pkgroot"
    continue
  fi
  if [ ! -d "${d%/zh-cn}/zh_Hans" ]; then
    mv "$d" "${d%/zh-cn}/zh_Hans"
    echo "  翻译目录已适配: $pkgroot (zh-cn → zh_Hans)"
    # touch 包 Makefile 强制 scan.mk 重新扫描 i18n 包定义
    find "$pkgroot" -maxdepth 2 -name Makefile -exec touch {} + 2>/dev/null || true
  fi
done

# ============================================================
# 编译优化（可选，按需取消注释）
# ============================================================

# 启用 ccache 加速重编（会增大缓存体积）
# sed -i '/CONFIG_CCACHE/d' .config && echo 'CONFIG_CCACHE=y' >> .config

echo "✅ diy-part2: 编译前定制完成"
