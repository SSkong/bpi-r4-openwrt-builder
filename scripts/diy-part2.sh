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

# node 版本固定（sbwml/feeds_packages_lang_node）：
#   Makefile 的 PKG_VERSION 动态 curl GitHub API 取最新 tag，但 sbwml/node_workflow
#   最新 release 可能尚未构建全架构（如 v24.21.0 仅有 riscv64），导致 aarch64 下载 404、
#   Build/Compile 子 shell 静默失败、install 步骤找不到二进制。
#   固定到有完整 aarch64_cortex-a53 资产的版本；上游补全后再解除。
NODE_MAKEFILE="package/custom/node/Makefile"
if [ -f "$NODE_MAKEFILE" ]; then
  sed -i 's|PKG_VERSION:=.*|PKG_VERSION:=22.23.2|' "$NODE_MAKEFILE"
  echo "  node 版本固定为 22.23.2（sbwml/node_workflow v22.23.2 有完整 aarch64 资产）"
fi

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

# tachyon 集成补丁（已禁用，恢复时取消注释）：
#   ① CONFLICTS 去掉 luci-app-passwall/passwall2 —— 上游声明双流量编排器冲突，
#      本固件为全家桶设计（多编排器共存、运行时只启用一个），打补丁允许共存
#   ② 版本号默认 1.4.5 —— 上游 Makefile 未传 TACHYON_VERSION 时回落 0.0.0；
#      CI 浅克隆 submodule 无 tags，无法 git describe，故内联默认值
#   ③ LUCI_LANGUAGES 增加 zh_Hans —— 上游仅 en/ru，luci.mk 只构建声明过的语言
# TACHYON_DIR="package/custom/tachyon"
# sed -i 's|^\tCONFLICTS:=https-dns-proxy nextdns luci-app-passwall luci-app-passwall2$|\tCONFLICTS:=https-dns-proxy nextdns|' \
#   "$TACHYON_DIR/tachyon/Makefile"
# sed -i 's|$(or $(TACHYON_PACKAGE_VERSION),$(TACHYON_VERSION))|$(or $(TACHYON_PACKAGE_VERSION),$(TACHYON_VERSION),1.4.5)|' \
#   "$TACHYON_DIR/tachyon/Makefile" "$TACHYON_DIR/luci-app-tachyon/Makefile"
# sed -i 's|^LUCI_LANGUAGES:=en ru$|LUCI_LANGUAGES:=en ru zh_Hans|' "$TACHYON_DIR/luci-app-tachyon/Makefile"
# grep -q 'luci-app-passwall' "$TACHYON_DIR/tachyon/Makefile" \
#   && { echo "::error::tachyon CONFLICTS 补丁未生效"; exit 1; } || true
# grep -m1 'TACHYON_SOURCE_VERSION' "$TACHYON_DIR/tachyon/Makefile"

# ============================================================
# feeds 同名包冲突清理（防止 feeds 版顶替 custom 版）
# ============================================================

# ImmortalWrt 25.12 feeds 已内置 dae / open-app-filter / luci-app-dae，删除 feeds 链接
rm -f package/feeds/packages/dae
rm -f package/feeds/packages/open-app-filter
rm -f package/feeds/luci/luci-app-dae
# feeds 官方 luci-app-homeproxy 被 custom XiaoHaiSly fork 顶替（2026-10-01 换源）：
# 新源 PKG_NAME 与官方同名（luci-app-homeproxy，非旧 pro 版），
# 必须删 feeds 源码目录——否则 feeds install 重建链接后官方版被 defconfig 选中，
# 且两者各自生成 luci-i18n-homeproxy-zh-cn 安装同一个 homeproxy.zh-cn.lmo 引发冲突
rm -rf feeds/luci/applications/luci-app-homeproxy
rm -f package/feeds/luci/luci-app-homeproxy
rm -f package/feeds/luci/luci-i18n-homeproxy-zh-cn
# XiaoHaiSly 版自带 sing-box 1.14.1-extended（shtorm-7/sing-box-extended，含 clash api 扩展），
# 顶替 passwall_packages feeds 的官方 sing-box 1.14.2（passwall/ssr-plus 的 +sing-box 依赖
# 自动解析到 custom 版，满足 homeproxy 的 sing-box (>=1.14.0) 依赖）
rm -rf feeds/passwall_packages/sing-box
rm -f package/feeds/passwall_packages/sing-box

