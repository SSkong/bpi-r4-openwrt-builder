#!/bin/bash
#
# verify-custom-packages.sh —— 自定义包编译前自动校验
#
# 校验清单 (scripts/custom-packages.list) 中的每个包：
#   1. 已被包扫描发现（diy-part1.sh 的 git clone 成功且 Makefile 有效）
#   2. 生效来源为 package/custom/（若同名包存在于 feeds，防止被顶替降级）
#   3. 已选入最终固件配置 (.config)
# 另附防呆提示：package/custom/ 中发现但未列入清单的包会给出警告
#
# 用法（在 OpenWrt 源码根目录下执行，需先 make defconfig）:
#   bash verify-custom-packages.sh <清单文件路径>
#
set -u

LIST_FILE="${1:?用法: bash verify-custom-packages.sh <custom-packages.list>}"
PKGINFO="tmp/.packageinfo"
DOTCONFIG=".config"

[ -f "$LIST_FILE" ] || { echo "::error::清单文件不存在: $LIST_FILE"; exit 1; }
[ -f "$PKGINFO" ]   || { echo "::error::$PKGINFO 不存在，请先执行 make defconfig"; exit 1; }
[ -f "$DOTCONFIG" ] || { echo "::error::$DOTCONFIG 不存在"; exit 1; }

# 从 packageinfo 提取某包的 Source-Makefile（条目结构：Source-Makefile 先于 Package）
get_src() {
    awk -v pkg="$1" '
        /^Source-Makefile:/ { src = $2 }
        /^Package: /        { if ($2 == pkg) { print src; exit } }
    ' "$PKGINFO"
}

fail=0
while read -r pkg; do
    # 跳过空行与注释行
    case "$pkg" in ''|'#'*) continue ;; esac

    src="$(get_src "$pkg")"
    if [ -z "$src" ]; then
        echo "::error::[$pkg] 未被扫描发现 —— 检查 diy-part1.sh 中该仓库的 git clone 是否成功"
        fail=1
        continue
    fi

    case "$src" in
        package/custom/*) ;;
        *)
            echo "::error::[$pkg] 生效来源为 $src（非 package/custom/），疑似被 feeds 同名包顶替"
            fail=1
            continue
            ;;
    esac

    if grep -q "^CONFIG_PACKAGE_${pkg}=y" "$DOTCONFIG"; then
        echo "✓ $pkg (来源: $src)"
    else
        echo "::error::[$pkg] 来源正确但未选入固件 —— 请在 config/bpi-r4.config 添加 CONFIG_PACKAGE_${pkg}=y"
        fail=1
    fi
done < "$LIST_FILE"

# 防呆提示：package/custom/ 中发现但未列入清单的包
if command -v awk >/dev/null 2>&1; then
    while read -r d; do
        [ -n "$d" ] || continue
        grep -qx "$d" "$LIST_FILE" && continue
        echo "::warning::[$d] package/custom/ 中发现但未列入清单；若有意不装可忽略，否则请补入清单与 config"
    done < <(awk '/^Source-Makefile:/ { src = $2 }
                  /^Package: / { if (src ~ /^package\/custom\//) print $2 }' "$PKGINFO" | sort)
fi

if [ "$fail" = 0 ]; then
    echo "✅ 全部自定义包校验通过（扫描 + 来源 + 选中）"
else
    echo "::error::自定义包校验存在失败项"
    exit 1
fi
