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

# 修复 honk 包的 BTF 依赖死锁：
#   honk 上游 Makefile 的 choice 中 HONK_USE_KERNEL_BTF 依赖
#   KERNEL_DEBUG_INFO_BTF（本源码树未暴露该选项，不可见），
#   Kconfig 被迫选中 HONK_USE_VMLINUX_BTF，进而依赖 vmlinux-btf 包，
#   而本源码树无 vmlinux-btf 包生成机制 → rootfs 组装 (package/install) 必然失败。
#   去除该条件依赖项即可；BTF 仅为 honk 的 eBPF 增强功能，主体功能不受影响。
sed -i 's| +HONK_USE_VMLINUX_BTF:vmlinux-btf||' package/custom/luci-app-honk/honk/Makefile

# ============================================================
# 编译优化（可选）
# ============================================================

# 启用 ccache 加速重编（注意：会增大缓存体积，本仓库默认未启用）
# sed -i '/CONFIG_CCACHE/d' .config && echo 'CONFIG_CCACHE=y' >> .config

echo "✅ diy-part2: 编译前定制完成"
