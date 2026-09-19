-- Aether LuCI controller (from-scratch redesign).
-- Modern dashboard API with real-time status, traffic, and egress.
module("luci.controller.aether", package.seeall)

function index()
	entry({"admin", "services", "aether"},
		cbi("aether"), _("Aether"), 60).dependent = true
	entry({"admin", "services", "aether", "status"},
		template("aether/status"), _("Status"), 1).leaf = true
	entry({"admin", "services", "aether", "api", "status"},
		call("act_api_status"), nil).leaf = true
	entry({"admin", "services", "aether", "api", "connect"},
		call("act_api_connect"), nil).leaf = true
	entry({"admin", "services", "aether", "api", "egress"},
		call("act_api_egress"), nil).leaf = true
	entry({"admin", "services", "aether", "api", "log"},
		call("act_api_log"), nil).leaf = true
	entry({"admin", "services", "aether", "api", "config"},
		call("act_api_config"), nil).leaf = true
end

function act_api_status()
	local run = "/var/run/aether"
	local state = luci.sys.exec("cat " .. run .. "/state 2>/dev/null"):gsub("\n", "")
	if state == "" then state = "down" end
	local uptime = luci.sys.exec("cat " .. run .. "/uptime 2>/dev/null"):gsub("\n", "")
	local core_pid = luci.sys.exec("cat " .. run .. "/core.pid 2>/dev/null"):gsub("\n", "")
	local core_log = luci.sys.exec("tail -5 " .. run .. "/core.log 2>/dev/null"):gsub("\n", "|")
	local tun_name = luci.sys.exec("uci -q get aether.main.tun_name 2>/dev/null"):gsub("\n", "")
	if tun_name == "" then tun_name = "aether0" end
	local tun_info = luci.sys.exec("ip -o link show " .. tun_name .. " 2>/dev/null"):gsub("\n", "")

	luci.http.prepare_content("application/json")
	luci.http.write(string.format(
		'{"state":"%s","uptime":"%s","core_pid":"%s","tun_name":"%s","tun_info":"%s","last_log":"%s"}',
		state, uptime, core_pid, tun_name, tun_info, core_log
	))
end

function act_api_connect()
	local action = luci.http.formvalue("action") or luci.http.formvalue("toggle")
	local run = "/var/run/aether"
	if action == "connect" or action == "on" then
		luci.sys.call("/etc/init.d/aether enable; /etc/init.d/aether start >/dev/null 2>&1")
	elseif action == "disconnect" or action == "off" then
		luci.sys.call("/etc/init.d/aether disable; /etc/init.d/aether stop >/dev/null 2>&1")
	else
		local st = luci.sys.exec("cat " .. run .. "/state 2>/dev/null"):gsub("\n", "")
		if st == "up" then
			luci.sys.call("/etc/init.d/aether disable; /etc/init.d/aether stop >/dev/null 2>&1")
		else
			luci.sys.call("/etc/init.d/aether enable; /etc/init.d/aether start >/dev/null 2>&1")
		end
	end
	luci.http.prepare_content("application/json")
	luci.http.write('{"ok":true}')
end

function act_api_egress()
	local run = "/var/run/aether"
	if luci.http.formvalue("refresh") == "1" then
		luci.sys.exec("[ -e " .. run .. "/egress.lock ] " ..
			"&& [ -z \"$(find " .. run .. "/egress.lock -mmin +1 2>/dev/null)\" ] || " ..
			"(touch " .. run .. "/egress.lock; " ..
			"/usr/share/aether/egress-check.sh; " ..
			"rm -f " .. run .. "/egress.lock >/dev/null 2>&1 &)")
	end
	local f = io.open(run .. "/egress.json")
	luci.http.prepare_content("application/json")
	luci.http.write(f and f:read("*a") or '{"state":"unknown"}')
	if f then f:close() end
end

function act_api_log()
	local run = "/var/run/aether"
	local lines = luci.http.formvalue("lines") or "50"
	local log = luci.sys.exec("tail -" .. lines .. " " .. run .. "/core.log 2>/dev/null")
	luci.http.prepare_content("text/plain")
	luci.http.write(log)
end

function act_api_config()
	local cfi = luci.http.formvalue("cfi") -- change flag identifier
	local cval = luci.http.formvalue("cval") -- change value
	if cfi and cval then
		luci.sys.call(string.format(
			'uci set aether.main.%s="%s" 2>/dev/null && uci commit aether',
			cfi, cval))
		luci.http.prepare_content("application/json")
		luci.http.write('{"ok":true,"changed":"' .. cfi .. '=' .. cval .. '"}')
		return
	end
	-- Read all UCI options
	local opts = {}
	local keys = {"enabled", "scan_mode", "ip_version", "noize", "quick_reconnect",
		"wg_peer", "wiw_outer", "wiw_inner", "wg_keepalive", "bind_address",
		"dns", "vpn_mode", "tun_name", "tun_mtu", "direct_iran",
		"route_direct", "route_block", "routes_file", "http_proxy",
		"http_port", "tls_groups", "validate_secs", "reconnect_secs",
		"no_profile_retry", "route_sniff", "sniffing_timeout_ms",
		"reprovision", "wg_endpoint_cooldown", "perf_profile"}
	for _, k in ipairs(keys) do
		local v = luci.sys.exec('uci -q get aether.main.' .. k .. ' 2>/dev/null'):gsub("\n", "")
		opts[k] = v
	end
	luci.http.prepare_content("application/json")
	luci.http.write(require("json").encode(opts))
end
