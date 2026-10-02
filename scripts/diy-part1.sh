#!/bin/bash
#
# diy-part1.sh —— 在 feeds update 之前执行
# 用途：注入第三方软件源 + 编译时直接 clone 自定义软件包
# 环境：当前目录为 OpenWrt 源码根目录
#
# 模式参考 VIKINGYFY/OpenWRT-CI：所有第三方包在编译时从上游直接 clone
# 最新版本，不依赖 monorepo 每日同步（monorepo 仅保留作源清单镜像）。
#   - 三个代理 feeds 用 src-git 声明，feeds update 时从上游 clone 最新代码
#   - 其余自定义包本脚本并行 clone 到 package/custom/（并发 8 限流）
#   - 无上游的静态自维护包随编译仓库 scripts/static-packages/ 分发
#
set -e

# 编译仓库根目录（CI 为 GITHUB_WORKSPACE；本地测试回退到脚本上级目录）
WS="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"

# ============================================================
# 一、代理 feeds 注入（src-git：feeds update 时从上游 clone 最新版）
#
# passwall_packages: 代理核心（xray/sing-box/hysteria/shadowsocks-rust 等）
# passwall:          luci-app-passwall / luci-app-passwall2
# helloworld:        luci-app-ssr-plus + 额外核心（分支 dev）
# 三源同名包由 feeds install 按声明顺序去重，先声明者优先
# ============================================================

# 幂等注入：先清理旧声明（含历史上用过的 src-link 形式），再追加
sed -i '/passwall_packages/d; /openwrt-passwall-packages/d; /src-git passwall /d; /src-link passwall /d; /Openwrt-Passwall\/openwrt-passwall\.git/d; /src-git helloworld/d; /src-link helloworld/d; /fw876\/helloworld/d; /sbwml\/openwrt_helloworld/d' feeds.conf.default
echo 'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main' >> feeds.conf.default
echo 'src-git passwall https://github.com/Openwrt-Passwall/openwrt-passwall.git;main' >> feeds.conf.default
echo 'src-git helloworld https://github.com/fw876/helloworld.git;dev' >> feeds.conf.default

# ============================================================
# 二、自定义 LuCI 应用与工具包（编译时逐仓库 clone 最新版）
#
# 克隆清单格式：目录名|仓库URL|分支（分支留空 = 上游默认分支）
# 添加新包标准三步：
#   ① 本清单加一行
#   ② config/bpi-r4.config 增加 CONFIG_PACKAGE_<包名>=y
#   ③ scripts/custom-packages.list 增加一行包名
#
# OpenWrt 25.12 包扫描深度为 5 层（include/scan.mk SCAN_DEPTH=5），
# 整仓库 clone 到 package/custom/ 下即可被自动发现，无需移动子目录。
# ============================================================

rm -rf package/custom
mkdir -p package/custom