# homeproxy DNS 自定义端口支持：
#   后端 generate_client.uc 的 parse_dnsserver() 已支持端口解析（parseURL 提取 port），
#   但前端 validateDnsServerAddress 不接受 IP:port / [IPv6]:port 格式，导致用户无法填端口。
#   补丁在 catch 块后增加 IP:port 分支校验，并更新 4 个 DNS 选项提示文案。
HP_CLIENT_JS="package/custom/luci-app-homeproxy/luci-app-homeproxy/htdocs/luci-static/resources/view/homeproxy/client.js"
if [ -f "$HP_CLIENT_JS" ] && ! grep -q 'IP:port and \[IPv6\]:port' "$HP_CLIENT_JS"; then
  python3 -c "
import re
with open('$HP_CLIENT_JS', 'r', encoding='utf-8') as f:
    src = f.read()

# 1) 在 validateDnsServerAddress 的 catch 块后插入 IP:port 校验分支
old = '''\t} catch(e) {}

\tif (!stubValidator.apply(allowIPv6 ? 'ipaddr' : 'ip4addr', value))'''
new = '''\t} catch(e) {}

\t/* Support IP:port and [IPv6]:port formats (port is optional) */
\tlet m = value.match(/^(\\\\[[^\\\\]]+\\\\]|[^:]+):(\\\\d+)\$/);
\tif (m) {
\t\tlet host = m[1];
\t\tlet port = +m[2];
\t\tif (port < 1 || port > 65535)
\t\t\treturn _('Expecting: %s').format(_('valid port (1-65535)'));
\t\tlet v6 = host.match(/^\\\\[(.+)\\\\]\$/)?.[1];
\t\tif (v6) {
\t\t\tif (allowIPv6 && stubValidator.apply('ip6addr', v6))
\t\t\t\treturn true;
\t\t} else if (stubValidator.apply('ip4addr', host)) {
\t\t\treturn true;
\t\t}
\t}

\tif (!stubValidator.apply(allowIPv6 ? 'ipaddr' : 'ip4addr', value))'''
assert old in src, 'validateDnsServerAddress anchor not found'
src = src.replace(old, new, 1)

