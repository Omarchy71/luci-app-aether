#!/bin/sh
# Aether Proxy Server — HTTP + SOCKS5 proxy (on/off toggle)
# Supports: OpenWrt 24.10.5

AETHER_DIR=/usr/share/aether
RUN_DIR=/var/run/aether

. $AETHER_DIR/setup-lib.sh

config_load aether
load_options

HTTP_PORT="${http_port:-8080}"
SOCKS_PORT="${socks_port:-1080}"
PROXY_BIND="${proxy_bind:-0.0.0.0}"

# ─── Start proxies ──
start_proxies() {
	# Check deps
	which microsocks >/dev/null 2>&1 || { opkg update && opkg install microsocks 2>/dev/null; }
	which tinyproxy >/dev/null 2>&1 || { opkg update && opkg install tinyproxy 2>/dev/null; }

	# Start HTTP proxy
	mkdir -p /var/run/aether/proxy
	cat > /var/run/aether/proxy/tinyproxy.conf << TCONF
Port $HTTP_PORT
Listen $PROXY_BIND
Allow all
MaxClients 50
Timeout 30
TCONF
	tinyproxy -c /var/run/aether/proxy/tinyproxy.conf -d 2>/dev/null &

	# Start SOCKS5 proxy
	microsocks -i "$PROXY_BIND" -p "$SOCKS_PORT" -u 2>/dev/null &

	sleep 1

	# Get local IP for display
	local ip="$(ip route get 1 2>/dev/null | head -1 | awk '{print $7; exit}')"
	[ -z "$ip" ] && ip="$(ip addr show br-lan 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)"
	[ -z "$ip" ] && ip="0.0.0.0"

	# Save proxy info
	cat > "$RUN_DIR/proxy_info.json" << INFOJSON
{"enabled":true,"ip":"$ip","http_port":$HTTP_PORT,"socks_port":$SOCKS_PORT}
INFOJSON

	echo "[Proxy] Started - HTTP:$HTTP_PORT SOCKS:$SOCKS_PORT on $ip"
}

# ─── Stop proxies ──
stop_proxies() {
	pkill -TERM tinyproxy 2>/dev/null
	pkill -KILL tinyproxy 2>/dev/null
	pkill -TERM microsocks 2>/dev/null
	pkill -KILL microsocks 2>/dev/null
	rm -f /var/run/aether/proxy/tinyproxy.conf 2>/dev/null
	rm -f "$RUN_DIR/proxy_info.json" 2>/dev/null
	echo "[Proxy] Stopped"
}

# ─── Get proxy status ──
get_proxy_status() {
	local http_pid=$(pgrep -f "tinyproxy.*$HTTP_PORT" 2>/dev/null | head -1)
	local socks_pid=$(pgrep -f "microsocks.*$SOCKS_PORT" 2>/dev/null | head -1)
	local http_ok=0 socks_ok=0
	[ -n "$http_pid" ] && http_ok=1
	[ -n "$socks_pid" ] && socks_ok=1

	cat > "$RUN_DIR/proxy_status.json" << STATUSJSON
{"http_running":$http_ok,"socks_running":$socks_ok,"http_pid":${http_pid:-0},"socks_pid":${socks_pid:-0}}
STATUSJSON
}

# ─── Parse args ──
case "${1:-}" in
	start)
		start_proxies
		;;
	stop)
		stop_proxies
		;;
	status)
		get_proxy_status
		cat "$RUN_DIR/proxy_status.json" 2>/dev/null || echo '{"http_running":0,"socks_running":0}'
		;;
	info)
		local ip="$(ip route get 1 2>/dev/null | head -1 | awk '{print $7; exit}')"
		[ -z "$ip" ] && ip="$(ip addr show br-lan 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)"
		[ -z "$ip" ] && ip="0.0.0.0"
		cat "$RUN_DIR/proxy_info.json" 2>/dev/null || echo "{\"enabled\":false,\"ip\":\"$ip\",\"http_port\":$HTTP_PORT,\"socks_port\":$SOCKS_PORT}"
		;;
esac
