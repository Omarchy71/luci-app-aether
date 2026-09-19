local uci = require "luci.model.uci".cursor()
local http = require "luci.http"
local fs = require "nixio.fs"
local json = require "luci.jsonc"

-- Read UCI config helper
local function get_config(key)
	return uci:get("aether", "main", key) or ""
end

-- Read status file
local function get_status()
	local f = fs.readfile("/var/run/aether/status.json")
	if f then
		return json.parse(f) or {}
	end
	return {service="status", core="stopped"}
end

-- Check if aether is running
local function is_running()
	return fs.access("/var/run/aether/core.pid") or fs.access("/proc/$(pgrep -f /usr/sbin/aether)")
end

local function set_status(data)
	fs.writefile("/var/run/aether/status.json", json.stringify(data))
end

index = function()
	if not has_permission() then return end
	entry({"admin", "services", "aether"}, alias("admin", "services", "aether", "status"), translate("Aether Core"), 95)
	entry({"admin", "services", "aether", "status"}, call("action_status"), nil).leaf = true
	entry({"admin", "services", "aether", "connect"}, call("action_connect"), nil).leaf = true
	entry({"admin", "services", "aether", "disconnect"}, call("action_disconnect"), nil).leaf = true
	entry({"admin", "services", "aether", "config"}, call("action_config"), nil).leaf = true
	entry({"admin", "services", "aether", "egress"}, call("action_egress"), nil).leaf = true
	entry({"admin", "services", "aether", "log"}, call("action_log"), nil).leaf = true
	entry({"admin", "services", "aether", "youtube"}, call("action_youtube"), nil).leaf = true
	entry({"admin", "services", "aether", "reconnect"}, call("action_reconnect"), nil).leaf = true
end

action_status = function()
	local status = get_status()
	local running = is_running()

	status.core = running and "running" or "stopped"
	status.protocol = get_config("protocol") or "gool"
	status.auto_connect = get_config("auto_connect") or "0"
	status.auto_reconnect = get_config("auto_reconnect") or "0"
	status.youtube_check = get_config("youtube_check") or "0"
	status.youtube_status = ""

	-- Check YouTube status if enabled
	local yc = get_config("youtube_check")
	if yc == "1" then
		local yf = fs.readfile("/var/run/aether/youtube.json")
		if yf then
			local yd = json.parse(yf)
			if yd then status.youtube_status = yd end
		end
	end

	http.prepare_content("application/json")
	http.write_json(status)
end

