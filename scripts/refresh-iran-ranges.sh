#!/usr/bin/env bash
# Refresh the embedded Iranian prefix lists from the daily-aggregated source.
# Same source + validation as Aethery's refresh script.
# Run from the repo root:  bash scripts/refresh-iran-ranges.sh
set -euo pipefail

BASE="https://github.com/Cod3ByAmir/iran-ip-ranges/releases/latest/download"
OUT="luci-app-aether/root/usr/share/aether"

curl -sSL --max-time 120 "$BASE/iran-ipv4.txt" -o "$OUT/iran-v4.txt"
curl -sSL --max-time 120 "$BASE/iran-ipv6.txt" -o "$OUT/iran-v6.txt"

python3 - "$OUT/iran-v4.txt" "$OUT/iran-v6.txt" <<'EOF'
import ipaddress, sys
total = 0
for path in sys.argv[1:]:
    for line in open(path):
        line = line.strip()
        if not line:
            continue
        ipaddress.ip_network(line)  # raises on junk
        total += 1
print(f"OK: {total} prefixes")
EOF
