#!/bin/bash
#
# diy-part1.sh —— 在 feeds update 之前执行
# 用途：注入第三方软件源 + git clone 自定义软件包
# 环境：当前目录为 OpenWrt 源码根目录
#
set -e

# ============================================================
# 一、科学上网软件源（sbwml/openwrt_helloworld）
# 含 passwall / passwall2 / ssr-plus 及全部代理核心（xray/sing-box/hysteria 等）
# ============================================================

# 移除可能残留的旧 passwall feeds 配置（幂等）
sed -i '/passwall_packages/d; /openwrt-passwall-packages/d; /Openwrt-Passwall\/openwrt-passwall\.git/d' feeds.conf.default

# helloworld 全家桶 clone 到 package/ 下，由 SCAN_DEPTH 自动发现
# golang feeds 替换在 diy-part2.sh（需等 feeds update 完成后操作 feeds/packages）
rm -rf package/helloworld
git clone -q --depth 1 https://github.com/sbwml/openwrt_helloworld.git package/helloworld

# ============================================================
# 二、自定义 LuCI 应用与工具包（49 个仓库）
#
# OpenWrt 25.12 包扫描深度为 5 层（include/scan.mk SCAN_DEPTH=5），
# 整仓库 clone 到 package/custom/ 下即可被自动发现，无需移动子目录。
# ============================================================

rm -rf package/custom
mkdir -p package/custom

# --- eBPF 透明代理 ---
# Honk eBPF 透明代理引擎（498777 fork，luci-app-honk + honk 后端双包）
git clone -q --depth 1 https://github.com/498777/luci-app-honk.git package/custom/luci-app-honk
# dae eBPF 透明代理（预编译二进制由 diy-part2.sh 下载）
git clone -q --depth 1 https://github.com/498777/luci-app-dae.git package/custom/luci-app-dae

# --- DNS 分流 ---
# OxiDNS DNS 分流（根目录即包）
git clone -q --depth 1 -b main https://github.com/hahaher123/luci-app-oxidns.git package/custom/luci-app-oxidns
# mosdns DNS 分流（sbwml 版，含 mosdns v5.3.4）
git clone -q --depth 1 https://github.com/sbwml/luci-app-mosdns.git package/custom/luci-app-mosdns

# --- 去广告 ---
# AdGuard Home LuCI（w9315273 版，根目录即包）
# 核心二进制不参与编译，首次使用时由脚本从 GitHub 下载官方预编译版，
# 彻底规避 feeds adguardhome 源码编译的 go.mod 依赖问题
git clone -q --depth 1 https://github.com/w9315273/luci-app-adguardhome.git package/custom/luci-app-adguardhome

# --- 网络监控 ---
# NetMonitor 网络质量监控（延迟/丢包）
git clone -q --depth 1 -b main https://github.com/LianXia233/luci-app-netmonitor.git package/custom/luci-app-netmonitor
# CPU 状态监控（频率/温度/占用）
git clone -q --depth 1 https://github.com/gSpotx2f/luci-app-cpu-status.git package/custom/luci-app-cpu-status
# 外网连通性检测（断网告警/自动恢复）
git clone -q --depth 1 https://github.com/gSpotx2f/luci-app-internet-detector.git package/custom/luci-app-internet-detector
# 系统日志增强查看
git clone -q --depth 1 https://github.com/gSpotx2f/luci-app-log.git package/custom/luci-app-log
# 温度监控
git clone -q --depth 1 https://github.com/gSpotx2f/luci-app-temp-status.git package/custom/luci-app-temp-status
# 看门狗（进程/网络异常自动重启）
git clone -q --depth 1 https://github.com/sirpdboy/luci-app-watchdog.git package/custom/luci-app-watchdog

# --- QoS / 流量控制 ---
# TrafficCtl 流量控制（限速/整形/断网）
git clone -q --depth 1 -b main https://github.com/YusDyr/luci-app-trafficctl.git package/custom/luci-app-trafficctl
# QosMate nftables 智能限速与 QoS 管理
git clone -q --depth 1 https://github.com/hudra0/qosmate.git package/custom/qosmate
git clone -q --depth 1 https://github.com/hudra0/luci-app-qosmate.git package/custom/luci-app-qosmate
# 带宽监控
git clone -q --depth 1 https://github.com/timsaya/luci-app-bandix.git package/custom/luci-app-bandix
git clone -q --depth 1 https://github.com/timsaya/openwrt-bandix.git package/custom/openwrt-bandix
# 应用过滤（OpenAppFilter 含 kmod-oaf + appfilter + luci-app-oaf 三包）
git clone -q --depth 1 https://github.com/destan19/OpenAppFilter.git package/custom/OpenAppFilter

# --- 组网 / 代理 / CDN ---
# EasyTier 去中心化 Mesh 组网
git clone -q --depth 1 https://github.com/EasyTier/luci-app-easytier.git package/custom/luci-app-easytier
# mihomo（Clash Meta）内核与 LuCI 管理
git clone -q --depth 1 https://github.com/fcshark-org/openwrt-fchomo.git package/custom/openwrt-fchomo
# Cloudflare CDN 节点优选测速
git clone -q --depth 1 https://github.com/stevenjoezhang/luci-app-cloudflarespeedtest.git package/custom/luci-app-cloudflarespeedtest
# Cloudflare 优选 IP 自动更新
git clone -q --depth 1 https://github.com/hello-yunshu/luci-app-cloudflare-ip.git package/custom/luci-app-cloudflare-ip

