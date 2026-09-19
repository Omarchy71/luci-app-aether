#!/bin/sh
# luci-app-aether shared setup logic (from-scratch redesign).
# Sourced by /etc/init.d/aether AND by the detached finish task
# (/usr/share/aether/finish.sh). Source /lib/functions.sh first so
# config_load/config_get exist.

PROG_AETHER=/usr/sbin/aether
PROG_HEV=/usr/bin/hev-socks5-tunnel
SHARE_DIR=/usr/share/aether
RUN_DIR=/var/run/aether
ROUTES_OUT=$RUN_DIR/routes.txt
HEV_CONF=$RUN_DIR/hev.yml
NET_ENV=$RUN_DIR/net.env
FINISH_PID=$RUN_DIR/finish.pid
HEV_PID=$RUN_DIR/hev.pid
FWMARK=0x9e
TUN_IPV4=198.18.0.1
IR_DOMAINS="private,digikala.com,aparat.com,filimo.com,telewebion.com,varzesh3.com,snapp.ir,cafebazaar.ir,divar.ir,namava.ir,shad.ir"
log() { logger -t aether "$*"; echo "[$(date +%T)] $*" >>"$RUN_DIR/setup.log"; }

valid_endpoint() {
	case "$1" in
		*]:*|*:*) return 0 ;;
		*) return 1 ;;
	esac
}

section_get() { local _tmp; config_get _tmp "main" "$1" 2>/dev/null; export "$1=$_tmp"; }

load_options() {
	for o in enabled scan_mode ip_version noize quick_reconnect \
		wg_peer wiw_outer wiw_inner wg_keepalive wiw_scan \
		wg_endpoint_cooldown wg_stale_secs \
		bind_address dns vpn_mode tun_name tun_mtu direct_iran \
		route_direct route_block routes_file http_proxy http_port \
		tls_groups validate_secs reconnect_secs no_profile_retry \
		route_sniff sniffing_timeout_ms reprovision \
		masque_h2 masque_quic_v2 masque_ech masque_fragment \
		masque_fragment_size masque_fragment_delay masque_h2_peer \
		masque_no_data_check startup_secs masque_h2_keepalive_secs \
		mim_outer mim_inner \
		tor tor_bind tor_dir tor_bridges tor_pt \
		upstream_proxy netstack_tcp_rx netstack_tcp_tx \
		max_clients team access_id access_secret access_token \
		access_email gateway log_level verbose perf_profile \
		protocol auto_connect auto_reconnect reconnect_interval \
		max_reconnect_attempts watchdog_interval wan_wait youtube_check \
		youtube_check_interval check_url check_timeout; do
		section_get "$o" "main"
	done
	[ -n "$tun_name" ] || tun_name="aether0"
	[ -n "$bind_address" ] || bind_address="127.0.0.1:1080"
	SOCKS_HOST="${bind_address%:*}"
	SOCKS_PORT="${bind_address##*:}"
	[ -n "$SOCKS_HOST" ] || SOCKS_HOST="127.0.0.1"
	[ -n "$SOCKS_PORT" ] || SOCKS_PORT="1080"
	# Defaults for new options
	[ -n "$http_port" ] || http_port="1820"
	[ -n "$validate_secs" ] || validate_secs="10"
	[ -n "$reconnect_secs" ] || reconnect_secs="2"
	[ -n "$sniffing_timeout_ms" ] || sniffing_timeout_ms="400"
	[ -n "$wg_endpoint_cooldown" ] || wg_endpoint_cooldown="300"
	[ "$direct_iran" = "1" ] || direct_iran="0"
	[ "$quick_reconnect" = "1" ] || quick_reconnect="0"
	[ "$no_profile_retry" = "1" ] || no_profile_retry="0"
	[ "$route_sniff" = "1" ] || route_sniff="0"
	[ "$reprovision" = "1" ] || reprovision="0"
}

# ─── Protocol-specific arg builders ────────────
build_gool_args() {
	add "--gool"
	local scan_mode="$scan_mode"
	[ "$scan_mode" = "balanced" ] || add "--$scan_mode"
	[ "$ip_version" = "both" ] || { [ "$ip_version" = "ipv4" ] && add "-4" || [ "$ip_version" = "ipv6" ] && add "-6"; }
	[ "$quick_reconnect" = "1" ] && add "--quick-reconnect" || add "--no-quick-reconnect"
	[ "$noize" != "none" ] && add "--noize=$noize"
	[ "$wiw_scan" = "1" ] && add "--wiw-scan"
	[ -n "$wg_peer" ] && add "--wg-peer=$wg_peer"
	[ -n "$wiw_outer" ] && add "--wiw-outer=$wiw_outer"
	[ -n "$wiw_inner" ] && add "--wiw-inner=$wiw_inner"
}

