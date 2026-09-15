module("luci.controller.aether", package.seeall)

function index()
	entry({"admin", "services", "aether"},
		cbi("aether"), _("Aether"), 60).dependent = true
	entry({"admin", "services", "aether", "status"},
		template("aether/status"), _("Status"), 1).leaf = true
end