# --- 网络工具 ---
# OpenList 多网盘挂载（阿里/百度/夸克等）
git clone -q --depth 1 https://github.com/sbwml/luci-app-openlist2.git package/custom/luci-app-openlist2
# PPPoE 拨号保活，断线自动重连
git clone -q --depth 1 https://github.com/muink/luci-app-alwaysonline.git package/custom/luci-app-alwaysonline
git clone -q --depth 1 https://github.com/muink/openwrt-alwaysonline.git package/custom/openwrt-alwaysonline
# MAC 地址查看与修改
git clone -q --depth 1 https://github.com/muink/luci-app-change-mac.git package/custom/luci-app-change-mac
git clone -q --depth 1 https://github.com/muink/openwrt-rgmac.git package/custom/openwrt-rgmac
# NAT 映射 / STUN 打洞
git clone -q --depth 1 https://github.com/muink/luci-app-natmapt.git package/custom/luci-app-natmapt
git clone -q --depth 1 https://github.com/muink/openwrt-natmapt.git package/custom/openwrt-natmapt
git clone -q --depth 1 https://github.com/muink/openwrt-stuntman.git package/custom/openwrt-stuntman
# WOL 网络唤醒
git clone -q --depth 1 https://github.com/isalikai/luci-app-owq-wol.git package/custom/luci-app-owq-wol
# AP/Modem 快捷访问（QiuSimons/OpenWrt-Add 子目录，仓库含大量同名包故只取此目录）
git clone -q --depth 1 https://github.com/QiuSimons/OpenWrt-Add.git /tmp/openwrt-add && \
  cp -a /tmp/openwrt-add/luci-app-ap-modem package/custom/luci-app-ap-modem && \
  rm -rf /tmp/openwrt-add

# --- 系统工具 ---
# HW Dashboard 硬件信息仪表盘
git clone -q --depth 1 -b main https://github.com/AliLostInTheDark/luci-app-hw-dashboard.git package/custom/luci-app-hw-dashboard
# 磁盘管理（挂载/格式化）
git clone -q --depth 1 https://github.com/4IceG/luci-app-mini-diskmanager.git package/custom/luci-app-mini-diskmanager
# 风扇转速控制（锁定 commit 7655e6d，上游 HEAD 有破坏性变更）
git clone -q --depth 1 https://github.com/bigmalloy/luci-app-fancontrol.git package/custom/luci-app-fancontrol
cd package/custom/luci-app-fancontrol && git fetch -q --depth 1 origin 7655e6d624e7d277cf5cb617584a638b08b672d7 && git checkout -q 7655e6d624e7d277cf5cb617584a638b08b672d7 && cd - >/dev/null
# 时间控制
git clone -q --depth 1 https://github.com/sirpdboy/luci-app-timecontrol.git package/custom/luci-app-timecontrol
# 分区扩展
git clone -q --depth 1 https://github.com/sirpdboy/luci-app-partexp.git package/custom/luci-app-partexp
# 任务计划
git clone -q --depth 1 https://github.com/sirpdboy/luci-app-taskplan.git package/custom/luci-app-taskplan
# 文件管理
git clone -q --depth 1 https://github.com/whzhni1/luci-app-harbor-file-pro.git package/custom/luci-app-harbor-file-pro
# AirPlay 音频转发
git clone -q --depth 1 https://github.com/sbwml/luci-app-airconnect.git package/custom/luci-app-airconnect

# --- Node.js 运行时 ---
# sbwml 预编译版，同名顶替 packages feeds 官方源码编译版，节省 30-60 分钟
# 注意分支 packages-25.12 与固件源码版本对应，勿随意改动
git clone -q --depth 1 -b packages-25.12 https://github.com/sbwml/feeds_packages_lang_node.git package/custom/node

# --- LuCI 主题（7 款） ---
git clone -q --depth 1 https://github.com/Zakkaus/luci-theme-graphite.git package/custom/luci-theme-graphite
git clone -q --depth 1 https://github.com/Zakkaus/luci-app-graphite.git package/custom/luci-app-graphite
git clone -q --depth 1 https://github.com/eamonxg/luci-theme-aurora.git package/custom/luci-theme-aurora
git clone -q --depth 1 https://github.com/eamonxg/luci-app-aurora-config.git package/custom/luci-app-aurora-config
git clone -q --depth 1 https://github.com/zzsj0928/luci-theme-liquid.git package/custom/luci-theme-liquid
git clone -q --depth 1 https://github.com/eamonxg/luci-theme-shadcn.git package/custom/luci-theme-shadcn
git clone -q --depth 1 https://github.com/VizzleTF/luci-theme-footstrap.git package/custom/luci-theme-footstrap
git clone -q --depth 1 https://github.com/LazuliKao/luci-theme-fluent.git package/custom/luci-theme-fluent
git clone -q --depth 1 https://github.com/OnyxAxisOwO/Obsidian-Theme.git package/custom/Obsidian-Theme

# 校验 clone 结果：必须能找到至少一个含 BuildPackage 的包 Makefile
echo "===== 自定义包 Makefile 扫描结果 ====="
find package/custom -maxdepth 3 -name Makefile -not -path '*/.git/*' \
  -exec grep -l 'call BuildPackage\|Build/DefaultTargets\|KernelPackage' {} + \
  || { echo "❌ 自定义包 clone 后未发现任何有效 Makefile"; exit 1; }

echo "✅ diy-part1: 自定义软件源注入 + 自定义包 clone 完成"
