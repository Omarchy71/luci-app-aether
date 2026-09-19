-- Standard LuCI SGI handler for uhttpd with embedded Lua
-- When uhttpd-mod-lua is installed, this handler runs in-process
-- without spawning /usr/bin/lua per request (3-5x faster)
--
-- The actual routing is handled by the controller (luasrc/controller/aether.lua)
-- which is auto-loaded by luci.sgi.http when a request arrives.

-- This file serves as the SGI entry point for uhttpd-mod-lua.
-- It simply loads the standard LuCI HTTP handler which dispatches
-- to the appropriate controller/action.

module("luci.sgi.uhttpd", package.seeall)

function http()
	return require "luci.sgi.http".http()
end

-- The actual request handling is done by:
-- luci.sgi.http → luci.dispatcher → luci.controller.aether
-- No additional routing needed here.
