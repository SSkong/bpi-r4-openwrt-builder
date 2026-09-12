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
# 编译优化（可选）
# ============================================================

# 启用 ccache 加速重编（注意：会增大缓存体积，本仓库默认未启用）
# sed -i '/CONFIG_CCACHE/d' .config && echo 'CONFIG_CCACHE=y' >> .config

echo "✅ diy-part2: 编译前定制完成"
