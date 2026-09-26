---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '0374c16e-6af0-4ab7-a896-fe4ac79128e0'
  PropagateID: '0374c16e-6af0-4ab7-a896-fe4ac79128e0'
  ReservedCode1: '04f49a04-a54a-4b8b-abea-6ab8ed099141'
  ReservedCode2: '04f49a04-a54a-4b8b-abea-6ab8ed099141'
---

# BPI-R4 OpenWrt 自动编译

使用 GitHub Actions **定时自动编译** Banana Pi BPI-R4（标准版，MT7988A）的 ImmortalWrt 固件，内置 Passwall 科学上网插件、mihomo、dae/honk eBPF 透明代理与 49 个自定义仓库（66 个包：eBPF 代理 / DNS 分流 / QoS 限速 / 网络监控 / 应用过滤 / NAT 打洞 / Mesh 组网 / CDN 优选 / 7 款 LuCI 主题等），内核已启用 BTF 支持 eBPF 程序运行。

## 固件信息

| 项目 | 说明 |
|---|---|
| 硬件平台 | Banana Pi BPI-R4 标准版 (MT7988A / 4GB RAM / 32GB eMMC) |
| 固件源码 | [chasey-dev/immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase) (ImmortalWrt 25.12 + MTK 官方 Feeds，内核 6.12) |
| 科学上网 | **Passwall** (Xray / sing-box / Hysteria，SSR / Shadowsocks 等全协议)、**dae/honk** (eBPF 透明代理) |
| 自定义插件 | 49 个仓库 66 个包：eBPF 代理、DNS 分流、去广告、QoS 限速、网络监控、带宽监控、应用过滤、Mesh 组网、CDN 优选、NAT 打洞、系统工具、网络唤醒、7 款 LuCI 主题等，完整清单见下方表格 |
| 内核特性 | 已启用 BTF（BPF Type Format），支持 dae/honk 等 eBPF 程序运行 |
| 管理界面 | LuCI 中文 |
| 默认地址 | `192.168.10.1`，账号 `root`，无密码 |
| 更新频率 | 每周一北京时间 11:00 自动编译 |

## 仓库结构

```
├── .github/workflows/
│   └── build-openwrt.yml    # 编译工作流（定时 + 手动触发）
├── scripts/
│   ├── diy-part1.sh         # [feeds 阶段] 注入第三方源 + git clone 自定义包到 package/custom/
│   ├── diy-part2.sh         # [编译前] 默认设置定制 + 兼容性修复 + feeds 源码替换
│   ├── custom-packages.list # 自定义包校验清单（verify-custom-packages.sh 读取）
│   └── verify-custom-packages.sh # 编译前三态校验（扫描 + 来源 + 选中）
├── config/
│   └── bpi-r4.config        # 固件配置种子文件（加/减插件改这里）
├── files/                   # 预置配置目录（放入 etc/xxx 会合并进固件）
│   └── po/zh_Hans/          # 预置中文翻译文件
└── README.md
```

## 自定义插件清单

