---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '71a0065c-fe43-41fa-9e28-bbb91b6aa463'
  PropagateID: '71a0065c-fe43-41fa-9e28-bbb91b6aa463'
  ReservedCode1: '6e2c0ba6-9a8e-4803-9ecf-5930cb27dbad'
  ReservedCode2: '6e2c0ba6-9a8e-4803-9ecf-5930cb27dbad'
---

# BPI-R4 OpenWrt 自动编译

使用 GitHub Actions **定时自动编译** Banana Pi BPI-R4（标准版，MT7988A）的 ImmortalWrt 固件，内置 Passwall 科学上网插件与 6 个自定义 LuCI 应用。

## 固件信息

| 项目 | 说明 |
|---|---|
| 硬件平台 | Banana Pi BPI-R4 标准版 (MT7988A / 4GB RAM / 32GB eMMC) |
| 固件源码 | [chasey-dev/immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase) (ImmortalWrt 25.12 + MTK 官方 Feeds，内核 6.12) |
| 科学上网 | **Passwall** (Xray / sing-box / Hysteria，SSR / Shadowsocks 等全协议) |
| 自定义插件 | **Honk** 微博客、**OxiDNS** DNS 分流、**NetMonitor** 网络质量监控、**TrafficCtl** 流量控制、**AdGuard Home** 去广告、**HW Dashboard** 硬件仪表盘 |
| 管理界面 | LuCI 中文 |
| 默认地址 | `192.168.1.1`，账号 `root`，无密码 |
| 更新频率 | 每周一北京时间 11:00 自动编译 |

## 仓库结构

```
├── .github/workflows/
│   └── build-openwrt.yml    # 编译工作流（定时 + 手动触发）
├── scripts/
│   ├── diy-part1.sh         # [feeds 阶段] 注入 Passwall 源 + git clone 自定义包到 package/custom/
│   └── diy-part2.sh         # [编译前] 修改默认 IP / 时区 / 版本号等（示例已注释）
├── config/
│   └── bpi-r4.config        # 固件配置种子文件（加/减插件改这里）
├── files/                   # 预置配置目录（放入 etc/xxx 会合并进固件）
└── README.md
```

### 自定义 LuCI 应用说明（diy-part1.sh git clone 方式注入）

| 插件 | 功能 | 来源仓库 |
|---|---|---|
| luci-app-honk | Honk 微博客（含后端） | [QiuSimons/luci-app-honk](https://github.com/QiuSimons/luci-app-honk) |
| luci-app-oxidns | OxiDNS DNS 分流 | [hahaher123/luci-app-oxidns](https://github.com/hahaher123/luci-app-oxidns) |
| luci-app-netmonitor | 网络质量监控（延迟/丢包） | [LianXia233/luci-app-netmonitor](https://github.com/LianXia233/luci-app-netmonitor) |
| luci-app-trafficctl | 流量控制（限速/整形/断网） | [YusDyr/luci-app-trafficctl](https://github.com/YusDyr/luci-app-trafficctl) |
| luci-app-adguardhome | AdGuard Home 去广告（**替换 luci feeds 自带旧版**，内置目录优先于 feeds） | [terrytyc/luci-app-adguardhome](https://github.com/terrytyc/luci-app-adguardhome) |
| luci-app-hw-dashboard | 硬件信息仪表盘 | [AliLostInTheDark/luci-app-hw-dashboard](https://github.com/AliLostInTheDark/luci-app-hw-dashboard) |

> 这些包在每次编译前由 diy-part1.sh 用 `git clone` 下载到源码树 `package/custom/`，OpenWrt 25.12 的包扫描深度为 5 层，整仓库放置即可被自动发现，无需手动移动子目录。

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
# 去广告
CONFIG_PACKAGE_luci-app-adguardhome=y
```

**修改默认设置**：编辑 [`scripts/diy-part2.sh`](scripts/diy-part2.sh)，按注释取消相应 sed 命令（改管理 IP / 时区 / 主机名）。

**预置配置**：将配置文件按目录结构放入 `files/`，如 `files/etc/config/network`，编译时会合并进固件。

**换设备**：改 `config/bpi-r4.config` 中的 `CONFIG_TARGET_..._DEVICE_xxx`（本源码还支持 BPI-R4 Pro / Lite、RAX3000M 等大量 MT798x 设备）。

**改定时**：编辑 `.github/workflows/build-openwrt.yml` 中的 `cron`（UTC 时间，如 `0 3 * * 1` = 每周一）。

## 编译流水线说明

- 采用**两阶段编译**（工具链 → 固件），确保单次任务不超过 GitHub Actions 6 小时上限
- 工具链与源码包以缓存复用，源码不变时工具链阶段秒级跳过
- 手动触发时可选「忽略缓存强制全量重编」与「失败时 SSH 调试」
- 每次成功编译自动发布 Release，仅保留最近 4 个版本

## 免责声明

固件中包含的科学上网插件仅供学习研究网络技术使用，请遵守当地法律法规。

## 致谢

- [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) & [chasey-dev/immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase)
- [Passwall](https://github.com/Openwrt-Passwall/openwrt-passwall) (Openwrt-Passwall Organization)
- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)（工作流架构参考）
- [MediaTek MTK OpenWrt Feeds](https://github.com/mediatek/mtk-openwrt-feeds)