CLONE_LIST="
# --- eBPF 透明代理 ---
luci-app-honk|https://github.com/498777/luci-app-honk.git|main
luci-app-dae|https://github.com/498777/luci-app-dae.git|main
# --- DNS 分流 ---
luci-app-oxidns|https://github.com/hahaher123/luci-app-oxidns.git|main
luci-app-mosdns|https://github.com/sbwml/luci-app-mosdns.git|v5
# --- 去广告 ---
luci-app-adguardhome|https://github.com/terrytyc/luci-app-adguardhome.git|main
# --- 网络监控 ---
luci-app-netmonitor|https://github.com/LianXia233/luci-app-netmonitor.git|main
luci-app-cpu-status|https://github.com/gSpotx2f/luci-app-cpu-status.git|master
luci-app-internet-detector|https://github.com/gSpotx2f/luci-app-internet-detector.git|master
luci-app-log|https://github.com/gSpotx2f/luci-app-log.git|master
luci-app-temp-status|https://github.com/gSpotx2f/luci-app-temp-status.git|master
luci-app-watchdog|https://github.com/sirpdboy/luci-app-watchdog.git|main
# --- QoS / 流量控制 ---
luci-app-trafficctl|https://github.com/YusDyr/luci-app-trafficctl.git|main
qosmate|https://github.com/hudra0/qosmate.git|main
luci-app-qosmate|https://github.com/hudra0/luci-app-qosmate.git|main
# --- 带宽监控 / 应用过滤 ---
luci-app-bandix|https://github.com/timsaya/luci-app-bandix.git|main
openwrt-bandix|https://github.com/timsaya/openwrt-bandix.git|main
OpenAppFilter|https://github.com/destan19/OpenAppFilter.git|master
# --- 组网 / 代理 / CDN ---
luci-app-zerotier|https://github.com/rabbitrogi/luci-app-zerotier.git|main
luci-app-easytier|https://github.com/EasyTier/luci-app-easytier.git|main
OpenWrt-nikki|https://github.com/nikkinikki-org/OpenWrt-nikki.git|main
OpenWrt-momo|https://github.com/nikkinikki-org/OpenWrt-momo.git|main
luci-app-kixdns|https://github.com/JohnsonRan/luci-app-kixdns.git|main
luci-app-substore|https://github.com/Arthur97172/luci-app-substore.git|main
luci-app-cloudflare-ip|https://github.com/hello-yunshu/luci-app-cloudflare-ip.git|main
openwrt-fchomo|https://github.com/fcshark-org/openwrt-fchomo.git|
luci-app-cloudflarespeedtest|https://github.com/stevenjoezhang/luci-app-cloudflarespeedtest.git|
luci-app-homeproxy|https://github.com/XiaoHaiSly/luci-app-homeproxy.git|main
# tachyon 已移除（恢复时取消注释）——上游 CONFLICTS 与 passwall 冲突
# tachyon|https://github.com/Dushnilin/tachyon.git|main
# --- 网络工具 ---
luci-app-openlist2|https://github.com/sbwml/luci-app-openlist2.git|main
node|https://github.com/sbwml/feeds_packages_lang_node.git|packages-25.12
luci-app-owq-wol|https://github.com/isalikai/luci-app-owq-wol.git|main
luci-app-change-mac|https://github.com/muink/luci-app-change-mac.git|
openwrt-alwaysonline|https://github.com/muink/openwrt-alwaysonline.git|
openwrt-rgmac|https://github.com/muink/openwrt-rgmac.git|
luci-app-alwaysonline|https://github.com/muink/luci-app-alwaysonline.git|
luci-app-natmapt|https://github.com/muink/luci-app-natmapt.git|
openwrt-stuntman|https://github.com/muink/openwrt-stuntman.git|
openwrt-natmapt|https://github.com/muink/openwrt-natmapt.git|
# --- 系统工具 ---
luci-app-hw-dashboard|https://github.com/AliLostInTheDark/luci-app-hw-dashboard.git|main
luci-app-timecontrol|https://github.com/gaobin89/luci-app-timecontrol.git|js
luci-app-partexp|https://github.com/sirpdboy/luci-app-partexp.git|main
luci-app-taskplan|https://github.com/sirpdboy/luci-app-taskplan.git|main
luci-app-harbor-file-pro|https://github.com/whzhni1/luci-app-harbor-file-pro.git|main
luci-app-airconnect|https://github.com/sbwml/luci-app-airconnect.git|main
luci-app-mini-diskmanager|https://github.com/4IceG/luci-app-mini-diskmanager.git|
# --- LuCI 主题 ---
luci-theme-graphite|https://github.com/Zakkaus/luci-theme-graphite.git|
luci-app-graphite|https://github.com/Zakkaus/luci-app-graphite.git|
luci-theme-aurora|https://github.com/eamonxg/luci-theme-aurora.git|
luci-app-aurora-config|https://github.com/eamonxg/luci-app-aurora-config.git|
luci-theme-liquid|https://github.com/zzsj0928/luci-theme-liquid.git|
luci-theme-shadcn|https://github.com/eamonxg/luci-theme-shadcn.git|
luci-theme-footstrap|https://github.com/VizzleTF/luci-theme-footstrap.git|
luci-theme-fluent|https://github.com/LazuliKao/luci-theme-fluent.git|
Obsidian-Theme|https://github.com/OnyxAxisOwO/Obsidian-Theme.git|
"

