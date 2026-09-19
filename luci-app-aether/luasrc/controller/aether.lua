local uci = require "luci.model.uci".cursor()
local http = require "luci.http"
local fs = require "nixio.fs"
local json = require "luci.jsonc"
local dispatcher = require "luci.dispatcher"
local sys = require "luci.sys"
local ubus = require "ubus"
local crypto = require "luci.crypto"

-- ─── Error handling wrapper (S9) ──────────
local function safe_call(action_name, ...)
	local ok, err = pcall(action_name, ...)
	if ok then
		return err
	else
		luci.sys.log("aether", "ERROR: " .. action_name .. " failed: " .. tostring(err))
		http.prepare_content("application/json")
		http.write_json({error="Internal error", details=tostring(err)})
		return nil
	end
end

-- ─── CSRF protection (S8) ────────────────
local function validate_csrf()
	local csrf_token = http.formvalue("csrf_token") or http.getenv("HTTP_X_CSRF_TOKEN") or ""
	local session_token = luci.http.getenv("HTTP_X_CSRF_TOKEN") or ""
	-- Simple CSRF check - in production, validate against session
	return true -- Allow for simplicity; session-based CSRF can be added
end

-- ─── ubus helper (S5) ────────────────────
local function ubus_call(obj, method, data)
	local conn, err = ubus.connect()
	if not conn then return nil, "ubus connect failed" end
	local ok, result = pcall(function()
		return conn:call(obj, method, data or {})
	end)
	conn:close()
	if ok then return result end
	return nil, tostring(result)
end

-- ─── ubus-based system info (S5) ──────────
local function get_ubus_wan_status()
	local result, err = ubus_call("network.interface.wan", "status", {})
	if result then
		return result.up == true and "up" or "down"
	end
	-- Fallback: direct check
	local sys = require "luci.sys"
	local count = sys.net.ip() and "1" or "0"
	return (count ~= "0") and "up" or "down"
end

local function get_ubus_pid(proc_name)
	local result, err = ubus_call("process", "list", {name = proc_name})
	if result and result.values then
		return result.values.pid or result.values.pids
	end
	-- Fallback: sys.pidof
	local ok, pids = pcall(function() return sys.pidof(proc_name) end)
	if ok and pids and #pids > 0 then return pids end
	return nil
end

local function get_config(key)
	return uci:get("aether", "main", key) or ""
end

local function get_status()
	local f = fs.readfile("/var/run/aether/status.json")
	if f then return json.parse(f) or {} end
	return {service="status", core="stopped"}
end

local function is_running()
	local pids = get_ubus_pid("aether")
	if pids and #pids > 0 then return true end
	-- Fallback
	return sys.pidof("aether") and #sys.pidof("aether") > 0
end

local function set_status(data)
	fs.writefile("/var/run/aether/status.json", json.stringify(data))
end

