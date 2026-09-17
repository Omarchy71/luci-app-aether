module("luci.controller.aether", package.seeall)

function index()
	entry({"admin", "services", "aether"},
		cbi("aether"), _("Aether"), 60).dependent = true
	entry({"admin", "services", "aether", "status"},
		template("aether/status"), _("Status"), 1).leaf = true
	entry({"admin", "services", "aether", "api", "status"},
		call("act_status"), nil).leaf = true
	entry({"admin", "services", "aether", "connect"},
		call("act_connect"), nil).leaf = true
	entry({"admin", "services", "aether", "egress"},
		call("act_egress"), nil).leaf = true
end

function act_status()
	local run = "/var/run/aether"
	local state = luci.sys.exec("cat " .. run .. "/state 2>/dev/null"):gsub("\n", "")
	if state == "" then state = "down" end
	local uptime = luci.sys.exec("cat " .. run .. "/uptime 2>/dev/null"):gsub("\n", "")
	luci.http.prepare_content("application/json")
	luci.http.write(string.format(
		'{"state":"%s","uptime":"%s"}', state, uptime
	))
end

function act_connect()
	local action = luci.http.formvalue("action")
	local run = "/var/run/aether"
	if action == "on" then
		luci.sys.call("/etc/init.d/aether enable; /etc/init.d/aether start >/dev/null 2>&1")
	elseif action == "off" then
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

function act_egress()
	-- Instant: always answer from the cached probe. A real probe runs
	-- in the background only on explicit refresh (or a missing cache),
	-- guarded by a 1-minute lock so clicks can't stampede it.
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