# 2) 更新 4 个 DNS 选项的提示文案，说明支持端口
src = src.replace(
    \"TCP protocol will be used if not specified.'));\",
    \"TCP protocol will be used if not specified. Port can be appended as IP:port or host:port.'));\", 1)
src = src.replace(
    \"The dns server for resolving China domains. Support UDP, TCP, DoH, DoQ, DoT.'));\",
    \"The dns server for resolving China domains. Support UDP, TCP, DoH, DoQ, DoT. Port can be appended as IP:port or host:port.'));\", 1)
src = src.replace(
    \"according to the strategy below. Support UDP, TCP, DoH, DoQ, DoT.'));\",
    \"according to the strategy below. Support UDP, TCP, DoH, DoQ, DoT. Port can be appended as IP:port or host:port.'));\", 1)
src = src.replace(
    \"Additional DNS servers used together with the China DNS server above.'));\",
    \"Additional DNS servers used together with the China DNS server above. Port can be appended as IP:port or host:port.'));\", 1)

with open('$HP_CLIENT_JS', 'w', encoding='utf-8') as f:
    f.write(src)
print('  homeproxy DNS 自定义端口补丁已应用')
"
else
  echo \"  homeproxy DNS 端口补丁已存在或 client.js 不存在，跳过\"
fi
# sbwml/luci-app-mosdns 含更新的 mosdns v5.3.4（feeds 为 v5.3.3）
rm -f package/feeds/packages/mosdns

# 移除 feeds/packages 中与 passwall_packages/helloworld feeds 重叠的核心代理包
# （feeds/packages 声明在自定义 feeds 之前会优先占位，导致旧版被选中）
# 必须同时删除源码目录和 feeds 链接，否则 feeds install -a 不会为其他 feed 补建链接
rm -rf feeds/packages/net/{xray-core,v2ray-core,v2ray-geodata,sing-box}
rm -f package/feeds/packages/xray-core package/feeds/packages/v2ray-core package/feeds/packages/v2ray-geodata package/feeds/packages/sing-box
# helloworld feeds 也提供 mosdns/mihomo，与 custom 版冲突时需删 feeds 链接
rm -f package/feeds/helloworld/mosdns
rm -f package/feeds/helloworld/mihomo
# helloworld feeds 也提供 nikki/momo，custom clone 版优先
rm -f package/feeds/helloworld/nikki 2>/dev/null || true
rm -f package/feeds/helloworld/momo 2>/dev/null || true

# ============================================================
# feeds 源码替换
# ============================================================

# golang feeds 替换为 sbwml 27.x（Go 1.27.1）：
# - xray-core 26.9.9（passwall-packages feeds 每日同步的最新版）要求 go >= 1.27
# - OpenList 4.2.6 要求 go >= 1.25，Go 1.27.1 满足
# - 历史排查结论（2026-09-28 定位真凶）：AdGuardHome 0.107.78 报
#   "no required module provides package X"（x/sys、go-cmp/internal/flags 等）
#   的真正根因是 workflow 下载步骤的假文件清理规则（P3TERX 模板的
#   find dl -size -1024c）误删了 go-mod-cache 中 <1KB 的模块元数据/小源文件
#   ——go.mod 本身无问题，无需 tidy patch；27.x 的"AdGuardHome 不兼容"
#   同为缓存误判（run 18 无缓存实验证实），26.x→27.x 切换安全。
# - 若 CI 再报 go.mod requires go >= 1.2x：升级 golang 分支到对应版本
# - 该包无 BUILD_BOOTSTRAP，CI 上 EXTERNAL_BOOTSTRAP_ROOT 为空时自动下载官方引导；
#   ARM64 本机需指向外部 Go（版本须 >= 该分支 bootstrap 要求）
rm -rf feeds/packages/lang/golang
git clone -q --depth 1 -b 27.x https://github.com/sbwml/packages_lang_golang.git feeds/packages/lang/golang

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
# 必须先 feeds update -i -a 刷新索引（rm 源码后旧索引仍指向已删路径，
# feeds install 会静默失败不建链接），再 feeds install -a 重建链接
./scripts/feeds update -i -a > /dev/null 2>&1 || true
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

# tachyon 中文汉化（已禁用，恢复时取消注释）：
#   submodule 只读，翻译文件由编译仓库 files/po/zh_Hans/ 在此注入；
#   po 需在 make defconfig 前就位，i18n 包才能被扫描生成
# if [ -f files/po/zh_Hans/tachyon.po ]; then
#   mkdir -p package/custom/tachyon/luci-app-tachyon/po/zh_Hans
#   cp files/po/zh_Hans/tachyon.po package/custom/tachyon/luci-app-tachyon/po/zh_Hans/
#   echo "  tachyon 中文翻译已注入 ($(grep -c '^msgid ' files/po/zh_Hans/tachyon.po) 条)"
# else
#   echo "::warning::files/po/zh_Hans/tachyon.po 不存在，luci-i18n-tachyon-zh-cn 不会被构建"
# fi
# touch package/custom/tachyon/luci-app-tachyon/Makefile

# 通用翻译目录适配：OpenWrt 25.12 中文语言代码为 zh_Hans（非旧版 zh-cn）
#   上游仓库多按旧规范建 po/zh-cn，luci.mk 的 LUCI_LANG 只认 zh_Hans，
#   po/zh-cn 不会被扫描生成 i18n 包。递归查找统一重命名为 zh_Hans：
#   - 包本身已有 zh_Hans 目录（如 change-mac）→ 跳过，避免覆盖上游新版翻译
#   - Makefile 硬编码引用 po/zh-cn 的包（自行 po2lmo 生成 .zh-cn.lmo，
#     不走 luci.mk 流程）→ 跳过，改名会破坏路径
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

# 注意：三个代理 feeds（passwall_packages/passwall/helloworld）已改为 src-git，
# feeds update 时直接从上游 clone 到 feeds/ 目录，无 /tmp/openwrt-packages 依赖，
# 本脚本的 feeds 源码目录清理（rm -rf feeds/...）与 feeds install 重建逻辑不受影响。

echo "✅ diy-part2: 编译前定制完成"