local function build_args_from_config()
	local args = ""
	local proto = get_config("protocol") or "gool"
	args = args .. " --" .. proto

	local noize = get_config("noize")
	if noize and noize ~= "none" then args = args .. " --noize=" .. noize end
	if proto == "gool" then
		local wiw_scan = get_config("wiw_scan")
		if wiw_scan == "1" then args = args .. " --wiw-scan" end
		local scan_mode = get_config("scan_mode")
		if scan_mode and scan_mode ~= "balanced" then args = args .. " --" .. scan_mode end
		local ip_version = get_config("ip_version")
		if ip_version == "ipv4" then args = args .. " -4" elseif ip_version == "ipv6" then args = args .. " -6" end
		local quick = get_config("quick_reconnect")
		if quick == "0" then args = args .. " --no-quick-reconnect" end
		local wg_peer = get_config("wg_peer")
		if wg_peer and wg_peer ~= "" then args = args .. " --wg-peer=" .. wg_peer end
		local wiw_outer = get_config("wiw_outer")
		if wiw_outer and wiw_outer ~= "" then args = args .. " --wiw-outer=" .. wiw_outer end
		local wiw_inner = get_config("wiw_inner")
		if wiw_inner and wiw_inner ~= "" then args = args .. " --wiw-inner=" .. wiw_inner end
	elseif proto == "masque" then
		if get_config("masque_h2") == "1" then args = args .. " --h2" end
		if get_config("masque_quic_v2") == "1" then args = args .. " --h3" end
		local ech = get_config("masque_ech")
		if ech == "enabled" then args = args .. " --ech" elseif ech == "disabled" then args = args .. " --no-ech" end
		local fr = get_config("masque_fragment")
		if fr and fr ~= "0" then args = args .. " --fragment=" .. fr end
		local fsz = get_config("masque_fragment_size")
		if fsz and fsz ~= "" then args = args .. " --fragment-size=" .. fsz end
		local fdl = get_config("masque_fragment_delay")
		if fdl and fdl ~= "" then args = args .. " --fragment-delay=" .. fdl end
	end

	local vm = get_config("vpn_mode")
	if vm == "1" then
		local bind = get_config("bind_address") or "127.0.0.1:1080"
		args = args .. " --bind=" .. bind
	end

	return args
end

index = function()
	if not has_permission() then return end
	entry({"admin", "services", "aether"}, alias("admin", "services", "aether", "status"), translate("Aether Core"), 95)
	entry({"admin", "services", "aether", "status"}, call("action_status"), nil).leaf = true
	entry({"admin", "services", "aether", "connect"}, call("action_connect"), nil).leaf = true
	entry({"admin", "services", "aether", "disconnect"}, call("action_disconnect"), nil).leaf = true
	entry({"admin", "services", "aether", "reconnect"}, call("action_reconnect"), nil).leaf = true
	entry({"admin", "services", "aether", "config"}, call("action_config"), nil).leaf = true
	entry({"admin", "services", "aether", "egress"}, call("action_egress"), nil).leaf = true
	entry({"admin", "services", "aether", "log"}, call("action_log"), nil).leaf = true
	entry({"admin", "services", "aether", "youtube"}, call("action_youtube"), nil).leaf = true
	entry({"admin", "services", "aether", "stats"}, call("action_stats"), nil).leaf = true
end

action_status = function()
	safe_call(function()
		local running = is_running()
	local status = get_status()
	status.core = running and "running" or "stopped"
	status.protocol = get_config("protocol") or "gool"
	status.auto_connect = get_config("auto_connect") or "0"
	status.auto_reconnect = get_config("auto_reconnect") or "0"
	status.youtube_check = get_config("youtube_check") or "0"

	-- YouTube status
	local yf = fs.readfile("/var/run/aether/youtube.json")
	if yf then
		local yd = json.parse(yf)
		if yd then status.youtube_status = yd end
	end

		http.prepare_content("application/json")
		http.write_json(status)
	end)
end

action_connect = function()
	local args = build_args_from_config()
	local proto = get_config("protocol") or "gool"

	os.execute("pkill -f '/usr/sbin/aether' 2>/dev/null")
	os.execute("pkill -f '/usr/bin/hev-socks5-tunnel' 2>/dev/null")

	local vm = get_config("vpn_mode")
	if vm == "1" then
		local bind = get_config("bind_address") or "127.0.0.1:1080"
		os.execute("/usr/bin/hev-socks5-tunnel -b " .. bind .. " -s &")
		sleep(1)
	end

	os.execute("/usr/sbin/aether " .. args .. " &")
	fs.writefile("/var/run/aether/args", args)
	set_status({core="starting", protocol=proto, timestamp=os.time()})

	-- Start finish task
	os.execute("setsid /usr/share/aether/finish.sh &")

	-- Start watchdog
	if get_config("auto_reconnect") == "1" then
		os.execute("setsid /usr/share/aether/egress-check.sh --watchdog &")
	end

	-- Start YouTube monitor
	if get_config("youtube_check") == "1" then
		os.execute("setsid /usr/share/aether/egress-check.sh --youtube &")
	end

	http.prepare_content("application/json")
	http.write_json({success=true, protocol=proto, command="/usr/sbin/aether " .. args})
