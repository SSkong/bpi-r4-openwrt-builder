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
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# 设置默认时区为东八区
sed -i "s|UTC|CST-8|g" package/base-files/files/bin/config_generate

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

# dae ARCH_PACKAGES 匹配修复：
#   dae Makefile 只匹配 aarch64_generic，但 BPI-R4 的 ARCH_PACKAGES 是 aarch64_cortex-a53，
#   导致 DAE_PREBUILT 变量为空、install 段 test -f 失败。
#   追加 aarch64_cortex-a53 分支指向同一预编译路径。
sed -i 's/else ifeq ($(ARCH_PACKAGES),aarch64_generic)/else ifeq ($(ARCH_PACKAGES),aarch64_cortex-a53)\n  DAE_PREBUILT:=$(CURDIR)\/files\/prebuilt\/aarch64\/dae\nelse ifeq ($(ARCH_PACKAGES),aarch64_generic)/' \
  package/custom/luci-app-dae/dae/Makefile 2>/dev/null || true

# fancontrol 旧版子目录清理：
#   commit 7655e6d 仓库含两个 openwrt-feed 目录：
#   - openwrt-feed/（根目录，v3.1.3 完整版，files/ 齐全）
#   - luci-app-fancontrol/openwrt-feed/（子目录，v2.3.1 旧版，files/ 仅 fancontrol.js）
#   SCAN_DEPTH=5 扫到深度更深的旧版 Makefile，但 files/ 不完整导致 install 失败。
#   删除旧版子目录让扫描只发现根目录的完整版。
rm -rf package/custom/luci-app-fancontrol/luci-app-fancontrol/openwrt-feed

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
# sbwml/luci-app-mosdns 含更新的 mosdns v5.3.4（feeds 为 v5.3.3），删除 feeds 链接防顶替
rm -f package/feeds/packages/mosdns

# 移除 feeds 中与 helloworld 冲突的核心代理包源码（helloworld 自带这些包的更新版本）
# 参考 sbwml/openwrt_helloworld README
rm -rf feeds/packages/net/{xray-core,v2ray-core,v2ray-geodata,sing-box}
# 删除 helloworld 中与 custom 冲突的 dae（保留 498777 fork 预编译版）
rm -rf package/helloworld/dae package/helloworld/luci-app-dae
# 更新 golang feeds 为 sbwml 版本（27.x = Go 1.27.1）：
# - helloworld 及自定义包（OpenList 4.2.6 要求 go >= 1.25）需要较新工具链，
#   23.x 的 Go 1.23.12 过旧；27.x 满足全部包的最低版本要求
# - 该包无 BUILD_BOOTSTRAP 选项，EXTERNAL_BOOTSTRAP_ROOT 为空时自动下载
#   go1.24.6 官方引导（x86_64 CI 可直接用）；ARM64 本机需指向外部 Go >= 1.24.6
rm -rf feeds/packages/lang/golang
git clone -q --depth 1 -b 27.x https://github.com/sbwml/packages_lang_golang.git feeds/packages/lang/golang
# 重新 feeds install 让替换与删除全部生效
./scripts/feeds install -a > /dev/null 2>&1 || true

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
# touch Makefile 强制 scan.mk 重新扫描（否则 scan 缓存不包含新增的 i18n 包）
touch package/custom/luci-app-hw-dashboard/Makefile

# ============================================================
# 编译优化（可选）
# ============================================================

# 启用 ccache 加速重编（注意：会增大缓存体积，本仓库默认未启用）
# sed -i '/CONFIG_CCACHE/d' .config && echo 'CONFIG_CCACHE=y' >> .config

echo "✅ diy-part2: 编译前定制完成"
