local m = Map("aether", translate("Aether Core"),
	translate("Multi-protocol censorship circumvention with auto-connect, auto-reconnect, and YouTube monitoring on OpenWrt 24.10.5"))

-- ══════════════════════════════════════════════════
-- Section 0: Core Toggle
-- ══════════════════════════════════════════════════
local s0 = m:section(NamedSection, "main", "aether", translate("Core Settings"))
s0:tab("core", translate("Core"))

local e = s0:taboption("core", Flag, "enabled", translate("Enable"), translate("Start Aether core on boot"))
e.rmempty = false
e.default = e.disabled

local proto = s0:taboption("core", ListValue, "protocol", translate("Protocol"), translate("Select protocol"))
proto:option("gool", "Gool (WG-in-WARP)")
proto:option("masque", "Masque (HTTP/3 QUIC + HTTP/2)")
proto:option("wg", "WireGuard")
proto:option("mim", "Mim (MASQUE-in-MASQUE)")
proto.rmempty = false
proto.default = "gool"

-- ══════════════════════════════════════════════════
-- Section 1: Auto-Connect & Auto-Reconnect
-- ══════════════════════════════════════════════════
local s1 = m:section(NamedSection, "main", "aether", translate("Auto-Connect & Auto-Reconnect"))
s1:tab("auto", translate("Auto"))

local ac = s1:taboption("auto", Flag, "auto_connect", translate("Auto-Connect on Boot"), translate("Automatically connect when router starts"))
ac.rmempty = false
ac.default = ac.enabled

local ar = s1:taboption("auto", Flag, "auto_reconnect", translate("Auto-Reconnect"), translate("Automatically reconnect when connection drops"))
ar.rmempty = false
ar.default = ar.enabled

local ri = s1:taboption("auto", Value, "reconnect_interval", translate("Reconnect Interval (s)"))
ri.datatype = "uinteger"
ri.default = "10"
ri:depends("auto_reconnect", "1")

local ma = s1:taboption("auto", Value, "max_reconnect_attempts", translate("Max Reconnect Attempts"))
ma.datatype = "uinteger"
ma.placeholder = "0"
ma.default = "0"
ma:description(translate("0 = unlimited attempts"))
ma:depends("auto_reconnect", "1")

local wi = s1:taboption("auto", Value, "watchdog_interval", translate("Watchdog Interval (s)"))
wi.datatype = "uinteger"
wi.default = "30"
wi:depends("auto_reconnect", "1")

-- ══════════════════════════════════════════════════
-- Section 2: YouTube Connectivity Check
-- ══════════════════════════════════════════════════
local s2 = m:section(NamedSection, "main", "aether", translate("YouTube Connectivity Check"))
s2:tab("youtube", translate("YouTube"))

local yc = s2:taboption("youtube", Flag, "youtube_check", translate("Enable YouTube Check"), translate("Continuously check if YouTube is accessible through the tunnel"))
yc.rmempty = false
yc.default = yc.enabled

local yi = s2:taboption("youtube", Value, "youtube_check_interval", translate("Check Interval (s)"))
yi.datatype = "uinteger"
yi.default = "60"
yi:depends("youtube_check", "1")

local yu = s2:taboption("youtube", Value, "check_url", translate("Check URL"))
yu.default = "https://www.youtube.com"
yu:depends("youtube_check", "1")

local yt = s2:taboption("youtube", Value, "check_timeout", translate("Timeout (s)"))
yt.datatype = "uinteger"
yt.default = "15"
yt:depends("youtube_check", "1")

-- ══════════════════════════════════════════════════
-- Section 3: Network Boot
-- ══════════════════════════════════════════════════
local s3 = m:section(NamedSection, "main", "aether", translate("Network Boot"))
s3:tab("wan", translate("WAN"))

local ww = s3:taboption("wan", Value, "wan_wait", translate("Wait for WAN (s)"))
ww.datatype = "uinteger"
ww.default = "30"

-- ══════════════════════════════════════════════════
-- Section 4: Protocol-Specific Settings
-- ══════════════════════════════════════════════════
-- Gool settings (visible when protocol=gool)
local s4 = m:section(NamedSection, "main", "aether", translate("Gool Settings"))
s4:tab("gool", translate("Gool"))
s4:depends("protocol", "gool")

