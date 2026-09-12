#!/bin/bash
#
# diy-part1.sh —— 在 feeds update 之前执行
# 用途：注入第三方软件源（科学上网插件等）
# 环境：当前目录为 OpenWrt 源码根目录
#
set -e

# ============================================================
# 科学上网软件源
# 注意：Passwall 官方源已从 xiaorouji 转移到 Openwrt-Passwall 组织
# ============================================================

# Passwall（默认启用，见 config/bpi-r4.config）
# openwrt-passwall        提供 luci-app-passwall 界面
# openwrt-passwall-packages 提供 xray-core / sing-box 等核心依赖
echo 'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main' >> feeds.conf.default
echo 'src-git passwall https://github.com/Openwrt-Passwall/openwrt-passwall.git;main' >> feeds.conf.default

# ============================================================
# 其他第三方源（按需取消注释）
# ============================================================

# OpenClash（Clash 图形面板，与 Passwall 共存会增大固件体积与编译时间）
# echo 'src-git openclash https://github.com/vernesong/OpenClash.git;master' >> feeds.conf.default

# SSR-Plus / Helloworld —— 原 fw866/helloworld 源已下线，如需使用请自行寻找可用镜像并替换 URL
# echo 'src-git helloworld https://github.com/XXXX/helloworld.git;master' >> feeds.conf.default

echo "✅ diy-part1: 自定义软件源注入完成"
cat feeds.conf.default | tail -n +6
