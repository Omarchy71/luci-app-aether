module("luci.controller.aether", package.seeall)

function index()
	entry({"admin", "services", "aether"},
		cbi("aether"), _("Aether"), 60).dependent = true
	entry({"admin", "services", "aether", "status"},
		template("aether/status"), _("Status"), 1).leaf = true
	entry({"admin", "services", "aether", "egress"},
		call("act_egress"), nil).leaf = true
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
