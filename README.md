# luci-app-aether — From-Scratch Redesign

Complete LuCI web interface for the Aether v2.0.0 censorship-circumvention core on OpenWrt 24.10.5 (Linksys EA8300, ipq40xx/generic).

## What This Package Provides

- **Aether Core v2.0.0** — gool-only (WARP-in-WARP) censorship circumvention
- **hev-socks5-tunnel** — TUN engine for full-system VPN
- **LuCI Dashboard** — modern web UI with real-time status, egress checking, and full configuration
- **Procd Service** — self-healing init script with detached finish task
- **Iran Direct Routing** — ~2850 embedded prefixes routed via WAN
- **Single ipk Package** — all components bundled for easy installation

## Features

- gool-only protocol (WG-in-WARP) with all flag parity to the desktop apps
- Modern dashboard with 5-second polling for state, egress IP, latency
- Connect/Disconnect control buttons
- Full configuration: scan mode, obfuscation, endpoint pinning, routing, DNS
- HTTP CONNECT proxy support (optional)
- Route sniffing with configurable timeout
- TLS group configuration
- Performance profile selector (low/medium/high)
- Egress checking: exit IP, country, TUN latency
- Real-time core log viewer
- Self-healing retry loop for service recovery after reboot/power loss
- Iranian direct routing with automatic prefix list updates

## Requirements

- OpenWrt 24.10.5 (apk) on ipq40xx/generic (Linksys EA8300)
- LuCI installed (`luci-lua-runtime`, `uhttpd-mod-lua`, `luci-base`)
- Internet connectivity for the core to discover endpoints

## Installation

### Single-file installation (from built ipk):
```bash
# Copy the ipk to the router
scp luci-app-aether_1.0.0-1_arm_cortex-a7_neon-vfpv4.ipk root@192.168.1.1:/tmp/

# SSH into the router and install
ssh root@192.168.1.1
opkg install /tmp/luci-app-aether_*.ipk
```

### Building from source:
```bash
# Clone this repository
git clone https://github.com/Omarchy71/luci-app-aether.git
cd luci-app-aether

# Build (requires OpenWrt SDK)
make package/luci-app-aether/compile -j$(nproc) V=s
```

Or use GitHub Actions:
- Push a `router-*` tag to trigger a build and release
- Use `workflow_dispatch` for manual builds targeting 24.10 or 25.12

## Configuration

After installation, access the web UI at `http://192.168.1.1/cgi-bin/luci/admin/services/aether`

Default UCI config: `/etc/config/aether`

### Key settings:
| Option | Default | Description |
|--------|---------|-------------|
| `enabled` | 0 | Enable/disable the service |
| `scan_mode` | balanced | turbo/balanced/thorough/stealth/ironclad |
| `ip_version` | both | v4/v6/both |
| `noize` | balanced | none/light/firewall/balanced/gfw/aggressive |
| `bind_address` | 127.0.0.1:1080 | SOCKS5 proxy address |
| `vpn_mode` | 1 | 1=full TUN, 0=proxy only |
| `dns` | 1.1.1.1 | Upstream DNS inside tunnel |
| `direct_iran` | 1 | Route Iranian sites via WAN |
| `tun_mtu` | 1420 | TUN interface MTU |

## Architecture

```
Aether Core (/usr/sbin/aether)
  ├── gool protocol (WG-in-WARP)
  ├── SOCKS5 proxy at --bind
  ├── Firewall mark 0x9e
  └── Routes file for Iran direct

hev-socks5-tunnel (/usr/bin/hev-socks5-tunnel)
  ├── Creates TUN device (aether0)
  ├── Reads YAML config from finish.sh
  └── Provides full-system tunnel

Procd (/etc/init.d/aether)
  ├── start_service: launches core + finish task
  ├── stop_service: cleans up routes, firewall
  └── status_service: reports status for LuCI

Finish Task (/usr/share/aether/finish.sh)
  ├── Self-healing retry loop (while true)
  ├── Waits for SOCKS port
  ├── Starts hev (if vpn_mode=1)
  ├── Configures net_up (routes, DNS, firewall)
  └── Writes state file

LuCI Web UI
  ├── Controller: API endpoints
  ├── CBI Model: Configuration form
  └── Status Page: Real-time dashboard
```

## Iran Direct Routing

The package includes ~2850 embedded IP prefixes for Iranian sites. These are routed directly via WAN instead of through the tunnel, allowing access to domestic services.

To update the prefix lists:
```bash
/usr/share/aether/refresh-iran-ranges.sh
```

## License

MIT
