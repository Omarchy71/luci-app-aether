-- Aether LuCI settings (gool-only, Linksys EA8300). UCI mirror of Aethery's
-- connection profile for Protocol::Gool: the init script turns these into
-- the same CLI flags profiles.rs as_args() produces for gool
-- (--gool, --wg-peer, --wiw-outer/inner, --keepalive, WG-family --noize).
local m = Map("aether", translate("Aether"),
	translate("Censorship-circumvention core in gool-only mode (Linksys EA8300) with full-system TUN. Same flag map as the Aethery desktop app for gool."))

local conn = m:section(NamedSection, "main", "aether", translate("Connection"))
conn.addremove = false

local en = conn:option(Flag, "enabled", translate("Enabled"),
	translate("Start at boot and on Save & Apply."))
en.rmempty = false

local proto = conn:option(DummyValue, "protocol", translate("Protocol"))
proto.default = "gool"
proto.description = translate("Fixed to gool (WG-in-WG) in this build.")

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

local noize = conn:option(ListValue, "noize", translate("Obfuscation profile"),
	translate("gool uses the WireGuard table: balanced / aggressive / light / off."))
noize:value("balanced", translate("Balanced"))
noize:value("aggressive", translate("Aggressive"))
noize:value("light", translate("Light"))
noize:value("off", translate("Off"))

conn:option(Flag, "quick_reconnect", translate("Quick reconnect"))

local pin = m:section(NamedSection, "main", "aether", translate("Endpoint pinning"),
	translate("Skip the scan with known-good gool addresses (host:port). Empty = auto-scan."))
pin.addremove = false
pin:option(Value, "wg_peer", translate("gool peer (--wg-peer)"))
pin:option(Value, "wiw_outer", translate("gool outer (--wiw-outer)"))
pin:option(Value, "wiw_inner", translate("gool inner (--wiw-inner)"))
pin:option(Value, "wg_keepalive", translate("Keepalive in seconds (--keepalive, empty = core default)"))

local rt = m:section(NamedSection, "main", "aether", translate("Routing"))
rt.addremove = false

local di = rt:option(Flag, "direct_iran", translate("Direct Iranian sites"),
	translate("Sends all ~2900 aggregated Iranian prefixes plus major domestic apps straight out via the WAN instead of the tunnel. Merges with Direct below. Skipped while a custom rules file is set."))
di.rmempty = false

rt:option(TextValue, "route_direct", translate("Direct"),
	translate("Comma/newline separated: domain, IP/CIDR, port:443, private — same format as the core's --route-direct."))
rt:option(TextValue, "route_block", translate("Blocked"),
	translate("Same format as --route-block."))
rt:option(Value, "routes_file", translate("Rules file path (optional)"),
	translate("Custom [block]/[direct] rules file. Takes precedence: the Iranian preset is skipped while set."))

local vpn = m:section(NamedSection, "main", "aether", translate("VPN (TUN)"))
vpn.addremove = false

local vm = vpn:option(Flag, "vpn_mode", translate("Full-system VPN"),
	translate("Layer hev-socks5-tunnel under aether0 and move the default route onto it."))
vm.rmempty = false
vpn:option(Value, "tun_name", translate("Interface name"))
vpn:option(Value, "tun_mtu", translate("MTU (1280–9000, 1280–1420 for Iranian lines)"))
vpn:option(Value, "bind_address", translate("SOCKS bind (host:port)"))
vpn:option(Value, "dns", translate("Upstream DNS through the tunnel"))

return m
