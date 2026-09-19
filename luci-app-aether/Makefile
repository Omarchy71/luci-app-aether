include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-aether
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Madjid <omarchy7117@atomicmail.io>

# Aether Core v2.0.0 — armv7-musl statically linked (runs on ipq40xx/EA8300)
AETHER_VERSION:=v2.0.0
PKG_SOURCE:=aether-linux-armv7-musl.tar.gz
PKG_SOURCE_URL:=https://github.com/CluvexStudio/Aether/releases/download/$(AETHER_VERSION)/
PKG_HASH:=sha256:b2373438508f224400683c69bb50d9c935d28de514f1fde06e701cee58be878a

# hev-socks5-tunnel — ARM32v7 (required for full-system TUN)
HEV_VERSION:=2.17.1
PKG_SOURCE2:=hev-socks5-tunnel-linux-arm32v7
PKG_SOURCE_URL2:=https://github.com/heiher/hev-socks5-tunnel/releases/download/$(HEV_VERSION)/
PKG_HASH2:=sha256:a5248713ef084589d92edba2d0f56e784eb7d21c8944db797674b792833975ee

# Build architecture
PKGARCH:=arm_cortex-a7_neon-vfpv4

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-aether
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI support for Aether v2.0.0 gool (from-scratch redesign)
  +DEPENDS:=+luci-base +luci-lua-runtime +uhttpd-mod-lua +hev-socks5-tunnel +ip-full +kmod-tun +firewall4
  PKGARCH:=$(PKGARCH)
endef

define Package/luci-app-aether/description
  Complete LuCI web interface, procd service, and full-system TUN for the
  Aether v2.0.0 censorship-circumvention core (gool-only) on OpenWrt 24.10.5.
  Primary target: Linksys EA8300 (ipq40xx/generic).

  Features from-scratch redesigned:
  - Modern dashboard with real-time status polling
  - Connect/Disconnect control
  - Full gool-only flag parity with Aethery desktop app
  - HTTP CONNECT proxy support
  - Route sniffing with configurable timeout
  - TLS group configuration
  - Performance profile selector
  - Iranian direct routing
  - Egress checking (IP/country/ping)
  - Self-healing finish task with retry loop
  - All bundled in a single installable ipk package
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	# Extract Aether core binary
	$(TAR) -xzf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR)
	# Download and place hev-socks5-tunnel
	$(DL_DIR)/$(PKG_SOURCE2)
	cp $(DL_DIR)/$(PKG_SOURCE2) $(PKG_BUILD_DIR)/hev-socks5-tunnel
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luci-app-aether/install
	# Core binaries
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/aether $(1)/usr/sbin/aether
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/hev-socks5-tunnel $(1)/usr/bin/hev-socks5-tunnel

	# Scripts and data
	$(INSTALL_DIR) $(1)/usr/share/aether
	$(INSTALL_DATA) ./root/usr/share/aether/setup-lib.sh $(1)/usr/share/aether/setup-lib.sh
	$(INSTALL_DATA) ./root/usr/share/aether/finish.sh $(1)/usr/share/aether/finish.sh
	$(INSTALL_DATA) ./root/usr/share/aether/egress-check.sh $(1)/usr/share/aether/egress-check.sh
	$(INSTALL_DATA) ./root/usr/share/aether/refresh-iran-ranges.sh $(1)/usr/share/aether/refresh-iran-ranges.sh
	$(INSTALL_DATA) ./root/usr/share/aether/iran-v4.txt $(1)/usr/share/aether/iran-v4.txt
	$(INSTALL_DATA) ./root/usr/share/aether/iran-v6.txt $(1)/usr/share/aether/iran-v6.txt
	$(INSTALL_DATA) ./root/etc/config/aether $(1)/etc/config/aether

	# Init and hooks
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/aether $(1)/etc/init.d/aether
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) ./root/etc/hotplug.d/iface/99-aether-mark $(1)/etc/hotplug.d/iface/99-aether-mark
	$(INSTALL_DATA) ./root/etc/firewall.user $(1)/etc/firewall.user

	# LuCI web interface
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/controller/aether.lua $(1)/usr/lib/lua/luci/controller/aether.lua
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DATA) ./luasrc/model/cbi/aether.lua $(1)/usr/lib/lua/luci/model/cbi/aether.lua
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/aether
	$(INSTALL_DATA) ./luasrc/view/aether/status.htm $(1)/usr/lib/lua/luci/view/aether/status.htm
	$(INSTALL_DATA) ./root/usr/lib/lua/luci/sgi/uhttpd.lua $(1)/usr/lib/lua/luci/sgi/uhttpd.lua

	# LuCI static assets
	$(INSTALL_DIR) $(1)/www/luci-static/aether
endef

$(eval $(call BuildPackage,luci-app-aether))