action_connect = function()
	local proto = get_config("protocol") or "gool"
	local args = get_config("args") or ""

	-- Build args from UCI config
	local cmd = "/usr/sbin/aether --" .. proto

	-- Add noize
	local noize = get_config("noize")
	if noize and noize ~= "none" then
		cmd = cmd .. " --noize=" .. noize
	end

	-- Add other protocol-specific flags
	if proto == "gool" then
		local wiw_scan = get_config("wiw_scan")
		if wiw_scan == "1" then cmd = cmd .. " --wiw-scan" end
		local wg_peer = get_config("wg_peer")
		if wg_peer and wg_peer ~= "" then cmd = cmd .. " --wg-peer=" .. wg_peer end
		local wiw_outer = get_config("wiw_outer")
		if wiw_outer and wiw_outer ~= "" then cmd = cmd .. " --wiw-outer=" .. wiw_outer end
		local wiw_inner = get_config("wiw_inner")
		if wiw_inner and wiw_inner ~= "" then cmd = cmd .. " --wiw-inner=" .. wiw_inner end
		local scan_mode = get_config("scan_mode")
		if scan_mode and scan_mode ~= "balanced" then cmd = cmd .. " --" .. scan_mode end
		local ip_version = get_config("ip_version")
		if ip_version == "ipv4" then cmd = cmd .. " -4" elseif ip_version == "ipv6" then cmd = cmd .. " -6" end
		local quick_reconnect = get_config("quick_reconnect")
		if quick_reconnect == "0" then cmd = cmd .. " --no-quick-reconnect" end
	elseif proto == "masque" then
		if get_config("masque_h2") == "1" then cmd = cmd .. " --h2" end
		if get_config("masque_quic_v2") == "1" then cmd = cmd .. " --h3" end
		local ech = get_config("masque_ech")
		if ech == "enabled" then cmd = cmd .. " --ech" elseif ech == "disabled" then cmd = cmd .. " --no-ech" end
		local fr = get_config("masque_fragment")
		if fr and fr ~= "0" then cmd = cmd .. " --fragment=" .. fr end
		local fsz = get_config("masque_fragment_size")
		if fsz and fsz ~= "" then cmd = cmd .. " --fragment-size=" .. fsz end
		local fdl = get_config("masque_fragment_delay")
		if fdl and fdl ~= "" then cmd = cmd .. " --fragment-delay=" .. fdl end
		local tls = get_config("tls_groups")
		if tls and tls ~= "" then cmd = cmd .. " --tls-groups=" .. tls end
		local hs = get_config("masque_h2_peer")
		if hs and hs ~= "" then cmd = cmd .. " --h2-peer=" .. hs end
	end

	-- Kill existing
	os.execute("pkill -f '/usr/sbin/aether' 2>/dev/null")
	os.execute("pkill -f '/usr/bin/hev-socks5-tunnel' 2>/dev/null")

	-- Start hev socks5 if vpn_mode=1
	local vm = get_config("vpn_mode")
	if vm == "1" then
		os.execute("/usr/bin/hev-socks5-tunnel -b " .. (get_config("bind_address") or "127.0.0.1:1080") .. " -s &")
	end

	-- Start aether core
	os.execute(cmd .. " &")

	-- Start finish task
	os.execute("setsid /usr/share/aether/finish.sh &")

	-- Write status
	set_status({core="starting", protocol=proto, timestamp=os.time()})

	http.prepare_content("application/json")
	http.write_json({success=true, protocol=proto, command=cmd})
end

action_disconnect = function()
	os.execute("pkill -f '/usr/sbin/aether' 2>/dev/null")
	os.execute("pkill -f '/usr/bin/hev-socks5-tunnel' 2>/dev/null")
	os.execute("ip link set aether0 down 2>/dev/null")
	set_status({core="stopped", timestamp=os.time()})
	http.prepare_content("application/json")
	http.write_json({success=true, core="stopped"})
end

action_config = function()
	local c = {
		protocol = get_config("protocol") or "gool",
		enabled = get_config("enabled") or "0",
		scan_mode = get_config("scan_mode") or "balanced",
		ip_version = get_config("ip_version") or "both",
		noize = get_config("noize") or "balanced",
		auto_connect = get_config("auto_connect") or "1",
		auto_reconnect = get_config("auto_reconnect") or "1",
		reconnect_interval = get_config("reconnect_interval") or "10",
		max_reconnect_attempts = get_config("max_reconnect_attempts") or "0",
		watchdog_interval = get_config("watchdog_interval") or "30",
		youtube_check = get_config("youtube_check") or "1",
		youtube_check_interval = get_config("youtube_check_interval") or "60",
		check_url = get_config("check_url") or "https://www.youtube.com",
		check_timeout = get_config("check_timeout") or "15",
		wan_wait = get_config("wan_wait") or "30",
		tun_name = get_config("tun_name") or "aether0",
		tun_mtu = get_config("tun_mtu") or "1420",
		direct_iran = get_config("direct_iran") or "1",
		http_proxy = get_config("http_proxy") or "0",
		http_port = get_config("http_port") or "1820",
		dns = get_config("dns") or "1.1.1.1",
		wg_keepalive = get_config("wg_keepalive") or "25",
		log_level = get_config("log_level") or "info",
		perf_profile = get_config("perf_profile") or "low",
		protocol_specific = {}
	}

	-- Protocol-specific
	local proto = c.protocol
	if proto == "gool" then
		c.protocol_specific = {
			wg_peer = get_config("wg_peer") or "",
			wiw_outer = get_config("wiw_outer") or "",
			wiw_inner = get_config("wiw_inner") or "",
			wiw_scan = get_config("wiw_scan") or "1",
			wg_endpoint_cooldown = get_config("wg_endpoint_cooldown") or "300",
			wg_stale_secs = get_config("wg_stale_secs") or "10"
		}
	elseif proto == "masque" then
		c.protocol_specific = {
			masque_h2 = get_config("masque_h2") or "0",
			masque_quic_v2 = get_config("masque_quic_v2") or "1",
			masque_ech = get_config("masque_ech") or "auto",
			masque_fragment = get_config("masque_fragment") or "0",
			masque_fragment_size = get_config("masque_fragment_size") or "",
			masque_fragment_delay = get_config("masque_fragment_delay") or "",
			tls_groups = get_config("tls_groups") or "",
			masque_h2_peer = get_config("masque_h2_peer") or "",
			startup_secs = get_config("startup_secs") or "30",
			masque_h2_keepalive_secs = get_config("masque_h2_keepalive_secs") or "15"
		}
	end

	http.prepare_content("application/json")
	http.write_json(c)
