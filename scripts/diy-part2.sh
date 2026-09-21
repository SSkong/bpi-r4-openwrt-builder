#!/bin/bash
#
# diy-part2.sh —— 在 feeds install 之后、make defconfig 之前执行
# 用途：修改源码默认设置（版本号、管理 IP、时区、主机名等）
# 环境：当前目录为 OpenWrt 源码根目录
#
# 以下均为示例，默认全部注释，按需取消注释即可
#
set -e

# ============================================================
# 固件默认设置定制（取消注释后生效）
# ============================================================

# 修改默认登录 IP（示例改为 192.168.100.1）
# sed -i 's/192.168.1.1/192.168.100.1/g' package/base-files/files/bin/config_generate

# 设置默认时区为东八区
# sed -i "s|UTC|CST-8|g" package/base-files/files/bin/config_generate

# 设置默认主机名
# sed -i "s/ImmortalWrt/BPI-R4/g" package/base-files/files/bin/config_generate

# 修改固件版本号显示（示例：BPI-R4 自用版）
# sed -i "s/DISTRIB_REVISION='.*'/DISTRIB_REVISION='BPI-R4-Custom'/" version.txt 2>/dev/null || true

# ============================================================
# 上游包兼容性修复（必须保留）
# ============================================================

# dae 预编译二进制下载：
#   498777/luci-app-dae 仓库不含预编译二进制（files/prebuilt/aarch64/dae），
#   需从 daeuniverse/dae release 下载 aarch64 静态二进制并放入对应目录。
#   make download 不处理这种"非标准 PKG_SOURCE 的预置文件"。
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

# 修复 luci-theme-graphite / luci-app-graphite / Obsidian-Theme 的 luci.mk include 路径：
#   这三个仓库原始 Makefile 用 `include ../../luci.mk`（假设在 feeds/luci/applications/ 深度），
#   放到 package/custom/ 后路径不对，DUMP 静默失败，包不进 Kconfig。
#   修正为绝对路径 $(TOPDIR)/feeds/luci/luci.mk。
for pkg in luci-theme-graphite luci-app-graphite Obsidian-Theme; do
  [ -f "package/custom/$pkg/Makefile" ] && \
    sed -i 's|include ../../luci\.mk|include $(TOPDIR)/feeds/luci/luci.mk|' "package/custom/$pkg/Makefile"
done

# 修复 luci-theme-footstrap 被 luci feeds 同名包顶替：
#   luci feeds 自带 luci-theme-footstrap，feeds install 检测到 custom 同名后应跳过，
#   但如果 feeds 链接已存在（乱序场景），需删除残留让 custom 版胜出。
rm -f package/feeds/luci/luci-theme-footstrap

# 删除 feeds 中与 custom 同名包的残留链接（防止 feeds 版顶替 custom 版）：
#   ImmortalWrt 25.12 feeds 已内置 dae / open-app-filter / luci-app-dae，
#   feeds install 可能先于 custom 创建链接导致 scan 让 feeds 版胜出。
#   custom 版优先规则要求 feeds 链接不存在；删除后 defconfig 重新扫描使 custom 版生效。
rm -f package/feeds/packages/dae
rm -f package/feeds/packages/open-app-filter
rm -f package/feeds/luci/luci-app-dae

# ============================================================
# Docker feeds 替换（sbwml fork 版，适配 OpenWrt 25.12）
# ============================================================
# sbwml 版 docker/dockerd/containerd/runc 修复了 25.12 兼容性问题，
# luci-app-dockerman 使用 openwrt-25.12 分支。
# 替换的是 feeds 源码（非 package/custom/），不影响来源校验。
rm -rf feeds/luci/applications/luci-app-dockerman
git clone -q --depth 1 -b openwrt-25.12 https://github.com/sbwml/luci-app-dockerman.git feeds/luci/applications/luci-app-dockerman

rm -rf feeds/packages/utils/{docker,dockerd,containerd,runc}
git clone -q --depth 1 https://github.com/sbwml/packages_utils_docker.git feeds/packages/utils/docker
git clone -q --depth 1 https://github.com/sbwml/packages_utils_dockerd.git feeds/packages/utils/dockerd
git clone -q --depth 1 https://github.com/sbwml/packages_utils_containerd.git feeds/packages/utils/containerd
git clone -q --depth 1 https://github.com/sbwml/packages_utils_runc.git feeds/packages/utils/runc

# 重新建立 feeds 索引链接（替换源码后需重新 feeds install -a）
./scripts/feeds install -a > /dev/null 2>&1 || true

# ============================================================
# luci-app-hw-dashboard 中文汉化
# ============================================================
# 上游仓库仅含 po/templates/hw-dashboard.pot 模板，无中文翻译。
# 将仓库中预置的翻译文件拷入 po/zh_Hans/，luci.mk 编译时自动编译为 .mo。
# 注意：OpenWrt 25+ 中文语言代码为 zh_Hans（非旧版 zh-cn）。
mkdir -p package/custom/luci-app-hw-dashboard/po/zh_Hans
cp files/po/zh_Hans/hw-dashboard.po package/custom/luci-app-hw-dashboard/po/zh_Hans/ 2>/dev/null || true

# ============================================================
# 编译优化（可选）
# ============================================================

# 启用 ccache 加速重编（注意：会增大缓存体积，本仓库默认未启用）
# sed -i '/CONFIG_CCACHE/d' .config && echo 'CONFIG_CCACHE=y' >> .config

echo "✅ diy-part2: 编译前定制完成"
