# luci-app-aether

LuCI app + opkg package + procd service that drives the
[Aether](https://github.com/CluvexStudio/Aether) censorship-circumvention core
(MASQUE / WireGuard / gool / mim) on OpenWrt routers, with full-system TUN via
`hev-socks5-tunnel` and one-switch direct routing for all Iranian destinations.

This is the router sibling of [Aethery](https://github.com/Omarchy71/Aethery)
(Windows desktop GUI): same core binary, same flag map, same embedded Iran
prefix lists — re-expressed as UCI config + procd + LuCI instead of Tauri.

## Target

Primary: **Linksys EA8300** (`ipq40xx/generic`, ARM Cortex-A7, 256 MB RAM) on
OpenWrt 24.10. The bundled core is upstream's `aether-linux-armv7-musl`
(statically linked, pinned to the same `v2.0.0` as Aethery), so it runs on any
armv7 OpenWrt target — but only `arm_cortex-a7_neon-vfpv4` ipks are built here.

## Install

Download `luci-app-aether_*.ipk` from
[releases](https://github.com/Omarchy71/luci-app-aether/releases), copy to the
router, then:

```sh
opkg update
opkg install hev-socks5-tunnel ip-full kmod-tun   # from official feeds
opkg install luci-app-aether_*.ipk
/etc/init.d/aether enable
```

Then open LuCI → Services → Aether, fill in the profile, tick **Direct
Iranian sites**, and start.

## How it works

- `/etc/init.d/aether` (procd) builds the exact same CLI flags Aethery's
  `profiles.rs` `as_args()` produces (`--gool/--wg/--masque/--mim`, `--peer`,
  `--wg-peer`, `--wiw-outer/inner`, `--mim-outer/inner`, `--noize`,
  `--keepalive`, `--fragment/--ech/--tls-groups`, `--route-direct/block`,
  `--routes`, `--mark`), starts the core, waits for its SOCKS port, then
  starts `hev-socks5-tunnel` on `aether0`.
- Loop avoidance uses the Linux path: core + hev sockets carry fwmark `0x9e`
  with an `ip rule fwmark … table main` bypass (no per-gateway routes needed).
- **Direct Iranian sites** (`direct_iran`): at start, the 2087 IPv4 + 766 IPv6
  aggregated Iranian prefixes in `usr/share/aether/` plus the domestic-domains
  preset are written to `/var/run/aether/routes.txt` (`[direct]` section,
  same format as Aethery's generated file) and passed as `--routes`; each
  prefix also gets a direct route via the WAN gateway so it never enters the
  tunnel. Your own `route_direct` entries merge in front, never replaced. A
  custom `routes_file` stays authoritative (preset skipped, logged).
- Unlike the desktop app, system DNS is deliberately left alone: dnsmasq keeps
  using the WAN resolver, domestic names resolve to domestic IPs (which route
  direct by prefix), foreign names resolve to foreign IPs (which go through
  the tunnel).

## Refreshing the Iran lists

```sh
bash scripts/refresh-iran-ranges.sh   # re-downloads + validates, from repo root
```

Same source and validation as Aethery's `fetch` script.

## Building

Tagged `router-*` pushes (and manual dispatches) cross-build the ipk in
GitHub Actions with the OpenWrt 24.10 SDK for `ipq40xx/generic`
(`.github/workflows/build.yml`). The Aether core tarball is fetched at build
time, hash-pinned in `luci-app-aether/Makefile`.