| 分类 | 包 | 功能 | 来源仓库 |
|---|---|---|---|
| eBPF 代理 | luci-app-honk / honk | Honk eBPF 透明代理引擎 | [498777/luci-app-honk](https://github.com/498777/luci-app-honk) |
| eBPF 代理 | luci-app-dae / dae | dae eBPF 透明代理（预编译二进制） | [498777/luci-app-dae](https://github.com/498777/luci-app-dae) |
| DNS 分流 | luci-app-oxidns | OxiDNS DNS 分流 | [hahaher123/luci-app-oxidns](https://github.com/hahaher123/luci-app-oxidns) |
| DNS 分流 | mosdns / luci-app-mosdns | mosdns DNS 分流（v5.3.4） | [sbwml/luci-app-mosdns](https://github.com/sbwml/luci-app-mosdns) |
| 去广告 | luci-app-adguardhome | AdGuard Home 去广告（nftables 重定向，核心二进制运行时下载） | [w9315273/luci-app-adguardhome](https://github.com/w9315273/luci-app-adguardhome) |
| 网络监控 | luci-app-netmonitor | 网络质量监控（延迟/丢包） | [LianXia233/luci-app-netmonitor](https://github.com/LianXia233/luci-app-netmonitor) |
| 网络监控 | luci-app-cpu-status | CPU 状态监控（频率/温度/占用） | [gSpotx2f/luci-app-cpu-status](https://github.com/gSpotx2f/luci-app-cpu-status) |
| 网络监控 | internet-detector / luci-app-internet-detector | 外网连通性检测 | [gSpotx2f/luci-app-internet-detector](https://github.com/gSpotx2f/luci-app-internet-detector) |
| 网络监控 | luci-app-log-viewer | 系统日志增强查看 | [gSpotx2f/luci-app-log](https://github.com/gSpotx2f/luci-app-log) |
| 网络监控 | luci-app-temp-status | 温度监控 | [gSpotx2f/luci-app-temp-status](https://github.com/gSpotx2f/luci-app-temp-status) |
| 网络监控 | watchdog / luci-app-watchdog | 看门狗（进程/网络异常自动重启） | [sirpdboy/luci-app-watchdog](https://github.com/sirpdboy/luci-app-watchdog) |
| QoS | luci-app-trafficctl | 流量控制（限速/整形/断网） | [YusDyr/luci-app-trafficctl](https://github.com/YusDyr/luci-app-trafficctl) |
| QoS | qosmate / luci-app-qosmate | nftables 智能限速与 QoS 管理 | [hudra0/qosmate](https://github.com/hudra0/qosmate) · [hudra0/luci-app-qosmate](https://github.com/hudra0/luci-app-qosmate) |
| 带宽/过滤 | bandix / luci-app-bandix | 带宽监控 | [timsaya/luci-app-bandix](https://github.com/timsaya/luci-app-bandix) · [timsaya/openwrt-bandix](https://github.com/timsaya/openwrt-bandix) |
| 带宽/过滤 | kmod-oaf / appfilter / luci-app-oaf | 应用过滤（OpenAppFilter） | [destan19/OpenAppFilter](https://github.com/destan19/OpenAppFilter) |
| 组网 | easytier / luci-app-easytier | 去中心化 Mesh 组网 | [EasyTier/luci-app-easytier](https://github.com/EasyTier/luci-app-easytier) |
| 代理 | mihomo / luci-app-fchomo | mihomo（Clash Meta）内核与 LuCI | [fcshark-org/openwrt-fchomo](https://github.com/fcshark-org/openwrt-fchomo) |
| CDN 优选 | luci-app-cloudflarespeedtest | Cloudflare CDN 节点优选测速 | [stevenjoezhang/luci-app-cloudflarespeedtest](https://github.com/stevenjoezhang/luci-app-cloudflarespeedtest) |
| CDN 优选 | luci-app-cloudflare-ip | Cloudflare 优选 IP 自动更新 | [hello-yunshu/luci-app-cloudflare-ip](https://github.com/hello-yunshu/luci-app-cloudflare-ip) |
| 网络工具 | openlist2 / luci-app-openlist2 | OpenList 多网盘挂载 | [sbwml/luci-app-openlist2](https://github.com/sbwml/luci-app-openlist2) |
| 网络工具 | alwaysonline / luci-app-alwaysonline | PPPoE 拨号保活 | [muink/luci-app-alwaysonline](https://github.com/muink/luci-app-alwaysonline) · [muink/openwrt-alwaysonline](https://github.com/muink/openwrt-alwaysonline) |
| 网络工具 | rgmac / luci-app-change-mac | MAC 地址查看与修改 | [muink/luci-app-change-mac](https://github.com/muink/luci-app-change-mac) · [muink/openwrt-rgmac](https://github.com/muink/openwrt-rgmac) |
| 网络工具 | natmapt / stuntman-client / luci-app-natmapt | NAT 映射 / STUN 打洞 | [muink/luci-app-natmapt](https://github.com/muink/luci-app-natmapt) · [muink/openwrt-natmapt](https://github.com/muink/openwrt-natmapt) · [muink/openwrt-stuntman](https://github.com/muink/openwrt-stuntman) |
| 网络工具 | luci-app-owq-wol | WOL 网络唤醒 | [isalikai/luci-app-owq-wol](https://github.com/isalikai/luci-app-owq-wol) |
| 网络工具 | luci-app-ap-modem | AP/Modem 快捷访问 | [QiuSimons/OpenWrt-Add](https://github.com/QiuSimons/OpenWrt-Add) |
| 系统工具 | luci-app-hw-dashboard | 硬件信息仪表盘 | [AliLostInTheDark/luci-app-hw-dashboard](https://github.com/AliLostInTheDark/luci-app-hw-dashboard) |
| 系统工具 | luci-app-mini-diskmanager | 磁盘管理（挂载/格式化） | [4IceG/luci-app-mini-diskmanager](https://github.com/4IceG/luci-app-mini-diskmanager) |
| 系统工具 | luci-app-fancontrol | 风扇转速控制 | [bigmalloy/luci-app-fancontrol](https://github.com/bigmalloy/luci-app-fancontrol) |
| 系统工具 | luci-app-timecontrol | 时间控制 | [sirpdboy/luci-app-timecontrol](https://github.com/sirpdboy/luci-app-timecontrol) |
| 系统工具 | luci-app-partexp | 分区扩展 | [sirpdboy/luci-app-partexp](https://github.com/sirpdboy/luci-app-partexp) |
| 系统工具 | luci-app-taskplan | 任务计划 | [sirpdboy/luci-app-taskplan](https://github.com/sirpdboy/luci-app-taskplan) |
| 系统工具 | luci-app-harbor-file-pro | 文件管理 | [whzhni1/luci-app-harbor-file-pro](https://github.com/whzhni1/luci-app-harbor-file-pro) |
| 系统工具 | airconnect / luci-app-airconnect | AirPlay 音频转发 | [sbwml/luci-app-airconnect](https://github.com/sbwml/luci-app-airconnect) |
| 运行时 | node / node-npm | Node.js（sbwml 预编译版，替换官方源码编译版） | [sbwml/feeds_packages_lang_node](https://github.com/sbwml/feeds_packages_lang_node) |
| 主题 | luci-theme-graphite + luci-app-graphite | Graphite 主题与配置器 | [Zakkaus/luci-theme-graphite](https://github.com/Zakkaus/luci-theme-graphite) · [Zakkaus/luci-app-graphite](https://github.com/Zakkaus/luci-app-graphite) |
| 主题 | luci-theme-aurora + luci-app-aurora-config | Aurora 主题与配置器 | [eamonxg/luci-theme-aurora](https://github.com/eamonxg/luci-theme-aurora) · [eamonxg/luci-app-aurora-config](https://github.com/eamonxg/luci-app-aurora-config) |
| 主题 | luci-theme-liquid | Liquid 主题 | [zzsj0928/luci-theme-liquid](https://github.com/zzsj0928/luci-theme-liquid) |
| 主题 | luci-theme-shadcn | Shadcn 主题 | [eamonxg/luci-theme-shadcn](https://github.com/eamonxg/luci-theme-shadcn) |
| 主题 | luci-theme-footstrap | Footstrap 主题（替换 luci feeds 同名包） | [VizzleTF/luci-theme-footstrap](https://github.com/VizzleTF/luci-theme-footstrap) |
| 主题 | luci-theme-fluent + luci-mod-fluentdashboard | Fluent 主题与仪表盘 | [LazuliKao/luci-theme-fluent](https://github.com/LazuliKao/luci-theme-fluent) |
| 主题 | Obsidian-Theme | Obsidian 黑曜石主题 | [OnyxAxisOwO/Obsidian-Theme](https://github.com/OnyxAxisOwO/Obsidian-Theme) |

> **上游 Makefile 适配修复**（diy-part2.sh 自动完成）：graphite / Obsidian-Theme 的 `include ../../luci.mk` 改为 `$(TOPDIR)/feeds/luci/luci.mk`；footstrap 删除 feeds 残留链接防止同名顶替；dae 下载预编译二进制并修复 ARCH_PACKAGES 匹配；fancontrol 删除旧版子目录；mosdns 删除 feeds 链接防顶替；golang feeds 降级为 26.x（Go 1.26.8）兼容性最广；Docker feeds 替换为 sbwml fork 适配 25.12。

> 这些包在每次编译前由 diy-part1.sh 用 `git clone` 下载到源码树 `package/custom/`，OpenWrt 25.12 的包扫描深度为 5 层，整仓库放置即可被自动发现，无需手动移动子目录。

### 如何添加新的自定义包（含替换 feeds 自带包）

**固定三步，替换场景无需任何额外操作：**

1. **克隆**：`scripts/diy-part1.sh` 增加一行 `git clone` 到 `package/custom/`
2. **启用**：`config/bpi-r4.config` 增加 `CONFIG_PACKAGE_<包名>=y`
3. **登记**：`scripts/custom-packages.list` 增加一行包名

**关于替换 feeds 自带包：**

- OpenWrt 规则是 `package/` 内置目录**优先于 feeds**——只要 clone 进来的包与 feeds 里的同名（PKG_NAME 相同），feeds install 会自动跳过 feeds 版，你的版本自动顶替生效，**不需要做任何删除操作**
- 第 3 步的清单会触发 `verify-custom-packages.sh` 在每次编译前校验：包已扫描、来源是 `package/custom/`、已选入固件；若哪天被 feeds 版静默顶替，编译会立即报错而不是悄悄降级
- 查询某包是否与 feeds 同名（决定是否必须走第 3 步）：源码树内执行 `./scripts/feeds search <包名>`；建议所有 git clone 的包都登记清单，校验永远有益无害

## 快速开始

1. 点击右上角 **Star** 每周获取编译结果，或直接使用本仓库
2. 前往 **Actions** → **Build BPI-R4 OpenWrt** → **Run workflow** 手动触发一次编译
3. 等待约 3~5 小时（首次无缓存较慢，之后约 2~3 小时）
4. 编译完成后在 **Releases** 页面下载固件

> 公开仓库的 GitHub Actions 完全免费且不限时长，这就是本仓库保持 Public 的原因。

### 从本地推送到 GitHub（首次部署）

```bash
# 1. 先在 GitHub 网页上创建一个空的公开仓库（不要初始化 README）
# 2. 配置你的署名（替换为你的用户名）
git config user.name  "你的GitHub用户名"
git config user.email "你的GitHub用户名@users.noreply.github.com"
git commit --amend --reset-author --no-edit   # 更新首次提交的署名

# 3. 关联远程仓库并推送（替换 用户名/仓库名）
git remote add origin https://github.com/你的用户名/你的仓库名.git
git push -u origin main

# 4. 推送后手动触发一次编译：Actions → Build BPI-R4 OpenWrt → Run workflow
```

> 注意：`.github/workflows/` 只有推送到 GitHub 后才会生效，本地无法直接运行 Actions。

## 固件安装

**方式一：SD 卡启动（新手推荐，可随时拔卡回退）**

下载 `*-bpi-r4-sdcard.img.gz`，解压后用 balenaEtcher / dd 写入 SD 卡，插卡上电即启动。

**方式二：写入 eMMC（长期使用）**

先用 SD 卡启动系统，然后下载 `*-emmc-preloader.bin` 和 `*-emmc-bl31-uboot.fip`，在 OpenWrt 命令行执行：

```bash
# 先看 eMMC 设备名（通常是 mmcblk0）
ls /dev/mmcblk*
# 写入引导
dd if=emmc-preloader.bin of=/dev/mmcblk0 bs=512 seek=4
dd if=emmc-bl31-uboot.fip of=/dev/mmcblk0 bs=512 seek=2048
```

再通过 LuCI 或 `sysupgrade` 刷入 `*-sysupgrade.itb` 完成系统安装。

**方式三：已装系统升级**

直接用 `*-sysupgrade.itb`：LuCI → 系统 → 备份/升级，或命令行 `sysupgrade -v /tmp/sysupgrade.itb`。

## 如何定制

**增删插件**：编辑 [`config/bpi-r4.config`](config/bpi-r4.config)，加 `CONFIG_PACKAGE_luci-app-xxx=y` 一行即可（make defconfig 会自动补全依赖）。常用示例：

```bash
# 美化主题（源码自带）
CONFIG_PACKAGE_luci-theme-argon=y
# 限速
CONFIG_PACKAGE_luci-app-qosmate=y
```

**修改默认设置**：编辑 [`scripts/diy-part2.sh`](scripts/diy-part2.sh)，按注释取消相应 sed 命令（改管理 IP / 时区 / 主机名）。

**预置配置**：将配置文件按目录结构放入 `files/`，如 `files/etc/config/network`，编译时会合并进固件。

**换设备**：改 `config/bpi-r4.config` 中的 `CONFIG_TARGET_..._DEVICE_xxx`（本源码还支持 BPI-R4 Pro / Lite、RAX3000M 等大量 MT798x 设备）。

**改定时**：编辑 `.github/workflows/build-openwrt.yml` 中的 `cron`（UTC 时间，如 `0 3 * * 1` = 每周一）。

## 编译流水线说明

- 采用**单 Job 编译**，工具链缓存命中时跳过工具链编译阶段直接编译固件
- 工具链与源码包以缓存复用，源码不变时工具链阶段秒级跳过
- 手动触发时可选「忽略缓存强制全量重编」与「失败时 SSH 调试」
- 每次成功编译自动发布 Release，仅保留最近 4 个版本

## 免责声明

固件中包含的科学上网插件仅供学习研究网络技术使用，请遵守当地法律法规。

## 致谢

- [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) & [chasey-dev/immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase)
- [sbwml/openwrt_helloworld](https://github.com/sbwml/openwrt_helloworld)（Passwall 科学上网源）
- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)（工作流架构参考）
- [MediaTek MTK OpenWrt Feeds](https://github.com/mediatek/mtk-openwrt-feeds)