#!/usr/bin/env bash
# Root half of omarchy-herd setup, run once through sudo or pkexec:
#   - installs Caddy, dnsmasq, MariaDB, PostgreSQL, Valkey
#   - runs Caddy as you on ports 80/443, bound to localhost only
#   - answers *.test with 127.0.0.1 via a dnsmasq that only systemd-resolved talks to
#   - routes .test lookups to it through a dummy NetworkManager link, so `omarchy dns` can't clobber it
#   - trusts Caddy's local certificate authority system-wide

set -euo pipefail

caddyfile=${1:?caddyfile path required}
run_dir=${2:?run dir required}
ca_root=${3:?CA root path required}

uid=${PKEXEC_UID:-${SUDO_UID:-}}
[[ -n $uid && $uid != 0 ]] || { echo "run this through sudo or pkexec as your normal user" >&2; exit 1; }
user=$(id -nu "$uid")
home=$(getent passwd "$user" | cut -d: -f6)

# Only accept paths inside the invoking user's home, since root writes them into unit files.
for path in "$caddyfile" "$run_dir" "$ca_root"; do
  [[ $path == "$home"/* && $path != *[[:space:]\"\'\$\`\\]* && $path != *..* ]] ||
    { echo "refusing unexpected path: $path" >&2; exit 1; }
done

pacman -S --needed --noconfirm caddy dnsmasq mariadb postgresql valkey jq

data_dir=${run_dir%/run}
caddy_data=${ca_root%/pki/authorities/local/root.crt}
[[ $data_dir != "$run_dir" && $caddy_data != "$ca_root" ]] || { echo "unexpected directory layout" >&2; exit 1; }
install -d -o "$user" -g "$(id -gn "$user")" -m 700 "$run_dir" "$data_dir/log" "$caddy_data" "$home/.config/caddy"

# Shared sandbox for both services: read-only OS, no devices, kernel knobs or new privileges.
sandbox='NoNewPrivileges=true
ProtectSystem=strict
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true
ProtectClock=true
ProtectHostname=true
RestrictNamespaces=true
RestrictRealtime=true
RestrictSUIDSGID=true
LockPersonality=true
MemoryDenyWriteExecute=true
SystemCallArchitectures=native
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE'

install -d -m 755 /etc/omarchy-herd
cat >/etc/omarchy-herd/dnsmasq.conf <<'EOF'
# omarchy-herd: answer every *.test name with this machine. Nothing else.
listen-address=127.0.0.153
port=53
bind-interfaces
no-resolv
no-hosts
no-poll
pid-file=
address=/test/127.0.0.1
address=/test/::1
EOF

cat >/etc/systemd/system/omarchy-herd-dns.service <<EOF
[Unit]
Description=omarchy-herd .test DNS (dnsmasq)
After=network.target

[Service]
User=dnsmasq
Group=dnsmasq
ExecStart=/usr/bin/dnsmasq --keep-in-foreground --conf-file=/etc/omarchy-herd/dnsmasq.conf
Restart=on-failure
ProtectHome=true
$sandbox

[Install]
WantedBy=multi-user.target
EOF

# Caddy runs as you so it can read your projects and reach PHP-FPM's sockets.
# It can only write its certificates, the log folder and the socket folder.
cat >/etc/systemd/system/omarchy-herd-caddy.service <<EOF
[Unit]
Description=omarchy-herd web server (Caddy)
After=network.target

[Service]
Type=notify
User=$user
Group=$(id -gn "$user")
Environment=XDG_DATA_HOME=${caddy_data%/caddy}
ExecStart=/usr/bin/caddy run --config $caddyfile --adapter caddyfile
ExecReload=/usr/bin/caddy reload --config $caddyfile --adapter caddyfile --address unix/$run_dir/caddy-admin.sock
ReadWritePaths=$caddy_data $run_dir $data_dir/log $home/.config/caddy
Restart=on-failure
TimeoutStopSec=5s
LimitNOFILE=1048576
$sandbox

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
for unit in omarchy-herd-dns omarchy-herd-caddy; do
  systemctl enable "$unit.service" >/dev/null 2>&1
  systemctl restart "$unit.service"
  systemctl is-active --quiet "$unit.service" || {
    journalctl -u "$unit.service" -n 20 --no-pager >&2
    echo "$unit failed to start" >&2
    exit 1
  }
done

# Caddy creates its local CA on first start.
for _ in {1..40}; do
  [[ -f $ca_root ]] && break
  sleep 0.25
done
[[ -f $ca_root ]] || { echo "Caddy didn't create its certificate authority at $ca_root" >&2; exit 1; }
install -m 644 "$ca_root" /etc/ca-certificates/trust-source/anchors/omarchy-herd.crt
update-ca-trust

if ! nmcli -t -f NAME connection show | grep -qx omarchy-herd; then
  nmcli connection add type dummy ifname herd0 con-name omarchy-herd \
    connection.autoconnect yes \
    ipv4.method manual ipv4.addresses 192.0.2.53/32 ipv4.never-default yes \
    ipv4.ignore-auto-dns yes ipv4.dns 127.0.0.153 ipv4.dns-search '~test' \
    ipv6.method disabled >/dev/null
fi
nmcli connection up omarchy-herd >/dev/null

echo "System setup done."