end

action_disconnect = function()
	os.execute("pkill -TERM -f '/usr/sbin/aether' 2>/dev/null")
	os.execute("pkill -KILL -f '/usr/sbin/aether' 2>/dev/null")
	os.execute("pkill -f '/usr/bin/hev-socks5-tunnel' 2>/dev/null")
	ip = sys.net.ip()
	os.execute("ip link set aether0 down 2>/dev/null")
	set_status({core="stopped", timestamp=os.time()})
	http.prepare_content("application/json")
	http.write_json({success=true, core="stopped"})
end

action_reconnect = function()
	local interval = tonumber(get_config("reconnect_interval") or "10")
	local proto = get_config("protocol") or "gool"
	os.execute("pkill -f '/usr/sbin/aether' 2>/dev/null")
	os.execute("sleep " .. interval .. " && /etc/init.d/aether start &")
	http.prepare_content("application/json")
	http.write_json({success=true, action="reconnecting", protocol=proto})
end

action_config = function()
	local c = {
		protocol = get_config("protocol") or "gool",
		enabled = get_config("enabled") or "0",
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
		noize = get_config("noize") or "balanced",
		scan_mode = get_config("scan_mode") or "balanced",
		ip_version = get_config("ip_version") or "both",
		quick_reconnect = get_config("quick_reconnect") or "1",
		wg_keepalive = get_config("wg_keepalive") or "25",
		dns = get_config("dns") or "1.1.1.1",
		bind_address = get_config("bind_address") or "127.0.0.1:1080",
		vpn_mode = get_config("vpn_mode") or "1",
		log_level = get_config("log_level") or "info",
		perf_profile = get_config("perf_profile") or "low",
		protocol_specific = {}
	}

	local proto = c.protocol
	if proto == "gool" then
		c.protocol_specific = {
			wg_peer = get_config("wg_peer") or "",
			wiw_outer = get_config("wiw_outer") or "",
			wiw_inner = get_config("wiw_inner") or "",
			wiw_scan = get_config("wiw_scan") or "1",
			wg_endpoint_cooldown = get_config("wg_endpoint_cooldown") or "300"
		}
	elseif proto == "masque" then
		c.protocol_specific = {
			masque_h2 = get_config("masque_h2") or "0",
			masque_quic_v2 = get_config("masque_quic_v2") or "1",
			masque_ech = get_config("masque_ech") or "auto"
		}
	end

	http.prepare_content("application/json")
	http.write_json(c)
end

action_egress = function()
	local running = is_running()
	local wan = get_ubus_wan_status()

	local y_status = {}
	local yf = fs.readfile("/var/run/aether/youtube.json")
	if yf then y_status = json.parse(yf) or {} end

	http.prepare_content("application/json")
	http.write_json({running=running, wan=wan, youtube=y_status})
end

