#!/bin/bash
#
# diy-part1.sh —— 在 feeds update 之前执行
# 用途：注入第三方软件源 + git clone 自定义软件包
# 环境：当前目录为 OpenWrt 源码根目录
#
set -e

# ============================================================
# 一、科学上网软件源（feeds 方式注入）
# 注意：Passwall 官方源已从 xiaorouji 转移到 Openwrt-Passwall 组织
# ============================================================

# Passwall（默认启用，见 config/bpi-r4.config）
# openwrt-passwall           提供 luci-app-passwall 界面
# openwrt-passwall-packages  提供 xray-core / sing-box 等核心依赖
# grep 防重保证脚本幂等（重复执行不会重复追加源）
grep -qF 'openwrt-passwall-packages.git' feeds.conf.default || \
  echo 'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main' >> feeds.conf.default
grep -qF 'Openwrt-Passwall/openwrt-passwall.git' feeds.conf.default || \
  echo 'src-git passwall https://github.com/Openwrt-Passwall/openwrt-passwall.git;main' >> feeds.conf.default

# ============================================================
# 二、自定义 LuCI 应用（编译前 git clone 到 package/custom/）
#
# 放置说明：
#   - OpenWrt 25.12 包扫描深度为 5 层（include/scan.mk SCAN_DEPTH=5），
#     因此整仓库 clone 到 package/custom/ 下即可被自动发现，
#     无需移动子目录（保留仓库完整性，上游改结构也不受影响）
#   - "根目录即包" 的仓库 clone 后 Makefile 直接生效
#   - "包在子目录" 的仓库（honk/trafficctl/adguardhome）由深度扫描自动发现
# ============================================================

rm -rf package/custom
mkdir -p package/custom

# Honk 微博客（luci-app-honk + honk 后端，双包仓库，后端为预编译 aarch64 二进制）
git clone -q --depth 1 -b master https://github.com/QiuSimons/luci-app-honk.git package/custom/luci-app-honk

# OxiDNS DNS 分流（根目录即包）
git clone -q --depth 1 -b main https://github.com/hahaher123/luci-app-oxidns.git package/custom/luci-app-oxidns

# NetMonitor 网络质量监控（根目录即包，包名由目录名推导）
git clone -q --depth 1 -b main https://github.com/LianXia233/luci-app-netmonitor.git package/custom/luci-app-netmonitor

# TrafficCtl 流量控制（包在子目录）
git clone -q --depth 1 -b main https://github.com/YusDyr/luci-app-trafficctl.git package/custom/luci-app-trafficctl

# AdGuard Home 去广告（包在子目录，核心包 adguardhome 由 packages feeds 依赖自动带入）
git clone -q --depth 1 -b main https://github.com/terrytyc/luci-app-adguardhome.git package/custom/luci-app-adguardhome

# HW Dashboard 硬件信息仪表盘（根目录即包）
git clone -q --depth 1 -b main https://github.com/AliLostInTheDark/luci-app-hw-dashboard.git package/custom/luci-app-hw-dashboard

# Node.js 运行时（sbwml 预编译版，同名顶替 packages feeds 官方源码编译版）
# 构建时直接下载预编译 apk 解压，相比官方源码编译节省 30-60 分钟
# 注意分支 packages-25.12 与固件源码版本对应，勿随意改动
git clone -q --depth 1 -b packages-25.12 https://github.com/sbwml/feeds_packages_lang_node.git package/custom/node

# 校验 clone 结果：必须能找到至少一个含 BuildPackage 的包 Makefile
echo "===== 自定义包 Makefile 扫描结果 ====="
find package/custom -maxdepth 3 -name Makefile -not -path '*/.git/*' \
  -exec grep -l 'call BuildPackage\|Build/DefaultTargets\|KernelPackage' {} + \
  || { echo "❌ 自定义包 clone 后未发现任何有效 Makefile"; exit 1; }

# ============================================================
# 三、其他第三方源（按需取消注释）
# ============================================================

# OpenClash（Clash 图形面板，与 Passwall 共存会增大固件体积与编译时间）
# echo 'src-git openclash https://github.com/vernesong/OpenClash.git;master' >> feeds.conf.default

# SSR-Plus / Helloworld —— 原 fw866/helloworld 源已下线，如需使用请自行寻找可用镜像并替换 URL
# echo 'src-git helloworld https://github.com/XXXX/helloworld.git;master' >> feeds.conf.default

echo "✅ diy-part1: 自定义软件源注入 + 自定义包 clone 完成"
