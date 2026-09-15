include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-aether
PKG_VERSION:=0.2.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Madjid <omarchy7117@atomicmail.io>

# Same core + version as the Aethery desktop app. armv7-musl is statically
# linked, so it runs on any armv7 OpenWrt target (built here for ipq40xx).
AETHER_VERSION:=v2.0.0
PKG_SOURCE:=aether-linux-armv7-musl.tar.gz
PKG_SOURCE_URL:=https://github.com/CluvexStudio/Aether/releases/download/$(AETHER_VERSION)/
PKG_HASH:=b2373438508f224400683c69bb50d9c935d28de514f1fde06e701cee58be878a

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKGARCH:=arm_cortex-a7_neon-vfpv4

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-aether
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI support for Aether gool + Iran direct routing (Linksys EA8300)
  DEPENDS:=+luci-base +hev-socks5-tunnel +ip-full +kmod-tun
  PKGARCH:=arm_cortex-a7_neon-vfpv4
endef

define Package/luci-app-aether/description
  Web UI and procd service driving the Aether v2.0.0 censorship-circumvention
  core in gool-only mode on OpenWrt routers (primary target: Linksys EA8300,
  ipq40xx/generic): full-system TUN via hev-socks5-tunnel and one-switch
  direct routing for all Iranian destinations.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(TAR) -xzf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luci-app-aether/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/aether $(1)/usr/sbin/aether
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/controller/aether.lua $(1)/usr/lib/lua/luci/controller/aether.lua
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DATA) ./luasrc/model/cbi/aether.lua $(1)/usr/lib/lua/luci/model/cbi/aether.lua
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/aether
	$(INSTALL_DATA) ./luasrc/view/aether/status.htm $(1)/usr/lib/lua/luci/view/aether/status.htm
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./root/etc/config/aether $(1)/etc/config/aether
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/aether $(1)/etc/init.d/aether
	$(INSTALL_DIR) $(1)/usr/share/aether
	$(INSTALL_DATA) ./root/usr/share/aether/iran-v4.txt $(1)/usr/share/aether/iran-v4.txt
	$(INSTALL_DATA) ./root/usr/share/aether/iran-v6.txt $(1)/usr/share/aether/iran-v6.txt
endef

$(eval $(call BuildPackage,luci-app-aether))
