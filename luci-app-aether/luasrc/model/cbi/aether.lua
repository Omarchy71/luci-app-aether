-- Aether LuCI CBI model (multi-protocol support).
-- Settings for Aether v2.0.0: gool, masque, wg, mim on OpenWrt 24.10.5.
local m = Map("aether", translate("Aether Core"),
	translate("Multi-protocol censorship circumvention · gool, masque, wg, mim · OpenWrt 24.10.5"))

m.redirect = luci.dispatcher.build_url("admin", "services", "aether", "status")

-- ═══════════════════════════════════════════════════════
-- SECTION 1: Quick Status & Control
-- ═══════════════════════════════════════════════════════
local s1 = m:section(NamedSection, "main", "aether", translate("Service Control"))
s1.addremove = false

local state_val = s1:option(DummyValue, "_state", translate("Status"))
function state_val.cfgvalue(self, section)
	local st = luci.sys.exec("cat /var/run/aether/state 2>/dev/null"):gsub("\n", "")
	return (st == "") and translate("down") or st
end

local btn = s1:option(Button, "_toggle", translate("Toggle Connection"))
function btn.cfgvalue(self, section)
	local st = luci.sys.exec("cat /var/run/aether/state 2>/dev/null"):gsub("\n", "")
	if st == "up" then
		self.inputtitle = translate("Disconnect")
		self.inputstyle = "reset"
	else
		self.inputtitle = translate("Connect")
		self.inputstyle = "apply"
	end
end
function btn.write(self, section)
	local st = luci.sys.exec("cat /var/run/aether/state 2>/dev/null"):gsub("\n", "")
	if st == "up" then
		luci.sys.call("/etc/init.d/aether disable; /etc/init.d/aether stop >/dev/null 2>&1")
	else
		luci.sys.call("/etc/init.d/aether enable; /etc/init.d/aether start >/dev/null 2>&1")
	end
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "aether"))
end

local protocol = s1:option(ListValue, "protocol", translate("Protocol"))
protocol:value("gool", translate("Gool (WG-in-WARP)") .. " — " .. translate("Recommended"))
protocol:value("masque", translate("Masque") .. " — " .. translate("HTTP/3 QUIC + HTTP/2"))
protocol:value("wg", translate("WireGuard") .. " — " .. translate("Classic WG"))
protocol:value("mim", translate("Mim (MASQUE-in-MASQUE)"))
protocol.rmempty = false
protocol.description = translate("Select the protocol. Changing requires restart. Gool is the default.")

local vpn_mode = s1:option(Flag, "vpn_mode", translate("Full-system VPN"),
	translate("Layers hev-socks5-tunnel under the TUN interface."))
vpn_mode.rmempty = false

local tun_name = s1:option(Value, "tun_name", translate("TUN interface"))
tun_name.rmempty = false
tun_name.placeholder = "aether0"

local bind_addr = s1:option(Value, "bind_address", translate("SOCKS5 bind address"))
bind_addr.rmempty = false
bind_addr.placeholder = "127.0.0.1:1080"

-- ═══════════════════════════════════════════════════════
-- SECTION 2: Connection Profile
-- ═══════════════════════════════════════════════════════
local s2 = m:section(NamedSection, "main", "aether", translate("Connection Profile"))
s2.addremove = false
s2.description = translate("Protocol set above. Controls endpoint discovery and obfuscation.")

local scan_mode = s2:option(ListValue, "scan_mode", translate("Scan mode"))
scan_mode:value("turbo", translate("Turbo"))
scan_mode:value("balanced", translate("Balanced"))
scan_mode:value("thorough", translate("Thorough"))
scan_mode:value("stealth", translate("Stealth"))
scan_mode:value("ironclad", translate("Ironclad"))
scan_mode.default = "balanced"

local ip_version = s2:option(ListValue, "ip_version", translate("IP version"))
ip_version:value("both", translate("Dual (IPv4 + IPv6)"))
ip_version:value("v4", "IPv4 only")
ip_version:value("v6", "IPv6 only")

local noize = s2:option(ListValue, "noize", translate("Obfuscation profile"))
noize:value("balanced", translate("Balanced"))
noize:value("gfw", translate("Great Firewall"))
noize:value("aggressive", translate("Aggressive"))
noize:value("light", translate("Light"))
noize:value("firewall", translate("Firewall"))
noize:value("none", translate("Off"))
noize.default = "balanced"
noize.description = translate("For gool and mim protocols.")

local qr = s2:option(Flag, "quick_reconnect", translate("Quick reconnect"))
qr.rmempty = false

local npr = s2:option(Flag, "no_profile_retry", translate("No profile retry"))
npr.rmempty = false

-- ═══════════════════════════════════════════════════════
-- SECTION 3: Gool Endpoint Pinning
-- ═══════════════════════════════════════════════════════
local s3 = m:section(NamedSection, "main", "aether", translate("Gool Endpoint Pinning"))
s3.addremove = false
s3:depends("protocol", "gool")
s3.description = translate("Name known-good WG-in-WARP endpoints. Empty = auto-scan.")