local sm = s4:taboption("gool", ListValue, "scan_mode", translate("Scan Mode"))
sm:option("balanced", "Balanced")
sm:option("fast", "Fast")
sm:option("thorough", "Thorough")
sm:option("stealth", "Stealth")
sm:option("ironclad", "Ironclad")
sm.default = "balanced"

local iv = s4:taboption("gool", ListValue, "ip_version", translate("IP Version"))
iv:option("both", "Both")
iv:option("ipv4", "IPv4 Only")
iv:option("ipv6", "IPv6 Only")
iv.default = "both"

local nz = s4:taboption("gool", ListValue, "noize", translate("Noize Obfuscation"))
nz:option("none", "None")
nz:option("light", "Light")
nz:option("firewall", "Firewall")
nz:option("balanced", "Balanced")
nz:option("gfw", "GFW")
nz:option("aggressive", "Aggressive")
nz.default = "balanced"

local wr = s4:taboption("gool", Flag, "quick_reconnect", translate("Quick Reconnect"))
wr.default = "1"

local wps = s4:taboption("gool", Value, "wg_peer", translate("WG Peer Endpoint"))
wps.default = ""

local wos = s4:taboption("gool", Value, "wiw_outer", translate("WIW Outer Key"))
wos.default = ""

local wis = s4:taboption("gool", Value, "wiw_inner", translate("WIW Inner Key"))
wis.default = ""

local wss = s4:taboption("gool", Flag, "wiw_scan", translate("WIW Scan (auto endpoint)"))
wss.default = "1"

local wk = s4:taboption("gool", Value, "wg_keepalive", translate("WG Keepalive (s)"))
wk.datatype = "uinteger"
wk.default = "25"

local wc = s4:taboption("gool", Value, "wg_endpoint_cooldown", translate("WG Endpoint Cooldown (s)"))
wc.datatype = "uinteger"
wc.default = "300"

local ba = s4:taboption("gool", Value, "bind_address", translate("SOCKS Bind Address"))
ba.default = "127.0.0.1:1080"

local dn = s4:taboption("gool", Value, "dns", translate("DNS"))
dn.default = "1.1.1.1"

-- Masque settings
local s5 = m:section(NamedSection, "main", "aether", translate("Masque Settings"))
s5:tab("masque", translate("Masque"))
s5:depends("protocol", "masque")

local h2 = s5:taboption("masque", Flag, "masque_h2", translate("HTTP/2"))
h2.default = "0"

local qv = s5:taboption("masque", Flag, "masque_quic_v2", translate("QUIC v2"))
qv.default = "1"

local ec = s5:taboption("masque", ListValue, "masque_ech", translate("ECH Mode"))
ec:option("auto", "Auto")
ec:option("enabled", "Enabled")
ec:option("disabled", "Disabled")
ec.default = "auto"

local fr = s5:taboption("masque", Value, "masque_fragment", translate("TLS Fragment"))
fr.default = "0"

local fz = s5:taboption("masque", Value, "masque_fragment_size", translate("Fragment Size"))
fz.default = ""

local fd = s5:taboption("masque", Value, "masque_fragment_delay", translate("Fragment Delay"))
fd.default = ""

local tg = s5:taboption("masque", Value, "tls_groups", translate("TLS Groups"))
tg.default = ""

local hs = s5:taboption("masque", Value, "masque_h2_peer", translate("H2 Peer"))
hs.default = ""

local nd = s5:taboption("masque", Flag, "masque_no_data_check", translate("No Data Check"))
nd.default = "0"

local ss = s5:taboption("masque", Value, "startup_secs", translate("Startup Deadline (s)"))
ss.datatype = "uinteger"
ss.default = "30"

-- WireGuard settings
local s6 = m:section(NamedSection, "main", "aether", translate("WireGuard Settings"))
s6:tab("wg", translate("WireGuard"))
s6:depends("protocol", "wg")

local wps2 = s6:taboption("wg", Value, "wg_peer", translate("WG Peer"))
wps2.default = ""

local wk2 = s6:taboption("wg", Value, "wg_keepalive", translate("Keepalive (s)"))
wk2.datatype = "uinteger"
wk2.default = "25"

local ws2 = s6:taboption("wg", Flag, "no_profile_retry", translate("No Profile Retry"))
ws2.default = "0"

-- Mim settings
local s7 = m:section(NamedSection, "main", "aether", translate("MIM Settings"))
s7:tab("mim", translate("MIM"))
s7:depends("protocol", "mim")