build_masque_args() {
	add "--masque"
	[ "$masque_h2" = "1" ] && add "--h2" || add "--no-h2"
	[ "$masque_quic_v2" = "1" ] && add "--h3"
	case "$masque_ech" in
		enabled) add "--ech" ;;
		disabled) add "--no-ech" ;;
	esac
	[ -n "$masque_fragment" ] && [ "$masque_fragment" != "0" ] && add "--fragment=$masque_fragment"
	[ -n "$masque_fragment_size" ] && add "--fragment-size=$masque_fragment_size"
	[ -n "$masque_fragment_delay" ] && add "--fragment-delay=$masque_fragment_delay"
	[ -n "$tls_groups" ] && add "--tls-groups=$tls_groups"
	[ -n "$masque_h2_peer" ] && add "--h2-peer=$masque_h2_peer"
	[ "$masque_no_data_check" = "1" ] && add "--no-data-check"
}

build_wg_args() {
	add "--wg"
	[ -n "$wg_peer" ] && add "--wg-peer=$wg_peer"
	[ "$wg_keepalive" != "25" ] && add "--keepalive=$wg_keepalive"
	[ "$no_profile_retry" = "1" ] && add "--no-profile-retry"
}

build_mim_args() {
	add "--mim"
	[ -n "$mim_outer" ] && add "--mim-outer=$mim_outer"
	[ -n "$mim_inner" ] && add "--mim-inner=$mim_inner"
}

# ─── Main build_args dispatcher ────────────────# ─── Global arg builders ──────────────────
add() { ARGS="$ARGS $1"; }
add2() { ARGS="$ARGS $1 $2"; }


build_args() {
	ARGS=""

	# Protocol selector
	case "$protocol" in
		masque) build_masque_args ;;
		wg|wireguard) build_wg_args ;;
		mim) build_mim_args ;;
		*) build_gool_args ;;
	esac

	# Common flags
	[ -n "$bind_address" ] && add "--bind=$bind_address"
	[ -n "$dns" ] && add "--dns=$dns"
	[ "$direct_iran" = "1" ] && add "--route-direct"
	[ -n "$route_direct" ] && add "--route=$route_direct"
	[ -n "$route_block" ] && add "--route-block=$route_block"
	[ -n "$routes_file" ] && add "--routes=$routes_file"
	[ "$http_proxy" = "1" ] && add "--http-proxy --http-port=$http_port"
	[ -n "$upstream_proxy" ] && add "--upstream-proxy=$upstream_proxy"
	[ "$vpn_mode" = "1" ] || add "--no-tun"
	[ "$no_profile_retry" = "1" ] && add "--no-profile-retry"
	[ "$reprovision" = "1" ] && add "--reprovision"
	[ "$route_sniff" = "1" ] && add "--route-sniff=$sniffing_timeout_ms"
	[ "$startup_secs" != "30" ] && add "--startup-deadline=$startup_secs"
	[ "$perf_profile" = "medium" ] && add "--turbo"
	[ "$perf_profile" = "high" ] && add "--thorough"
	add "--mark=$FWMARK"

	# Log
	log "Built args: $ARGS"
}

