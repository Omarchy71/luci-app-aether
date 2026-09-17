-- LuCI uhttpd dispatcher for Aether Core
-- Minimal handler serving LuCI web interface
function handle_request()
    local io = io
    io.write('Content-Type: text/html; charset=utf-8\r\n\r\n')
    io.write('<html><head><title>LuCI - Aether Core</title>')
    io.write('<style>body{font-family:arial;padding:40px}h1{color:#333}</style>')
    io.write('</head><body>')
    io.write('<h1>LuCI Web Interface</h1>')
    io.write('<p>Aether Core 2.0.0 is running.</p>')
    io.write('<ul>')
    io.write('<li><a href="/cgi-bin/luci/admin/">Administration</a></li>')
    io.write('<li><a href="/cgi-bin/luci/network/">Network</a></li>')
    io.write('<li><a href="/cgi-bin/luci/status/">Status</a></li>')
    io.write('<li><a href="/cgi-bin/luci/system/">System</a></li>')
    io.write('<li><a href="/luci-static/">Static Files</a></li>')
    io.write('</ul>')
    io.write('<p>All interfaces are active.</p>')
    io.write('</body></html>')
end
