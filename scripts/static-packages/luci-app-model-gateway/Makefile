# luci-app-model-gateway —— 预编译集成版（非源码编译）
#
# 上游 wanvfx/luci-app-model-gateway 以 iStoreOS 应用发布（无 OpenWrt 包
# Makefile，唯一 Makefile 是 Go 项目自身的构建脚本），无法走标准源码编译。
# 本包采用官方 Release ipk 提取方案：
#   - ipk 为 gzip tar 格式，内含 debian-binary + control.tar.gz + data.tar.gz
#   - data.tar.gz 提供 model-gatewayd/-arm64 静态二进制（CGO=0 无运行时依赖）
#     + 标准 LuCI 文件（controller/cbi/view）+ /etc/init.d + /etc/config
#   - iStore 专属文件（istorec / opkg meta）随装但标准 OpenWrt 下不生效、无害
#
# 升级上游版本：改 PKG_VERSION / PKG_SOURCE（含发布日期后缀）/ PKG_HASH 三处。

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-model-gateway
PKG_VERSION:=1.9.3
PKG_RELEASE:=1

PKG_SOURCE:=luci-app-model-gateway_$(PKG_VERSION)-r20260821_all.ipk
PKG_SOURCE_URL:=https://github.com/wanvfx/luci-app-model-gateway/releases/download/v$(PKG_VERSION)/
PKG_HASH:=d557277c9f5672aa1af0762151632aac96a40f9bb1f9182b6d5692461d8f2bbd

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_LICENSE:=Apache-2.0

include $(INCLUDE_DIR)/package.mk

# .ipk 不在 OpenWrt 默认解压格式列表，禁用自动解包，全部在 Build/Prepare 手动处理
define PKG_UNPACK
endef

define Package/luci-app-model-gateway
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=AI Model Gateway (OpenAI-compatible, prebuilt)
  DEPENDS:=+luci-base
  PKGARCH:=all
endef

define Package/luci-app-model-gateway/description
  OpenAI 兼容 AI 模型网关：聚合 NVIDIA / 商汤 / 魔搭 / Gemini 等平台免费额度，
  统一接口 + 自动故障转移 + 质量/延迟加权路由。
  本包提取上游 iStoreOS ipk 官方二进制，集成进 OpenWrt 构建链。
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	tar xzf "$(DL_DIR)/$(PKG_SOURCE)" -C $(PKG_BUILD_DIR)
	tar xzf $(PKG_BUILD_DIR)/data.tar.gz -C $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/luci-app-model-gateway/install
	$(INSTALL_DIR) $(1)/etc $(1)/usr
	cp -a $(PKG_BUILD_DIR)/etc/. $(1)/etc/
	cp -a $(PKG_BUILD_DIR)/usr/. $(1)/usr/
	# 中文翻译：上游 .po 位于非标准路径（usr/lib/lua/luci/i18n/zh-cn/），
	# LuCI 不加载该位置的 .po。本包预编译 .lmo 随仓库分发（平台无关数据文件，
	# 由 feeds/luci/modules/luci-base/src/po2lmo 转换生成），避免构建顺序依赖。
	# 上游更新翻译时重新生成：po2lmo <上游po> model-gateway.zh-cn.lmo
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DATA) $(CURDIR)/model-gateway.zh-cn.lmo \
		$(1)/usr/lib/lua/luci/i18n/model-gateway.zh-cn.lmo
	rm -rf $(1)/usr/lib/lua/luci/i18n/zh-cn
	# iStore 专属文件（opkg meta / istorec）保留无碍；如需精简可在此删除
endef

$(eval $(call BuildPackage,luci-app-model-gateway))