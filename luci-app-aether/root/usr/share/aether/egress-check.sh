#!/bin/sh
# Aether Egress Checker — Deep YouTube connectivity + alternative reconnection
# VPN-aware routing: when VPN is up, checks through VPN; when VPN is down, checks through WAN
# Supports: OpenWrt 24.10.5

AETHER_BIN=/usr/sbin/aether
HEV_BIN=/usr/bin/hev-socks5-tunnel
AETHER_DIR=/usr/share/aether
STATUS_FILE=/var/run/aether/status.json
YOUTUBE_FILE=/var/run/aether/youtube.json
LOG_FILE=/var/log/aether.log

. $AETHER_DIR/setup-lib.sh

config_load aether
load_options

# ─── Determine route path based on VPN state ──
# Returns: empty when VPN is up (default route = VPN), WAN device when VPN is down
is_vpn_up() {
	ip link show "$tun_name" 2>/dev/null | grep -q "UP"
}

get_curl_iface() {
	# If VPN is up, use default route (through VPN)
	# If VPN is down, force curl through WAN interface
	if is_vpn_up; then
		echo ""
	else
		local wan_dev="$(ip route show default 2>/dev/null | grep -v 'dev $tun_name' | head -1 | sed -n 's/.*dev \([^ ]*\).*/\1/p')"
		echo "$wan_dev"
	fi
}

# ─── Build curl command with correct routing ──
build_curl_cmd() {
	local url="$1"
	local timeout="${2:-15}"
	local iface="$(get_curl_iface)"
	local cmd="curl -s --connect-timeout $timeout --max-time $timeout -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)'"
	if [ -n "$iface" ]; then
		cmd="$cmd --interface $iface"
	fi
	cmd="$cmd '$url'"
	echo "$cmd"
}

is_running() {
	pgrep -f "$AETHER_BIN" >/dev/null 2>&1
}

log() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
	echo "$1"
}

# ─── Check if YouTube page actually loads content ──
# VPN-aware routing:
#   - VPN UP → curl uses default route (goes through VPN tunnel)
#   - VPN DOWN → curl uses --interface WAN_DEV (goes through WAN directly)
# Returns: 0=connected, 1=not connected, 2=error
check_youtube_deep() {
	local url="${check_url:-https://www.youtube.com}"
	local timeout="${check_timeout:-15}"

	# Check if aether is running first
	if ! is_running; then
		echo '{"status":"no_core","reachable":false,"detail":"Core not running","timestamp":'$(date +%s)'}' > $YOUTUBE_FILE
		return 2
	fi

	# Determine VPN state
	local vpn_up=0
	if is_vpn_up; then
		vpn_up=1
	fi

	# Build and execute curl with correct routing
	local curl_cmd="$(build_curl_cmd "$url" "$timeout")"
	local result
	result=$(eval "$curl_cmd")

	local curl_exit=$?

	# Determine route info for logging
	local route_info
	if [ "$vpn_up" = "1" ]; then
		route_info="VPN ($tun_name)"
	else
		route_info="WAN (direct)"
	fi

	# Check for actual YouTube content markers
	if echo "$result" | grep -q "ytInitialData\|watch?v=\|YouTube.*premium\|yt-core-web\|ytd-web-control"; then
		local latency_cmd="curl -s -o /dev/null -w '%{time_total}' --connect-timeout $timeout --max-time $timeout -H 'User-Agent: Mozilla/5.0' '$url'"
		if [ -n "$(get_curl_iface)" ]; then
			latency_cmd="$latency_cmd --interface $(get_curl_iface)"
		fi
		local latency=$(eval "$latency_cmd" 2>/dev/null)
		local latency_ms=$(( latency * 1000 ))

		echo '{"status":"connected","reachable":true,"detail":"YouTube page content verified","latency":'"$latency_ms"'ms,"route":"'"$route_info"'","timestamp":'$(date +%s)'}' > $YOUTUBE_FILE
		log "[YouTube] CONNECTED (content verified, ${latency_ms}ms, $route_info)"
		return 0
	elif [ $curl_exit -ne 0 ]; then
		echo '{"status":"error","reachable":false,"detail":"Connection failed (curl exit: '$curl_exit') ['$route_info']","timestamp":'$(date +%s)'}' > $YOUTUBE_FILE
		log "[YouTube] ERROR (curl exit: $curl_exit via $route_info)"
		return 2
	else
		local http_code=$(echo "$result" | head -1 | grep -oP 'HTTP/[0-9.]+ [0-9]+' | awk '{print $2}')
		echo '{"status":"disconnected","reachable":false,"detail":"Not YouTube content (HTTP: '$http_code')","timestamp":'$(date +%s)'}' > $YOUTUBE_FILE
		log "[YouTube] NOT YOUTUBE (HTTP: $http_code)"
		return 1
	fi
}

