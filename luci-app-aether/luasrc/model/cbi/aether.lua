-- Aether LuCI CBI model (from-scratch redesign).
-- Modern organized settings for Aether v2.0.0 gool-only on OpenWrt 24.10.5.
local m = Map("aether", translate("Aether Core"),
	translate("Gool (WG-in-WARP) censorship circumvention · OpenWrt 24.10.5"))

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

local vpn_mode = s1:option(Flag, "vpn_mode", translate("Full-system VPN"),
	translate("Layers hev-socks5-tunnel under the TUN interface and routes all traffic through it. Disable for SOCKS5-proxy-only mode."))
vpn_mode.rmempty = false

local tun_name = s1:option(Value, "tun_name", translate("TUN interface"))
tun_name.rmempty = false
tun_name.placeholder = "aether0"

local bind_addr = s1:option(Value, "bind_address", translate("SOCKS5 bind address"))
bind_addr.rmempty = false
bind_addr.placeholder = "127.0.0.1:1080"
bind_addr.description = translate("Local SOCKS5 proxy address. Also drives the hev TUN configuration.")

-- ═══════════════════════════════════════════════════════
-- SECTION 2: Connection Profile
-- ═══════════════════════════════════════════════════════
local s2 = m:section(NamedSection, "main", "aether", translate("Connection Profile"))
s2.addremove = false
s2.description = translate("Protocol is fixed to gool (WARP-in-WARP). Settings below control endpoint discovery and obfuscation.")

local scan_mode = s2:option(ListValue, "scan_mode", translate("Scan mode"))
scan_mode:value("turbo", translate("Turbo") .. " — " .. translate("Stop at first candidate"))
scan_mode:value("balanced", translate("Balanced") .. " — " .. translate("Default: fast + reliable"))
scan_mode:value("thorough", translate("Thorough") .. " — " .. translate("Full range sweep"))
scan_mode:value("stealth", translate("Stealth") .. " — " .. translate("Minimal probes"))
scan_mode:value("ironclad", translate("Ironclad") .. " — " .. translate("Real HTTP validation"))
scan_mode.default = "balanced"

local ip_version = s2:option(ListValue, "ip_version", translate("IP version"))
ip_version:value("both", translate("Dual (IPv4 + IPv6)"))
ip_version:value("v4", "IPv4 only")
ip_version:value("v6", "IPv6 only")

local noize = s2:option(ListValue, "noize", translate("Obfuscation profile"))
noize:value("balanced", translate("Balanced") .. " — " .. translate("Default for gool"))
noize:value("gfw", translate("Great Firewall") .. " — " .. translate("China-adapted"))
noize:value("aggressive", translate("Aggressive") .. " — " .. translate("Maximum obfuscation"))
noize:value("light", translate("Light") .. " — " .. translate("Minimal overhead"))
noize:value("none", translate("Off"))
noize.default = "balanced"

local qr = s2:option(Flag, "quick_reconnect", translate("Quick reconnect"),
	translate("Auto-accept the last known working gateway on reconnect. Disable for fresh scans every time."))
qr.rmempty = false

local npr = s2:option(Flag, "no_profile_retry", translate("No profile retry"),
	translate("Do not retry other obfuscation profiles during scan. Faster but less resilient."))
npr.rmempty = false

-- ═══════════════════════════════════════════════════════
-- SECTION 3: Endpoint Pinning
-- ═══════════════════════════════════════════════════════
local s3 = m:section(NamedSection, "main", "aether", translate("Endpoint Pinning"))
s3.addremove = false
s3.description = translate("Name known-good WARP-in-WARP endpoints to skip the scan. Leave empty for automatic discovery.")

local wg_peer = s3:option(Value, "wg_peer", translate("gool peer (--wg-peer)"))
wg_peer.placeholder = "host:port"
wg_peer:depends("quick_reconnect", "0")

local wiw_outer = s3:option(Value, "wiw_outer", translate("Outer hop (--wiw-outer)"))
wiw_outer.placeholder = "host:port"

local wiw_inner = s3:option(Value, "wiw_inner", translate("Inner hop (--wiw-inner)"))
wiw_inner.placeholder = "host:port"

local keepalive = s3:option(Value, "wg_keepalive", translate("WireGuard keepalive (seconds)"))
keepalive.placeholder = "25"
keepalive.datatype = "uinteger"

local cooldown = s3:option(Value, "wg_endpoint_cooldown", translate("Endpoint cooldown (seconds)"))
cooldown.placeholder = "300"
cooldown.datatype = "uinteger"
cooldown.description = translate("How long a failed endpoint is excluded from rescans.")