s3:option(Value, "wg_peer", translate("gool peer"))
s3:option(Value, "wiw_outer", translate("Outer hop"))
s3:option(Value, "wiw_inner", translate("Inner hop"))
s3:option(Flag, "wiw_scan", translate("Auto-scan endpoints"))
s3:option(Value, "wg_keepalive", translate("Keepalive (seconds)"))
s3:option(Value, "wg_endpoint_cooldown", translate("Endpoint cooldown (seconds)"))
s3:option(Value, "wg_stale_secs", translate("WG stale timeout (seconds)"))

-- ═══════════════════════════════════════════════════════
-- SECTION 4: Masque Transport
-- ═══════════════════════════════════════════════════════
local s4 = m:section(NamedSection, "main", "aether", translate("Masque Transport"))
s4.addremove = false
s4:depends("protocol", "masque")

s4:option(Flag, "masque_h2", translate("HTTP/2 (TCP) instead of HTTP/3"))
s4:option(Flag, "masque_quic_v2", translate("QUIC v2 opener"))
s4:option(Value, "masque_ech", translate("ECH (auto or base64)"))
s4:option(Value, "tls_groups", translate("TLS key share groups"))
s4:option(Flag, "masque_fragment", translate("Fragment TLS ClientHello"))
s4:option(Value, "masque_fragment_size", translate("Fragment size"))
s4:option(Value, "masque_fragment_delay", translate("Fragment delay (ms)"))
s4:option(Value, "masque_h2_peer", translate("HTTP/2 peer override"))
s4:option(Flag, "masque_no_data_check", translate("Skip data-plane validation"))
s4:option(Value, "startup_secs", translate("Startup deadline (seconds)"))
s4:option(Value, "masque_h2_keepalive_secs", translate("HTTP/2 keepalive (seconds)"))

-- ═══════════════════════════════════════════════════════
-- SECTION 5: Mim
-- ═══════════════════════════════════════════════════════
local s5 = m:section(NamedSection, "main", "aether", translate("MASQUE-in-MASQUE"))
s5.addremove = false
s5:depends("protocol", "mim")

s5:option(Value, "mim_outer", translate("Outer hop"))
s5:option(Value, "mim_inner", translate("Inner hop"))
s5:option(Flag, "masque_h2", translate("HTTP/2 for both hops"))

-- ═══════════════════════════════════════════════════════
-- SECTION 6: Tor
-- ═══════════════════════════════════════════════════════
local s6 = m:section(NamedSection, "main", "aether", translate("Tor Chaining"))
s6.addremove = false
s6:option(Flag, "tor", translate("Enable Tor"))
s6:option(Value, "tor_bind", translate("Tor bind"))
s6:option(Value, "tor_dir", translate("Tor directory"))
s6:option(TextValue, "tor_bridges", translate("Tor bridges"))
s6:option(TextValue, "tor_pt", translate("Tor pluggable transport"))

-- ═══════════════════════════════════════════════════════
-- SECTION 7: Routing
-- ═══════════════════════════════════════════════════════
local s7 = m:section(NamedSection, "main", "aether", translate("Routing"))
s7.addremove = false

s7:option(Flag, "direct_iran", translate("Direct Iranian sites"))
s7:option(TextValue, "route_direct", translate("Direct routes"))
s7:option(TextValue, "route_block", translate("Blocked routes"))
s7:option(Value, "routes_file", translate("Custom rules file"))
s7:option(Flag, "route_sniff", translate("Route sniffing"))
s7:option(Value, "sniffing_timeout_ms", translate("Sniff timeout (ms)"))
s7:option(Flag, "reprovision", translate("Auto-reprovision"))

-- ═══════════════════════════════════════════════════════
-- SECTION 8: Proxy & Resources
-- ═══════════════════════════════════════════════════════
local s8 = m:section(NamedSection, "main", "aether", translate("Proxy & Resources"))
s8.addremove = false

s8:option(Flag, "http_proxy", translate("HTTP CONNECT proxy"))
s8:option(Value, "http_port", translate("HTTP proxy port"))
s8:option(Value, "upstream_proxy", translate("Upstream proxy"))
s8:option(Value, "netstack_tcp_rx", translate("Netstack TCP RX buffer"))
s8:option(Value, "netstack_tcp_tx", translate("Netstack TCP TX buffer"))
s8:option(Value, "max_clients", translate("Max concurrent clients"))

-- ═══════════════════════════════════════════════════════
-- SECTION 9: Cloudflare Zero Trust
-- ═══════════════════════════════════════════════════════
local s9 = m:section(NamedSection, "main", "aether", translate("Cloudflare Zero Trust"))
s9.addremove = false
s9:option(Value, "team", translate("Team name"))
s9:option(Value, "access_id", translate("Access client ID"))
s9:option(Value, "access_secret", translate("Access secret"))
s9:option(Value, "access_token", translate("Access token"))
s9:option(Value, "access_email", translate("Access email"))
s9:option(Flag, "gateway", translate("Gateway proxy"))

-- ═══════════════════════════════════════════════════════
-- SECTION 10: DNS & Performance
-- ═══════════════════════════════════════════════════════
local s10 = m:section(NamedSection, "main", "aether", translate("DNS & Performance"))
s10.addremove = false

s10:option(Value, "dns", translate("Upstream DNS"))
s10:option(ListValue, "log_level", translate("Log level")):value("info", "Info")
s10:option(Flag, "verbose", translate("Verbose"))
s10:option(ListValue, "perf_profile", translate("Performance profile"))
s10:option(Value, "tun_mtu", translate("TUN MTU"))

return m
