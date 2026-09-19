#!/bin/sh
# On-demand egress probe — egress IP, country, TUN ping.
# Runs ONLY on manual Refresh (or stale cache). Page polls cached JSON.
RUN_DIR=/var/run/aether
OUT=$RUN_DIR/egress.json
TMP=$OUT.tmp
TUN="$(uci -q get aether.main.tun_name 2>/dev/null)"
[ -n "$TUN" ] || TUN=aether0
STATE="$(cat "$RUN_DIR/state" 2>/dev/null)"
[ -n "$STATE" ] || STATE=down
NOW="$(date -u +%FT%TZ)"
if [ "$STATE" != "up" ] || ! ip link show "$TUN" >/dev/null 2>&1; then
	printf '{"state":"%s","ts":"%s"}\n' "$STATE" "$NOW" >"$TMP" \
		&& mv "$TMP" "$OUT"
	exit 0
fi
# Latency: one UDP DNS query straight through the TUN
T0="$(cut -d' ' -f1 /proc/uptime 2>/dev/null)"
nslookup www.cloudflare.com 1.1.1.1 >/dev/null 2>&1
RC=$?
T1="$(cut -d' ' -f1 /proc/uptime 2>/dev/null)"
if [ "$RC" = "0" ] && [ -n "$T0" ] && [ -n "$T1" ]; then
	RTT="$(awk "BEGIN{printf \"%.0f\", ($T1-$T0)*1000}")"
else
	RTT="?"
fi
TRACE="$(wget -qO- --timeout=12 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null)"
IP="$(printf '%s' "$TRACE" | sed -n 's/^ip=//p')"
CC="$(printf '%s' "$TRACE" | sed -n 's/^loc=//p')"
printf '{"state":"up","ts":"%s","tun":"%s","ping_ms":"%s","egress_ip":"%s","country":"%s"}\n' \
	"$NOW" "$TUN" "$RTT" "$IP" "$CC" >"$TMP" && mv "$TMP" "$OUT"