# 并行克隆（并发 8：控制与 GitHub 的连接数，避免限流；失败不中断，
# 由下方校验步骤统一报告缺失项）
MAX_JOBS=8
while IFS='|' read -r dir url branch; do
  case "$dir" in ''|'#'*) continue ;; esac
  (
    if [ -n "$branch" ]; then
      git clone -q --depth 1 --single-branch --branch "$branch" "$url" "package/custom/$dir" \
        && echo "  ✓ $dir ($branch)" \
        || echo "  ✗ $dir 克隆失败"
    else
      git clone -q --depth 1 "$url" "package/custom/$dir" \
        && echo "  ✓ $dir (默认分支)" \
        || echo "  ✗ $dir 克隆失败"
    fi
  ) &
  # 并发限流：达到上限时等待任一任务结束
  while [ "$(jobs -rp | wc -l)" -ge "$MAX_JOBS" ]; do
    sleep 0.3
  done
done <<< "$CLONE_LIST"
wait || true

# fancontrol 锁定 commit 7655e6d（上游 HEAD 有破坏性变更，不跟最新）
FANCTRL_SHA="7655e6d624e7d277cf5cb617584a638b08b672d7"
git clone -q --depth 1 https://github.com/bigmalloy/luci-app-fancontrol.git /tmp/fancontrol
(
  cd /tmp/fancontrol
  git fetch -q --depth 1 origin "$FANCTRL_SHA"
  git checkout -q "$FANCTRL_SHA"
)
cp -a /tmp/fancontrol package/custom/luci-app-fancontrol
rm -rf package/custom/luci-app-fancontrol/.git /tmp/fancontrol
echo "  ✓ luci-app-fancontrol (锁定 $FANCTRL_SHA)"

# ============================================================
# 三、静态自维护包（无 GitHub 上游，随编译仓库分发）
#
# luci-app-ap-modem:      AP 模式调制解调器管理（含 zh_Hans 翻译）
# luci-app-model-gateway:  wanvfx 模型网关的预编译 ipk 集成（Makefile + .lmo）
# ============================================================

cp -a "$WS/scripts/static-packages/." package/custom/
echo "  ✓ 静态包: $(ls "$WS/scripts/static-packages/" | tr '\n' ' ')"

# ============================================================
# 四、克隆结果校验（逐包必须含有效 Makefile，缺失即失败）
# ============================================================

check_pkg() {
  find "package/custom/$1" -maxdepth 3 -name Makefile -print -quit 2>/dev/null | grep -q .
}

FAILED=""
while IFS='|' read -r dir url branch; do
  case "$dir" in ''|'#'*) continue ;; esac
  check_pkg "$dir" || FAILED="$FAILED $dir"
done <<< "$CLONE_LIST"
for extra in luci-app-fancontrol luci-app-ap-modem luci-app-model-gateway; do
  check_pkg "$extra" || FAILED="$FAILED $extra"
done

if [ -n "$FAILED" ]; then
  echo "::error::以下包 clone/复制失败，未发现有效 Makefile:$FAILED"
  exit 1
fi

echo "===== 自定义包 Makefile 扫描结果 ====="
find package/custom -maxdepth 3 -name Makefile -not -path '*/.git/*' | wc -l \
  | xargs -I{} echo "共发现 {} 个 Makefile"

echo "✅ diy-part1: 自定义软件源注入 + 编译时最新版 clone 完成"
