#!/bin/sh
# On-demand egress probe for the LuCI status page — egress IP, exit
# country and TUN ping. Runs ONLY on manual Refresh (or a stale cache),
# never on page poll: the page polls the cached JSON, which is instant.
#
# One HTTPS fetch to the Cloudflare trace endpoint does triple duty:
# exit IP + country come from the body, latency from the fetch time.
# (ICMP ping can't work here — hev-socks5-tunnel carries TCP/UDP only;
# and this BusyBox has neither a `timeout` applet nor wget --tries.)
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
# Latency: one UDP DNS query straight through the TUN (ICMP can't pass
# hev). nslookup has its own internal timeout — it fails, never hangs.
# Exit code decides: an instant local failure must not read as 0 ms.
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