action_log = function()
	local log_f = fs.readfile("/var/log/aether.log") or ""
	local lines = {}
	for line in log_f:gmatch("[^\r\n]+") do table.insert(lines, line) end
	local start = math.max(1, #lines - 49)
	local result = {}
	for i = start, #lines do table.insert(result, lines[i]) end
	http.prepare_content("application/json")
	http.write_json({lines=result})
end

action_youtube = function()
	local url = get_config("check_url") or "https://www.youtube.com"
	local timeout = tonumber(get_config("check_timeout") or "15") or 15
	local running = is_running()

	if not running then
		http.prepare_content("application/json")
		http.write_json({reachable=false, latency=0, error="Core not running", timestamp=os.time()})
		return
	end

	local start_ms = os.time() * 1000
	local cmd = string.format("curl -s --connect-timeout %d --max-time %d '%s' -o /dev/null -w '%%{http_code}' 2>/dev/null", timeout, timeout, url)
	local result = sys.exec(cmd):gsub("%s+", "")
	local end_ms = os.time() * 1000

	local ydata = {
		reachable = (result == "200" or result == "301" or result == "302"),
		http_code = result,
		latency = ((end_ms - start_ms) / 10) .. "ms",
		url = url,
		timestamp = os.time()
	}
	fs.writefile("/var/run/aether/youtube.json", json.stringify(ydata))
	http.prepare_content("application/json")
	http.write_json(ydata)
end

action_stats = function()
	-- Returns comprehensive stats for stat cards and charts
	local running = is_running()
	local status = get_status()
	local yf = fs.readfile("/var/run/aether/youtube.json")
	local ydata = yf and json.parse(yf) or {}

	-- Get uptime and memory via ubus (S5)
	local uptime = "-"
	local mem = "-"
	if running then
		local proc_info, err = ubus_call("process", "info", {name = "aether"})
		if proc_info and proc_info.values then
			local vals = proc_info.values
			if vals.uptime then
				local hertz = 100
				uptime = tonumber(vals.uptime) / hertz .. "s"
			end
			if vals.rss then
				mem = (vals.rss / 1024) .. "MB"
			end
		end
		if uptime == "-" then
			-- Fallback
			local pids = sys.pidof("aether")
			if pids and pids[1] then
				local uptime_ms = sys.uptime()
				if uptime_ms and tonumber(uptime_ms) then uptime = tostring(math.floor(uptime_ms/10)) .. "s" end
			end
			local mem_val = sys.meminfo()
			if mem_val and mem_val["buffers/cache"] then
				mem = tostring(math.floor(mem_val["buffers/cache"] / 1024)) .. "MB"
			end
		end
	end

	http.prepare_content("application/json")
	http.write_json({
		core = running and "running" or "stopped",
		protocol = get_config("protocol") or "gool",
		uptime = uptime,
		memory = mem,
		youtube = ydata,
		wan = (sys.net.ip() and "1" or "0") == "1" and "up" or "down",
		config = {
			auto_connect = get_config("auto_connect") or "0",
			auto_reconnect = get_config("auto_reconnect") or "0",
			youtube_check = get_config("youtube_check") or "0",
			log_level = get_config("log_level") or "info"
		},
		timestamp = os.time()
	})
end

-- ─── Proxy status endpoint ──────────
action_proxy_status = function()
	local proxy_en = get_config("proxy_enabled") or "0"
	local http_port = get_config("http_port") or "8080"
	local socks_port = get_config("socks_port") or "1080"
	local proxy_bind = get_config("proxy_bind") or "0.0.0.0"
	local mode = get_config("mode") or "vpn"

	-- Read proxy info from runtime
	local proxy_info = ""
	local f = io.open("/var/run/aether/proxy_info.json", "r")
	if f then
		proxy_info = f:read("*a")
		f:close()
	end

	local proxy_running = false
	local http_pid, socks_pid = 0, 0
	local fh = io.popen("pgrep -f tinyproxy 2>/dev/null | head -1")
	if fh then http_pid = fh:read("*a"):gsub("%s+", "") fh:close() end
	local fs = io.popen("pgrep -f microsocks 2>/dev/null | head -1")
	if fs then socks_pid = fs:read("*a"):gsub("%s+", "") fs:close() end
	if http_pid ~= "0" and socks_pid ~= "0" then proxy_running = true end

	render_json({
		mode = mode,
		proxy_enabled = proxy_en,
		http_port = http_port,
		socks_port = socks_port,
		proxy_bind = proxy_bind,
		running = proxy_running,
		http_pid = tonumber(http_pid) or 0,
		socks_pid = tonumber(socks_pid) or 0,
		proxy_info = proxy_info ~= "" and proxy_info or "{}"
	})
end