build_args() {
	ARGS=""

	# ─── Protocol selector ──────────────────────────────
	case "$protocol" in
		masque) add "--masque" ;;
		wg|wireguard) add "--wg" ;;
		mim) add "--mim" ;;
		*) add "--gool" ;;  # Default: gool (WG-in-WARP)
	esac

	# ─── Common flags (all protocols) ────────────────────

	# Scan mode (not for masque/mim which have different scanning)
	case "$scan_mode" in
		turbo) add "--turbo" ;;
		thorough) add "--thorough" ;;
		stealth) add "--stealth" ;;
		ironclad) add "--ironclad" ;;
		*) add "--balanced" ;;
	esac

	# IP version
	case "$ip_version" in
		v4) add "-4" ;;
		v6) add "-6" ;;
		*) add "--dual" ;;
	esac

	# Quick reconnect
	if [ "$quick_reconnect" = "1" ]; then add "--quick-reconnect";
	else add "--no-quick-reconnect"; fi

	# --bind must reach the core
	[ -n "$bind_address" ] && add2 "--bind" "$bind_address"

	# DNS through tunnel
	[ -n "$dns" ] && add2 "--dns" "$dns"

	# HTTP CONNECT proxy (optional)
	if [ -n "$http_proxy" ] && [ "$http_proxy" = "1" ]; then
		add2 "--http-proxy" "$SOCKS_HOST:$http_port"
	fi

	# Upstream proxy
	[ -n "$upstream_proxy" ] && add2 "--upstream" "$upstream_proxy"
	[ -n "$upstream_proxy" ] && [ "$upstream_proxy" = "http://"* ] && add "--h2"

	# Route sniffing
	[ "$route_sniff" = "0" ] && add "--route-sniff" "0"
	add2 "--route-sniff-ms" "$sniffing_timeout_ms"

	# Validate/reconnect secs
	add2 "--validate-secs" "$validate_secs"
	add2 "--reconnect-secs" "$reconnect_secs"

	# No profile retry
	[ "$no_profile_retry" = "1" ] && add "--no-profile-retry"

	# Reprovision
	[ "$reprovision" = "1" ] && add "--reprovision"

	# Firewall mark for loop avoidance
	add2 "--mark" "$FWMARK"

	# Perf profile
	[ -n "$perf_profile" ] && add2 "--perf" "$perf_profile"

	# Log level
	[ -n "$log_level" ] && add2 "--log-level" "$log_level"
	[ "$verbose" = "1" ] && add "--verbose"

	# ─── Protocol-specific flags ─────────────────────────
	case "$protocol" in

		# ═══════════════════════════════════════════════
		# GOOL (WG-in-WARP) — WG-family flags
		# ═══════════════════════════════════════════════
		gool)
			# Noize/obfuscation (WG-family)
			case "$noize" in
				none|light|firewall|balanced|gfw|aggressive|off) add2 "--noize" "$noize" ;;
				*) add2 "--noize" "balanced" ;;
			esac

			# Endpoint pinning
			valid_endpoint "$wg_peer" && add2 "--wg-peer" "$wg_peer"
			valid_endpoint "$wiw_outer" && add2 "--wiw-outer" "$wiw_outer"
			valid_endpoint "$wiw_inner" && add2 "--wiw-inner" "$wiw_inner"
			[ "$wiw_scan" = "1" ] && ! valid_endpoint "$wiw_outer" && add "--wiw-scan"
			case "$wg_keepalive" in ''|*[!0-9]*) ;;
				*) add2 "--keepalive" "$wg_keepalive" ;;
			esac
			add2 "--wg-endpoint-cooldown-secs" "$wg_endpoint_cooldown"
			add2 "--wg-stale-secs" "$wg_stale_secs"
			;;

		# ═══════════════════════════════════════════════
		# MASQUE (HTTP/3 QUIC / HTTP/2 TLS)
		# ═══════════════════════════════════════════════
		masque)
			# Transport: HTTP/2 or HTTP/3
			if [ "$masque_h2" = "1" ]; then add "--h2";
			else add "--h3"; fi
			[ "$masque_quic_v2" = "0" ] && add "--no-quic-v2"

			# ECH
			[ -n "$masque_ech" ] && add2 "--ech" "$masque_ech"

			# TLS key share groups
			[ -n "$tls_groups" ] && add2 "--tls-groups" "$tls_groups"

			# Fragment TLS ClientHello
			[ "$masque_fragment" = "1" ] && add "--fragment"
			[ -n "$masque_fragment_size" ] && add2 "--fragment-size" "$masque_fragment_size"
			[ -n "$masque_fragment_delay" ] && add2 "--fragment-delay" "$masque_fragment_delay"

			# HTTP/2 peer override
			[ -n "$masque_h2_peer" ] && add2 "--h2-peer" "$masque_h2_peer"

			# Data-plane validation
			[ "$masque_no_data_check" = "1" ] && add "--no-data-check"

			# Startup/reconnect timing
			add2 "--startup-secs" "$startup_secs"
			add2 "--reconnect-secs" "$reconnect_secs"

			# HTTP/2 keepalive
			add2 "--h2-keepalive-secs" "$masque_h2_keepalive_secs"
			;;

		# ═══════════════════════════════════════════════
		# WIREGUARD (classic WG)
		# ═══════════════════════════════════════════════
		wg|wireguard)
			# Noize is not applicable for pure WG
			# Peer pinning
			valid_endpoint "$wg_peer" && add2 "--peer" "$wg_peer"
			case "$wg_keepalive" in ''|*[!0-9]*) ;;
				*) add2 "--keepalive" "$wg_keepalive" ;;
			esac
			[ "$no_profile_retry" = "1" ] && add "--no-profile-retry"
			add2 "--wg-endpoint-cooldown-secs" "$wg_endpoint_cooldown"
			add2 "--wg-stale-secs" "$wg_stale_secs"
			;;

		# ═══════════════════════════════════════════════
		# MIM (MASQUE-in-MASQUE)
		# ═══════════════════════════════════════════════
		mim)
			# Endpoint pinning for MASQUE-in-MASQUE
			valid_endpoint "$mim_outer" && add2 "--mim-outer" "$mim_outer"
			valid_endpoint "$mim_inner" && add2 "--mim-inner" "$mim_inner"
			# Noize applies to inner MASQUE hop
			case "$noize" in
				none|light|firewall|balanced|gfw|aggressive|off) add2 "--noize" "$noize" ;;
				*) add2 "--noize" "balanced" ;;
			esac
			# HTTP/2 or HTTP/3 for both hops
			if [ "$masque_h2" = "1" ]; then add "--h2";
			else add "--h3"; fi
			add2 "--startup-secs" "$startup_secs"
			;;
	esac

	# ─── Routing (applies to all protocols) ──────────────
	if [ -n "$route_block" ]; then
		add2 "--route-block" "$(echo "$route_block" | tr '\n' ',' | tr -s ',')"
	fi
	USER_DIRECT=""
	if [ -n "$route_direct" ]; then
		USER_DIRECT="$(echo "$route_direct" | tr '\n' ',' | tr -s ',' | sed 's/^,//;s/,$//')"
	fi
	if [ -n "$routes_file" ]; then
		add2 "--routes" "$routes_file"
		[ -n "$USER_DIRECT" ] && add2 "--route-direct" "$USER_DIRECT"
		[ "$direct_iran" = "1" ] && log "custom rules file set — Iran preset skipped"
	elif [ "$direct_iran" = "1" ]; then
		gen_routes_file
		add2 "--routes" "$ROUTES_OUT"
		[ -n "$USER_DIRECT" ] && add2 "--route-direct" "$USER_DIRECT"
	elif [ -n "$USER_DIRECT" ]; then
		add2 "--route-direct" "$USER_DIRECT"
	fi

	# ─── Tor (optional, protocol-specific) ───────────────
	case "$protocol" in
		masque)
			[ "$tor" = "1" ] && add "--tor-reverse"
			[ -n "$tor_bridges" ] && add2 "--tor-bridges" "$tor_bridges"
			[ -n "$tor_pt" ] && add2 "--tor-pt" "$tor_pt"
			[ -n "$tor_dir" ] && add2 "--tor-dir" "$tor_dir"
			;;
		gool)
			[ "$tor" = "1" ] && add "--tor"
			[ -n "$tor_bind" ] && add2 "--tor-bind" "$tor_bind"
			[ -n "$tor_dir" ] && add2 "--tor-dir" "$tor_dir"
			;;
	esac

	# ─── Additional resources ────────────────────────────
	[ -n "$netstack_tcp_rx" ] && add2 "--netstack-tcp-rx" "$netstack_tcp_rx"
	[ -n "$netstack_tcp_tx" ] && add2 "--netstack-tcp-tx" "$netstack_tcp_tx"
	[ -n "$max_clients" ] && add2 "--max-clients" "$max_clients"

	# ─── Cloudflare Zero Trust (optional) ────────────────
	[ -n "$team" ] && add2 "--team" "$team"
	[ -n "$access_id" ] && add2 "--access-id" "$access_id"
	[ -n "$access_secret" ] && add2 "--access-secret" "$access_secret"
	[ -n "$access_token" ] && add2 "--access-token" "$access_token"
	[ -n "$access_email" ] && add2 "--access-email" "$access_email"
	[ "$gateway" = "1" ] && add "--gateway"

	echo "$ARGS" >"$RUN_DIR/args"
}

