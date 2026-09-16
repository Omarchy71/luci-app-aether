#!/bin/sh
# On-demand egress probe for the LuCI status page — egress IP, exit
# country and TUN ping. Runs ONLY on manual Refresh (or a stale cache),
# never on page poll: the page polls the cached JSON, which is instant.
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
RTT="$(ping -c2 -W3 -I "$TUN" 1.1.1.1 2>/dev/null \
	| grep round-trip | sed -n 's#.*= \([0-9.]*\)/\([0-9.]*\)/.*#\2#p')"
[ -n "$RTT" ] || RTT="?"
TRACE="$(wget -qO- --timeout=12 --tries=1 \
	https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null)"
IP="$(printf '%s' "$TRACE" | sed -n 's/^ip=//p')"
CC="$(printf '%s' "$TRACE" | sed -n 's/^loc=//p')"
printf '{"state":"up","ts":"%s","tun":"%s","ping_ms":"%s","egress_ip":"%s","country":"%s"}\n' \
	"$NOW" "$TUN" "$RTT" "$IP" "$CC" >"$TMP" && mv "$TMP" "$OUT"
