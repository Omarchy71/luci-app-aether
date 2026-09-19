#!/bin/sh
# Aether finish task — self-healing TUN, auto-reconnect on disconnect
# Supports: OpenWrt 24.10.5, Linksys EA8300

AETHER_BIN=/usr/sbin/aether
HEV_BIN=/usr/bin/hev-socks5-tunnel
AETHER_DIR=/usr/share/aether
RECONNECT_FILE=/var/run/aether/reconnect
STATUS_FILE=/var/run/aether/status.json

. $AETHER_DIR/setup-lib.sh

config_load aether
load_options

is_running() {
	pgrep -f "$AETHER_BIN" >/dev/null 2>&1
}

stop_core() {
	pkill -TERM -f "$AETHER_BIN" 2>/dev/null
	sleep 1
	pkill -KILL -f "$AETHER_BIN" 2>/dev/null
	pkill -TERM -f "$HEV_BIN" 2>/dev/null
	sleep 1
	pkill -KILL -f "$HEV_BIN" 2>/dev/null
	ip link set "$tun_name" down 2>/dev/null
}

start_core() {
	# Clean up stale state
	stop_core

	# Wait for WAN
	local wait="${wan_wait:-30}"
	local i=0
	while [ $i -lt "$wait" ]; do
		ip route show default 2>/dev/null | grep -q "default" && break
		sleep 1
		i=$((i+1))
	done

	build_args
	mkdir -p /var/run/aether /var/run/hev

	# Start hev socks5 if vpn_mode=1
	if [ "$vpn_mode" = "1" ]; then
		mkdir -p /var/run/hev
		$HEV_BIN -b "$bind_address" -s &
		sleep 1
	fi

	# Start aether core
	$AETHER_BIN $ARGS &
	echo "$ARGS" > /var/run/aether/args 2>/dev/null
	echo '{"service":"core","status":"started","timestamp":'$(date +%s)'}' > $STATUS_FILE
}

force_reconnect() {
	echo "[finish] Force reconnect triggered"
	echo '{"service":"finish","action":"reconnect","timestamp":'$(date +%s)'}' > $STATUS_FILE
	stop_core
	sleep "$reconnect_interval"
	start_core
}

# ─── self-healing TUN check ───────────────────────
heal_tun() {
	# Check if TUN interface exists and has carrier
	if ! ip link show "$tun_name" 2>/dev/null | grep -q "UP"; then
		echo "[finish] TUN $tun_name is DOWN, healing..."
		force_reconnect
		return
	fi

	# Check if aether is running
	if ! is_running; then
		echo "[finish] Aether not running, restarting..."
		start_core
		return
	fi

	# Check if TUN has IP
	if ! ip addr show "$tun_name" 2>/dev/null | grep -q "inet "; then
		echo "[finish] TUN has no IP, reconnecting..."
		force_reconnect
		return
	fi

	echo "[finish] TUN is healthy (checked at $(date +%s))"
}

# ─── infinite self-healing loop ───────────────────
echo "[finish] Starting self-healing loop..."
while true; do
	heal_tun

	# Check YouTube with deep content verification if configured
	if [ "$youtube_check" = "1" ]; then
		/usr/share/aether/egress-check.sh --check-once >/dev/null 2>&1
		local yresult=$?
		if [ $yresult -ne 0 ]; then
			echo "[finish] YouTube check FAILED! Trying alternative reconnect..."
			/usr/share/aether/egress-check.sh --reconnect >/dev/null 2>&1 &
		fi
	fi

	# Wait before next check
	sleep "${watchdog_interval:-30}"
done
