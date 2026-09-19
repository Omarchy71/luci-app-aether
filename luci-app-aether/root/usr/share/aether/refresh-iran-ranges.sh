#!/bin/sh
# Refresh Iran IP ranges and update the bundled prefix lists.
# Run periodically (cron) or manually to keep the Iran preset current.
# Usage: /usr/share/aether/refresh-iran-ranges.sh

SHARE_DIR=/usr/share/aether
TMPDIR=$(mktemp -d)

# Iran IPv4 prefixes (from RIPE/APNIC)
echo "Downloading Iran IPv4 ranges..."
curl -sL "https://www.ripe.net/database/export/web-content/?export=RIPE&resource=IR&type-prefix" > "$TMPDIR/iran-v4.txt" 2>/dev/null || true
# Fallback: use maintained list
[ -s "$TMPDIR/iran-v4.txt" ] || curl -sL "https://raw.githubusercontent.com/nicecai/iran-cidr/main/iran-v4.txt" > "$TMPDIR/iran-v4.txt" 2>/dev/null || true

# Iran IPv6 prefixes
echo "Downloading Iran IPv6 ranges..."
curl -sL "https://www.ripe.net/database/export/web-content/?export=RIPE&resource=IR/32:-&type-prefix" > "$TMPDIR/iran-v6.txt" 2>/dev/null || true
[ -s "$TMPDIR/iran-v6.txt" ] || curl -sL "https://raw.githubusercontent.com/nicecai/iran-cidr/main/iran-v6.txt" > "$TMPDIR/iran-v6.txt" 2>/dev/null || true

# Validate and install
if [ -s "$TMPDIR/iran-v4.txt" ]; then
	grep -E '^[0-9]' "$TMPDIR/iran-v4.txt" | grep -v '^#' > "$SHARE_DIR/iran-v4.txt"
	echo "Updated iran-v4.txt: $(wc -l < "$SHARE_DIR/iran-v4.txt") prefixes"
fi
if [ -s "$TMPDIR/iran-v6.txt" ]; then
	grep -E '^[0-9a-f]:' "$TMPDIR/iran-v6.txt" | grep -v '^#' > "$SHARE_DIR/iran-v6.txt"
	echo "Updated iran-v6.txt: $(wc -l < "$SHARE_DIR/iran-v6.txt") prefixes"
fi

rm -rf "$TMPDIR"
