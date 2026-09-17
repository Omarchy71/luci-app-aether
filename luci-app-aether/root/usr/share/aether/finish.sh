#!/bin/sh
# Aether TUN finish task — runs DETACHED (setsid) after start_service.
# Retries indefinitely so the service self-heals after reboot/power loss.
. /lib/functions.sh
. /usr/share/aether/setup-lib.sh

restart_core() {
	if [ -f "$RUN_DIR/core.pid" ]; then
		read -r CPID <"$RUN_DIR/core.pid" 2>/dev/null
		if [ -n "$CPID" ] && [ -d "/proc/$CPID" ]; then return 0; fi
	fi
	log "core not running — restarting"
	kill_finish 2>/dev/null
	for p in $(pidof aether 2>/dev/null); do kill "$p" 2>/dev/null; done
	sleep 1
	setsid "$PROG_AETHER" $ARGS >>"$RUN_DIR/core.log" 2>&1 < /dev/null &
	echo $! >"$RUN_DIR/core.pid"
	log "core restarted"
	sleep 2
}

while true; do
	config_load aether
	section_get enabled enabled 0
	[ "$enabled" = "1" ] || { rm -f "$RUN_DIR/finish.pid"; exit 0; }
	config_load aether
	load_options
	echo $$ >"$RUN_DIR/finish.pid"
	restart_core
	wait_for "SOCKS $bind_address" 1200 "! (nc $SOCKS_HOST $SOCKS_PORT < /dev/null 2>&1 | grep -q \"can.t connect\")" \
		|| { echo "down" >"$RUN_DIR/state"; rm -f "$RUN_DIR/finish.pid"; sleep 10; continue; }
	config_load aether
	section_get enabled enabled 0
	[ "$enabled" = "1" ] || { rm -f "$RUN_DIR/finish.pid"; exit 0; }
	config_load aether
	load_options
	if [ "$vpn_mode" = "1" ]; then
		[ -x "$PROG_HEV" ] || { log "ERROR: $PROG_HEV missing"; echo "down" >"$RUN_DIR/state"; rm -f "$RUN_DIR/finish.pid"; sleep 10; continue; }
		gen_hev_conf
		if . /lib/functions/procd.sh 2>/dev/null && procd_open_service aether /etc/init.d/aether 2>/dev/null; then
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
			|| { echo "down" >"$RUN_DIR/state"; rm -f "$RUN_DIR/finish.pid"; sleep 10; continue; }
		net_up || { echo "down" >"$RUN_DIR/state"; rm -f "$RUN_DIR/finish.pid"; sleep 10; continue; }
	fi
	date -u +%FT%TZ >"$RUN_DIR/uptime"
	echo "up" >"$RUN_DIR/state"
	log "UP (tun=$([ "$vpn_mode" = "1" ] && echo "$tun_name" || echo "proxy-only"))"
	rm -f "$RUN_DIR/finish.pid"
	sleep 60
done