gen_routes_file() {
	{
		echo "[direct]"
		[ -n "$USER_DIRECT" ] && echo "$USER_DIRECT" | tr ',' '\n'
		echo "$IR_DOMAINS" | tr ',' '\n'
		cat "$SHARE_DIR/iran-v4.txt" "$SHARE_DIR/iran-v6.txt" 2>/dev/null
	} >"$ROUTES_OUT"
	log "routes file: $(wc -l <"$ROUTES_OUT") lines"
}

gen_hev_conf() {
	case "$tun_mtu" in ''|*[!0-9]*) tun_mtu=1420 ;; esac
	[ "$tun_mtu" -lt 1280 ] && tun_mtu=1280
	[ "$tun_mtu" -gt 9000 ] && tun_mtu=9000
	cat >"$HEV_CONF" <<EOF
# Generated by luci-app-aether — do not edit (regenerated per start).
tunnel:
  name: $tun_name
  mtu: $tun_mtu
  multi-queue: false
  ipv4: $TUN_IPV4
socks5:
  address: $SOCKS_HOST
  port: $SOCKS_PORT
  udp: 'udp'
  mark: $FWMARK
misc:
  log-file: '$RUN_DIR/hev.log'
  log-level: warn
  task-stack-size: 86016
EOF
}

wait_for() {
	i=0
	while ! sh -c "$3" >/dev/null 2>&1; do
		i=$((i + 1))
		if [ "$i" -ge "$2" ]; then
			log "ERROR: $1 not ready"
			return 1
		fi
		sleep 1
	done
	return 0
}

