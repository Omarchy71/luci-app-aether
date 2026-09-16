#!/bin/sh
# Aether TUN finish task — runs DETACHED (setsid) after start_service
# returns, and is kill-safe via $RUN_DIR/finish.pid (stop_service and the
# next start kill a stale one; the pidfile dies with /var/run on reboot).
#
# Why detached: procd only receives the core instance once start_service
# RETURNS (rc.common sends it in procd_close_service). Any wait longer
# than a second inside start_service therefore deadlocks the service —
# the core would never spawn, and the wait could never succeed. So
# start_service only registers the core and returns; this task waits for
# the core's SOCKS port, then layers hev-socks5-tunnel (TUN) plus the
# WAN/iran routes on top. Verified against this exact failure on EA8300.
. /lib/functions.sh
. /usr/share/aether/setup-lib.sh

echo $$ >"$RUN_DIR/finish.pid"
config_load aether
load_options

# NOTE: this BusyBox nc has no -w1 and exits 0 even on refused
# connections — but prints "can't connect to remote host". So the
# probe waits until that message DISAPPEARS (SOCKS up).
# 1200 tries: a full gool scan + validation took 10+ minutes on this
# link — timing out earlier orphans the core (still running, never
# reaching hev/TUN setup) and wedges the service in state=down.
wait_for "SOCKS $bind_address" 1200 "! (nc $SOCKS_HOST $SOCKS_PORT < /dev/null 2>&1 | grep -q \"can.t connect\")" \
	|| { echo "down" >"$RUN_DIR/state"; rm -f "$RUN_DIR/finish.pid"; exit 1; }

# Bail out quietly if the service was disabled while we were waiting
# (stop already killed the core; nothing left to layer onto).
config_load aether
section_get enabled enabled 0
[ "$enabled" = "1" ] || { rm -f "$RUN_DIR/finish.pid"; exit 0; }
config_load aether
load_options

if [ "$vpn_mode" = "1" ]; then
	[ -x "$PROG_HEV" ] || { log "ERROR: $PROG_HEV missing (opkg install hev-socks5-tunnel)"; echo "down" >"$RUN_DIR/state"; rm -f "$RUN_DIR/finish.pid"; exit 1; }
	gen_hev_conf
	# Register hev with procd WITHOUT disturbing the running core
	# instance (service add merges instances). Fallback: detached hev
	# + pidfile — stop_service kills both forms, so either way the
	# lifecycle stays clean.
	# shellcheck disable=SC2086
	if . /lib/functions/procd.sh 2>/dev/null \
		&& procd_open_service aether /etc/init.d/aether 2>/dev/null; then
		procd_open_instance hev
		procd_set_param command $PROG_HEV "$HEV_CONF"
		procd_set_param respawn 3600 5 5
		procd_close_instance
		if procd_close_service add 2>/dev/null; then
			log "hev registered with procd"
		else
			setsid "$PROG_HEV" "$HEV_CONF" >>"$RUN_DIR/hev.log" 2>&1 < /dev/null &
			echo $! >"$RUN_DIR/hev.pid"
			log "hev started detached (procd add failed)"
		fi
	else
		setsid "$PROG_HEV" "$HEV_CONF" >>"$RUN_DIR/hev.log" 2>&1 < /dev/null &
		echo $! >"$RUN_DIR/hev.pid"
		log "hev started detached (no procd)"
	fi
	wait_for "TUN $tun_name" 15 "ip link show $tun_name" \
		|| { echo "down" >"$RUN_DIR/state"; rm -f "$RUN_DIR/finish.pid"; exit 1; }
	net_up || { echo "down" >"$RUN_DIR/state"; rm -f "$RUN_DIR/finish.pid"; exit 1; }
fi

date -u +%FT%TZ >"$RUN_DIR/uptime"
echo "up" >"$RUN_DIR/state"
# shellcheck disable=SC2154
log "UP (tun=$([ "$vpn_mode" = "1" ] && echo "$tun_name" || echo "proxy-only"))"
rm -f "$RUN_DIR/finish.pid"