-- ═══════════════════════════════════════════════════════
-- SECTION 4: Advanced Transport
-- ═══════════════════════════════════════════════════════
local s4 = m:section(NamedSection, "main", "aether", translate("Transport Settings"))
s4.addremove = false

local http_proxy = s4:option(Flag, "http_proxy", translate("HTTP CONNECT proxy"),
	translate("Exposes an additional HTTP CONNECT proxy at the configured port. Useful for browsers that don't support SOCKS5."))
http_proxy.rmempty = false

local http_port = s4:option(Value, "http_port", translate("HTTP proxy port"))
http_port.placeholder = "1820"
http_port.datatype = "port"
http_port:depends("http_proxy", "1")

local tls_groups = s4:option(Value, "tls_groups", translate("TLS key share groups"))
tls_groups.placeholder = "P-256:X25519:P-384"
tls_groups.description = translate("Space-separated or colon-separated TLS groups. Leave empty for defaults.")

local validate = s4:option(Value, "validate_secs", translate("Validate seconds"))
validate.placeholder = "10"
validate.datatype = "uinteger"
validate.description = translate("Seconds to wait for data-plane validation before considering the tunnel up.")

local reconnect = s4:option(Value, "reconnect_secs", translate("Reconnect delay (seconds)"))
reconnect.placeholder = "2"
reconnect.datatype = "uinteger"

-- ═══════════════════════════════════════════════════════
-- SECTION 5: Routing
-- ═══════════════════════════════════════════════════════
local s5 = m:section(NamedSection, "main", "aether", translate("Routing"))
s5.addremove = false

local direct_iran = s5:option(Flag, "direct_iran", translate("Direct Iranian sites"),
	translate("Sends Iranian IP prefixes via WAN instead of the tunnel. Merges with Direct routes below."))
direct_iran.rmempty = false

local route_direct = s5:option(TextValue, "route_direct", translate("Direct routes"),
	translate("Comma or newline-separated: domain, IP/CIDR, port:443, private. Same format as core's --route-direct."))

local route_block = s5:option(TextValue, "route_block", translate("Blocked routes"),
	translate("Same format as --route-block. These domains/IPs never reach the network."))

local routes_file = s5:option(Value, "routes_file", translate("Custom rules file"))
routes_file.placeholder = "/path/to/rules.txt"
routes_file.description = translate("Path to a [block]/[direct] rules file. Takes precedence over Iranian preset.")

local route_sniff = s5:option(Flag, "route_sniff", translate("Route sniffing"),
	translate("Reads the SNI from the first bytes of a connection to route correctly behind a TUN. Disable only if you know what you're doing."))
route_sniff.rmempty = false

local sniff_ms = s4:option(Value, "sniffing_timeout_ms", translate("Route sniff timeout (ms)"))
sniff_ms.placeholder = "400"
sniff_ms.datatype = "uinteger"
sniff_ms:depends("route_sniff", "1")

local reprovision = s4:option(Flag, "reprovision", translate("Auto-reprovision"))
reprovision.rmempty = false
reprovision.description = translate("Allow the core to replace a refused WARP identity with a freshly registered one.")

-- ═══════════════════════════════════════════════════════
-- SECTION 6: DNS & Performance
-- ═══════════════════════════════════════════════════════
local s6 = m:section(NamedSection, "main", "aether", translate("DNS & Performance"))
s6.addremove = false

local dns = s6:option(Value, "dns", translate("Upstream DNS"))
dns.rmempty = false
dns.placeholder = "1.1.1.1"
dns.description = translate("Comma-separated DNS resolvers used inside the tunnel.")

local perf = s6:option(ListValue, "perf_profile", translate("Performance profile"))
perf:value("low", translate("Low (routers/embedded)"))
perf:value("medium", translate("Medium (typical desktop)"))
perf:value("high", translate("High (servers)"))
perf.description = translate("Force a resource profile. 'low' is recommended for the Linksys EA8300.")

local netstack_rx = s6:option(Value, "netstack_tcp_rx", translate("Netstack TCP RX buffer"))
netstack_rx.placeholder = "auto"

local netstack_tx = s6:option(Value, "netstack_tcp_tx", translate("Netstack TCP TX buffer"))
netstack_tx.placeholder = "auto"

local tun_mtu = s5:option(Value, "tun_mtu", translate("TUN MTU"))
tun_mtu.placeholder = "1420"
tun_mtu.datatype = "uinteger"
tun_mtu.description = translate("1280–9000. Default 1420 works for most setups.")

return m
