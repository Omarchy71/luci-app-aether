-- Aether LuCI settings. Field-for-field the UCI mirror of Aethery's
-- connection profile: the init script turns these into the same CLI flags
-- profiles.rs as_args() produces. Gating mirrors the desktop UI: endpoint
-- pins only apply to their protocol family, fragment/ECH only to MASQUE.
local m = Map("aether", translate("Aether"),
	translate("Censorship-circumvention core (MASQUE / WireGuard / gool / mim) with full-system TUN. Same flag map as the Aethery desktop app."))

local conn = m:section(NamedSection, "main", "aether", translate("Connection"))
conn.addremove = false

local en = conn:option(Flag, "enabled", translate("Enabled"),
	translate("Start at boot and on Save & Apply."))
en.rmempty = false

local proto = conn:option(ListValue, "protocol", translate("Protocol"))
proto:value("auto", translate("Auto"))
proto:value("masque", "MASQUE")
proto:value("wg", translate("WireGuard"))
proto:value("gool", "gool")
proto:value("mim", "mim")

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
	translate("MASQUE family uses firewall / gfw / off; WireGuard and gool use balanced / aggressive / light / off."))
noize:value("firewall", translate("Firewall (MASQUE)"))
noize:value("gfw", "GFW (MASQUE)")
noize:value("balanced", translate("Balanced (WG/gool)"))
noize:value("aggressive", translate("Aggressive (WG/gool)"))
noize:value("light", translate("Light (WG/gool)"))
noize:value("off", translate("Off"))

conn:option(Flag, "quick_reconnect", translate("Quick reconnect"))

local pin = m:section(NamedSection, "main", "aether", translate("Endpoint pinning"),
	translate("Skip the scan with known-good addresses. Each field is only sent for its protocol family."))
pin.addremove = false
pin:option(Value, "peer", translate("MASQUE / WG / gool endpoint (--peer)"))
pin:option(Value, "wg_peer", translate("WG / gool peer (--wg-peer)"))
pin:option(Value, "wiw_outer", translate("gool outer (--wiw-outer)"))
pin:option(Value, "wiw_inner", translate("gool inner (--wiw-inner)"))
pin:option(Value, "mim_outer", translate("mim outer (--mim-outer)"))
pin:option(Value, "mim_inner", translate("mim inner (--mim-inner)"))
pin:option(Value, "wg_keepalive", translate("WireGuard keepalive (seconds)"))

local ev = m:section(NamedSection, "main", "aether", translate("MASQUE evasion"),
	translate("Only sent for the MASQUE family (auto counts)."))
ev.addremove = false
ev:option(Flag, "fragment", translate("Fragment"))
ev:option(Value, "fragment_size", translate("Fragment size range"))
ev:option(Value, "fragment_delay", translate("Fragment delay range"))
ev:option(Value, "ech", translate("ECH (off / auto / custom value)"))
ev:option(Value, "tls_groups", translate("TLS groups"))

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