# ─── Check WAN connectivity (always direct, never via VPN) ──
check_wan_direct() {
	local wan_dev="$(ip route show default 2>/dev/null | grep -v 'dev $tun_name' | head -1 | sed -n 's/.*dev \([^ ]*\).*/\1/p')"
	if [ -z "$wan_dev" ]; then
		echo '{"reachable":false,"reason":"no WAN device"}'
		return 1
	fi

	local result
	result=$(curl -s --connect-timeout 5 --max-time 5 --interface "$wan_dev" "https://www.google.com" 2>/dev/null)
	local curl_exit=$?

	if [ $curl_exit -eq 0 ]; then
		echo '{"reachable":true,"interface":"'"$wan_dev"'"}'
		return 0
	else
		echo '{"reachable":false,"interface":"'"$wan_dev"'","curl_exit":'"$curl_exit"'}'
		return 1
	fi
}

# ─── Alternative reconnection methods ──────────────
reconnect_try1() {
	log "[Reconnect] Method 1: Restart aether core"
	pkill -TERM -f "$AETHER_BIN" 2>/dev/null
	sleep 2
	pkill -KILL -f "$AETHER_BIN" 2>/dev/null
	pkill -TERM -f "$HEV_BIN" 2>/dev/null
	sleep 1
	pkill -KILL -f "$HEV_BIN" 2>/dev/null
	sleep "$reconnect_interval"
	start_service
}

reconnect_try2() {
	log "[Reconnect] Method 2: Toggle noise level"
	local current="$noize"
	case "$current" in
		none) config_set aether main noize "light" ;;
		light) config_set aether main noize "firewall" ;;
		firewall) config_set aether main noize "balanced" ;;
		balanced) config_set aether main noize "gfw" ;;
		gfw) config_set aether main noize "aggressive" ;;
		aggressive) config_set aether main noize "none" ;;
		*) config_set aether main noize "balanced" ;;
	esac
	config_commit aether
	reconnect_try1
}

reconnect_try3() {
	log "[Reconnect] Method 3: Switch protocol"
	local current="$protocol"
	case "$current" in
		gool) config_set aether main protocol "masque" ;;
		masque) config_set aether main protocol "wg" ;;
		wg) config_set aether main protocol "mim" ;;
		mim) config_set aether main protocol "gool" ;;
		*) config_set aether main protocol "gool" ;;
	esac
	config_commit aether
	reconnect_try1
}

reconnect_try4() {
	log "[Reconnect] Method 4: Change DNS and retry"
	case "$dns" in
		1.1.1.1) config_set aether main dns "8.8.8.8" ;;
		8.8.8.8) config_set aether main dns "9.9.9.9" ;;
		*) config_set aether main dns "1.1.1.1" ;;
	esac
	config_commit aether
	reconnect_try1
}

# ─── Main reconnection logic with fallback chain ──
attempt_reconnect() {
	[ "$auto_reconnect" != "1" ] && { echo "[Reconnect] Disabled"; return 1; }
	get_config
	local max_attempts="${max_reconnect_attempts:-0}"
	local attempt=0

	log "[Reconnect] Starting fallback chain..."

	while true; do
		check_youtube_deep
		local yresult=$?
		if [ $yresult -eq 0 ]; then
			log "[Reconnect] YouTube connected! Done."
			return 0
		fi

		if [ "$max_attempts" != "0" ] && [ "$attempt" -ge "$max_attempts" ]; then
			log "[Reconnect] Max attempts ($max_attempts) reached. Need manual intervention."
			echo '{"service":"reconnect","status":"manual","attempt":'"$attempt"'}' > $YOUTUBE_FILE
			return 1
		fi

		attempt=$((attempt+1))
		log "[Reconnect] Attempt $attempt..."

		case $((attempt % 4)) in
			1) reconnect_try1 ;;
			2) reconnect_try2 ;;
			3) reconnect_try3 ;;
			4) reconnect_try4 ;;
		esac

		sleep "$reconnect_interval"
	done
}

# ─── Watchdog ──
watchdog_loop() {
	local interval="${watchdog_interval:-30}"
	log "[Watchdog] Started (interval: ${interval}s)"

	while true; do
		if ! is_running; then
			log "[Watchdog] Core not running! Restarting..."
			start_service &
		fi
		sleep "$interval"
	done
}

# ─── YouTube monitoring loop ──
youtube_loop() {
	get_config
	local interval="${youtube_check_interval:-60}"
	local yc_enabled="$youtube_check"

	[ "$yc_enabled" != "1" ] && return 0

	log "[YouTube Monitor] Started (interval: ${interval}s)"

	while true; do
		check_youtube_deep
		local result=$?

		if [ $result -ne 0 ]; then
			log "[YouTube Monitor] YouTube check FAILED! Trying reconnect..."
			attempt_reconnect &
		fi

		sleep "$interval"
	done
}

# ─── Parse CLI args ──
case "${1:-}" in
	--youtube)
		youtube_loop
		;;
	--watchdog)
		watchdog_loop
		;;
	--reconnect)
		attempt_reconnect
		;;
	--check-once)
		check_youtube_deep
		;;
	--check-wan)
		check_wan_direct
		;;
	*)
		# Default: one-time check
		check_youtube_deep
		;;
esac