end

action_egress = function()
	local running = is_running()
	local status = get_status()

	-- Check WAN
	local wan_up = false
	local wan_f = io.popen("ip route show default 2>/dev/null")
	local wan_line = wan_f:read("*a")
	wan_f:close()
	if wan_line and wan_line ~= "" then wan_up = true end

	-- Check YouTube
	local y_status = ""
	local yf = fs.readfile("/var/run/aether/youtube.json")
	if yf then
		local yd = json.parse(yf)
		if yd then y_status = yd end
	end

	http.prepare_content("application/json")
	http.write_json({
		running = running,
		wan = wan_up and "up" or "down",
		youtube = y_status,
		core = status.core or "stopped"
	})
end

action_log = function()
	local log_f = fs.readfile("/var/log/aether.log") or ""
	local last_100 = {}
	for line in log_f:gmatch("[^\r\n]+") do
		table.insert(last_100, line)
	end
	-- Return last 50 lines
	local start = math.max(1, #last_100 - 49)
	local result = {}
	for i = start, #last_100 do
		table.insert(result, last_100[i])
	end
	http.prepare_content("application/json")
	http.write_json({lines=result})
end

-- NEW: YouTube connectivity check
action_youtube = function()
	local check_url = get_config("check_url") or "https://www.youtube.com"
	local timeout = tonumber(get_config("check_timeout") or "15") or 15
	local running = is_running()

	if not running then
		http.prepare_content("application/json")
		http.write_json({reachable=false, latency=0, error="Core not running", timestamp=os.time()})
		return
	end

	local start_ms = os.time() * 1000
	local cmd = string.format("curl -s --connect-timeout %d --max-time %d '%s' -o /dev/null -w '%%{http_code}' 2>/dev/null", timeout, timeout, check_url)
	local f = io.popen(cmd)
	local result = f:read("*a"):gsub("%s+", "")
	f:close()

	local end_ms = os.time() * 1000
	local latency = end_ms - start_ms

	local ydata = {
		reachable = (result == "200" or result == "301" or result == "302"),
		http_code = result,
		latency = latency .. "ms",
		url = check_url,
		timestamp = os.time()
	}

	-- Save for status page
	fs.writefile("/var/run/aether/youtube.json", json.stringify(ydata))

	http.prepare_content("application/json")
	http.write_json(ydata)
end

-- NEW: Manual reconnect
action_reconnect = function()
	os.execute("pkill -f '/usr/sbin/aether' 2>/dev/null")
	os.execute("pkill -f '/usr/bin/hev-socks5-tunnel' 2>/dev/null")
	os.execute("sleep " .. (get_config("reconnect_interval") or "10"))

	local proto = get_config("protocol") or "gool"
	-- Trigger start
	os.execute("/etc/init.d/aether start &")

	http.prepare_content("application/json")
	http.write_json({success=true, action="reconnecting", protocol=proto})
end
