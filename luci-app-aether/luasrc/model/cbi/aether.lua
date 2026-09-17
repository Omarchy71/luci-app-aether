-- Aether LuCI — simplified control panel (gool-only, Linksys EA8300).
-- Big Connect/Disconnect button + full-traffic toggle.
-- Advanced settings (scan, noize, routing, pinning) remain available
-- in the same map for power users.
local m = Map("aether", translate("Aether"),
	translate("Gool-only censorship-circumvention core — OpenWrt router"))

-- ── Service control ──────────────────────────────────────────────
local s = m:section(NamedSection, "main", "aether", translate("Service"))
s.addremove = false

local st = s:option(DummyValue, "_state", translate("State"))
function st.cfgvalue(self, section)
	local st = luci.sys.exec("cat /var/run/aether/state 2>/dev/null"):gsub("\n", "")
	return (st == "") and "down" or st
end

local btn = s:option(Button, "_toggle")
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
	luci.http.redirect(luci.dispatcher.build_url("admin/services/aether"))
end

-- ── Full-traffic toggle ──────────────────────────────────────────
local vm = m:section(NamedSection, "main", "aether", translate("VPN Mode"))
vm.addremove = false

local vf = vm:option(Flag, "vpn_mode", translate("Full-system VPN"),
	translate("Layers hev-socks5-tunnel under aether0 and moves the default route onto it."))
vf.rmempty = false

-- ── TUN settings ─────────────────────────────────────────────────
local tn = m:section(NamedSection, "main", "aether", translate("TUN settings"))
tn.addremove = false
tn:option(Value, "tun_name", translate("Interface name"))
tn:option(Value, "tun_mtu", translate("MTU (1280–9000)"))
tn:option(Value, "bind_address", translate("SOCKS bind (host:port)"))
tn:option(Value, "dns", translate("Upstream DNS"))

-- ── Connection profile (advanced) ────────────────────────────────
local conn = m:section(NamedSection, "main", "aether", translate("Connection (advanced)"))
conn.addremove = false

conn:option(DummyValue, "protocol", translate("Protocol")).default = "gool"

local scan = conn:option(ListValue, "scan_mode", translate("Scan mode"))
scan:value("turbo", translate("Turbo"))
scan:value("balanced", translate("Balanced"))
scan:value("thorough", translate("Thorough"))
scan:value("stealth", translate("Stealth"))
scan:value("ironclad", translate("Ironclad"))

local ipv = conn:option(ListValue, "ip_version", translate("IP version"))
ipv:value("both", translate("Dual"))
ipv:value("v4", "IPv4")
ipv:value("v6", "IPv6")

local noize = conn:option(ListValue, "noize", translate("Obfuscation profile"))
noize:value("balanced", translate("Balanced"))
noize:value("aggressive", translate("Aggressive"))
noize:value("light", translate("Light"))
noize:value("off", translate("Off"))

conn:option(Flag, "quick_reconnect", translate("Quick reconnect"))

-- ── Endpoint pinning ─────────────────────────────────────────────
local pin = m:section(NamedSection, "main", "aether", translate("Endpoint pinning"),
	translate("Skip the scan with known-good gool addresses (host:port). Empty = auto-scan."))
pin.addremove = false
pin:option(Value, "wg_peer", translate("gool peer (--wg-peer)"))
pin:option(Value, "wiw_outer", translate("gool outer (--wiw-outer)"))
pin:option(Value, "wiw_inner", translate("gool inner (--wiw-inner)"))
pin:option(Value, "wg_keepalive", translate("Keepalive (seconds, empty = core default)"))

-- ── Routing ──────────────────────────────────────────────────────
local rt = m:section(NamedSection, "main", "aether", translate("Routing"))
rt.addremove = false

local di = rt:option(Flag, "direct_iran", translate("Direct Iranian sites"),
	translate("Sends Iranian prefixes via WAN instead of the tunnel. Merges with Direct below."))
di.rmempty = false

rt:option(TextValue, "route_direct", translate("Direct"),
	translate("Comma/newline: domain, IP/CIDR, port:443, private — same as core's --route-direct."))
rt:option(TextValue, "route_block", translate("Blocked"),
	translate("Same format as --route-block."))
rt:option(Value, "routes_file", translate("Rules file path (optional)"),
	translate("Custom [block]/[direct] file. Takes precedence over Iranian preset."))

return m