local mo = s7:taboption("mim", Value, "mim_outer", translate("Outer MASQUE"))
mo.default = ""

local mi = s7:taboption("mim", Value, "mim_inner", translate("Inner MASQUE"))
mi.default = ""

-- Tor settings
local s8 = m:section(NamedSection, "main", "aether", translate("Tor Chain"))
s8:tab("tor", translate("Tor"))
s8:depends("protocol", "tor")

local tgb = s8:taboption("tor", Value, "tor_bridges", translate("Bridges"))
tgb.default = ""

local tpt = s8:taboption("tor", Value, "tor_pt", translate("Pluggable Transport"))
tpt.default = ""

-- ══════════════════════════════════════════════════
-- Section 5: General Settings
-- ══════════════════════════════════════════════════
local s9 = m:section(NamedSection, "main", "aether", translate("General"))
s9:tab("general", translate("General"))

local tm = s9:taboption("general", Value, "tun_name", translate("TUN Name"))
tm.default = "aether0"
local mt = s9:taboption("general", Value, "tun_mtu", translate("TUN MTU"))
mt.datatype = "uinteger"
mt.default = "1420"
local di = s9:taboption("general", Flag, "direct_iran", translate("Direct Iran Routes"))
di.default = "1"
local rs = s9:taboption("general", Flag, "route_sniff", translate("Route Sniffing"))
rs.default = "1"
local vs = s9:taboption("general", Value, "verbose", translate("Verbose"))
vs.datatype = "uinteger"
vs.default = "0"
local ls = s9:taboption("general", ListValue, "log_level", translate("Log Level"))
ls:option("debug", "Debug")
ls:option("info", "Info")
ls:option("warn", "Warning")
ls:option("error", "Error")
ls.default = "info"
local pf = s9:taboption("general", ListValue, "perf_profile", translate("Performance Profile"))
pf:option("low", "Low")
pf:option("medium", "Medium")
pf:option("high", "High")
pf.default = "low"
local rp = s9:taboption("general", Flag, "reprovision", translate("Reprovision"))
rp.default = "1"

-- Cloudflare Zero Trust
local s10 = m:section(NamedSection, "main", "aether", translate("Cloudflare Zero Trust"))
s10:tab("cf", translate("Zero Trust"))

local tm2 = s10:taboption("cf", Value, "team", translate("Team"))
tm2.default = ""
local aid = s10:taboption("cf", Value, "access_id", translate("Access ID"))
aid.default = ""
local ase = s10:taboption("cf", Value, "access_secret", translate("Access Secret"))
ase.default = ""
local ato = s10:taboption("cf", Value, "access_token", translate("Access Token"))
ato.default = ""
local aem = s10:taboption("cf", Value, "access_email", translate("Access Email"))
aem.default = ""
local gw = s10:taboption("cf", Flag, "gateway", translate("Gateway"))
gw.default = "0"


-- ─── Proxy Mode Section ───────────────────
local ps = m:section(NamedSection, "settings", "proxy", translate("Proxy Server"))

ps:tab("main", translate("Proxy Settings"))
local s = ps:taboption("main", Flag, "proxy_enabled", translate("Enable Proxy"), translate("Turn ON/OFF the local HTTP + SOCKS5 proxy server"))
s.rmempty = false
s.default = false

s = ps:taboption("main", Value, "http_port", translate("HTTP Proxy Port"), translate("Port for HTTP proxy (e.g. 8080)"))
s.datatype = "port"
s.default = 8080
s.rmempty = false

s = ps:taboption("main", Value, "socks_port", translate("SOCKS5 Proxy Port"), translate("Port for SOCKS5 proxy (e.g. 1080)"))
s.datatype = "port"
s.default = 1080
s.rmempty = false

s = ps:taboption("main", Value, "proxy_bind", translate("Bind Address"), translate("IP address to bind proxy to (0.0.0.0 = all interfaces)"))
s.default = "0.0.0.0"
s.rmempty = false
s.datatype = "ip4addr"

s = ps:taboption("main", ListValue, "mode", translate("Connection Mode"), translate("Select VPN tunnel or local proxy mode"))
s.default = "vpn"
s.rmempty = false
s:value("vpn", translate("VPN (WireGuard TUN)"))
s:value("proxy", translate("Proxy (HTTP + SOCKS5)"))

s = ps:taboption("main", DummyValue, "proxy_status", translate("Proxy Status"))
s.template = "aether/proxy_status"
s.readonly = true

return m
