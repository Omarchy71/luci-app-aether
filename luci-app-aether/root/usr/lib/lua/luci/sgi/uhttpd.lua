-- Minimal LuCI uhttpd handler for Aether Core
-- Uses io.write() only to avoid circular dependencies
function handle_request()
	local io = io
	local path = luci.http.getenv("PATH_INFO") or "/"
	local method = luci.http.getenv("REQUEST_METHOD") or "GET"

	-- API endpoints
	if path:match("^/api/") then
		io.write("Content-Type: application/json\r\n\r\n")
		if path:match("/api/status$") then
			-- handled by controller
		elseif path:match("/api/connect$") then
			-- handled by controller
		elseif path:match("/api/egress$") then
			-- handled by controller
		elseif path:match("/api/log$") then
			local lines = luci.http.formvalue("lines") or "50"
			local log = luci.sys.exec("tail -" .. lines .. " /var/run/aether/core.log 2>/dev/null")
			io.write(log)
		elseif path:match("/api/config$") then
			io.write("{}")
		else
			io.write('{"error":"unknown api path"}')
		end
		return
	end

	-- Static content for the CBI framework
	io.write("Content-Type: text/html; charset=utf-8\r\n\r\n")
end