net_up() {
	WAN_GW="$(ip route show default | grep -v "dev $tun_name" | head -1 | sed -n 's/.*via \([0-9.]*\).*/\1/p')"
	WAN_DEV="$(ip route show default | grep -v "dev $tun_name" | head -1 | sed -n 's/.*dev \([^ ]*\).*/\1/p')"
	[ -n "$WAN_GW" ] || { log "ERROR: no WAN gateway found"; return 1; }
	echo "WAN_GW=$WAN_GW" >"$NET_ENV"
	echo "WAN_DEV=$WAN_DEV" >>"$NET_ENV"

	ip rule show | grep -q "fwmark $FWMARK" \
		|| ip rule add fwmark "$FWMARK" table main priority 100 2>/dev/null

	ip route replace default via "$WAN_GW" dev "$WAN_DEV" table 100
	ip rule show | grep -q "fwmark $FWMARK.*table 100" \
		|| ip rule add fwmark "$FWMARK" table 100 priority 50 2>/dev/null

	# Iran prefixes direct via WAN
	: >"$RUN_DIR/iran.applied"
	if [ "$direct_iran" = "1" ] && [ -z "$routes_file" ]; then
		for f in "$SHARE_DIR/iran-v4.txt" "$SHARE_DIR/iran-v6.txt"; do
			while read -r pfx; do
				case "$pfx" in ''|\#*) continue ;; esac
				if ip route add "$pfx" via "$WAN_GW" dev "$WAN_DEV" 2>/dev/null; then
					echo "$pfx" >>"$RUN_DIR/iran.applied"
				fi
			done <"$f"
		done
		log "iran direct routes: $(wc -l <"$RUN_DIR/iran.applied") via $WAN_GW"
	fi

	# TUN default (metric 5) must beat WAN metric
	WAN_METRIC="$(ip route show default | grep -v "dev $tun_name" | head -1 | sed -n 's/.*metric \([0-9]*\).*/\1/p')"
	[ -n "$WAN_METRIC" ] || WAN_METRIC=0
	if [ "$WAN_METRIC" -lt 5 ]; then
		while ip route show default | grep -qF "via $WAN_GW dev $WAN_DEV"; do
			ip route del default via "$WAN_GW" dev "$WAN_DEV" 2>/dev/null || break
		done
		ip route add default via "$WAN_GW" dev "$WAN_DEV" metric 10
		log "WAN default metric $WAN_METRIC -> 10 so TUN wins"
	fi

	if ! ip route show default | grep -q "dev $tun_name"; then
		ip route add default dev "$tun_name" metric 5 \
			|| ip route replace default dev "$tun_name" metric 5
	fi
	log "default via $tun_name (metric 5); WAN kept as fallback"
}
