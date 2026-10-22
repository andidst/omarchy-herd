#!/usr/bin/env bash
# Root half of omarchy-herd setup, run through sudo or pkexec:
#   - installs Caddy, dnsmasq, MariaDB, PostgreSQL, Valkey
#   - runs Caddy as you on ports 80/443, bound to localhost only, in a systemd sandbox
#   - answers *.test with 127.0.0.1 via a dnsmasq that only systemd-resolved talks to
#   - routes .test lookups to it through a dummy NetworkManager link, so `omarchy dns` can't clobber it
#   - trusts Caddy's local certificate authority system-wide
#
# Root never creates, chowns or copies anything inside your home folder: the CLI creates the
# folders beforehand, and this script only checks them and reads the CA certificate as you.

set -euo pipefail

# Bump when the units or system config below change, so `omarchy-herd setup` re-applies them.
SETUP_VERSION=2

caddyfile=${1:?caddyfile path required}
run_dir=${2:?run dir required}
ca_root=${3:?CA root path required}

uid=${PKEXEC_UID:-${SUDO_UID:-}}
[[ -n $uid && $uid != 0 ]] || { echo "run this through sudo or pkexec as your normal user" >&2; exit 1; }
user=$(id -nu "$uid")
group=$(id -gn "$uid")
home=$(getent passwd "$user" | cut -d: -f6)

fail() {
  echo "omarchy-herd setup: $*" >&2
  exit 1
}

# Root writes these paths into unit files, so accept only plain paths inside the user's home.
for path in "$caddyfile" "$run_dir" "$ca_root"; do
  [[ $path == "$home"/* && $path != *[[:space:]\"\'\$\`\\%]* && $path != *..* ]] || fail "refusing unexpected path: $path"
done

data_dir=${run_dir%/run}
caddy_data=${ca_root%/pki/authorities/local/root.crt}
[[ $data_dir != "$run_dir" && $caddy_data != "$ca_root" ]] || fail "unexpected directory layout"

# Folders Caddy may write to must already exist as real directories owned by the user,
# with no symlink anywhere in their path; otherwise systemd would follow the link.
for dir in "$run_dir" "$data_dir/log" "$caddy_data"; do
  [[ $(realpath -e -- "$dir" 2>/dev/null) == "$dir" && -d $dir && $(stat -c %u -- "$dir") == "$uid" ]] ||
    fail "$dir must be a directory owned by $user (no symlinks); run omarchy-herd setup as $user"
done

pacman -S --needed --noconfirm caddy dnsmasq mariadb postgresql valkey jq upx

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

# Caddy runs as you so it can read your projects and reach PHP-FPM's sockets. It can only
# write its certificates, the log folder and the socket folder. The "-" lets it start even if
# one is missing, and it keeps retrying until your session's services recreate them.
cat >/etc/systemd/system/omarchy-herd-caddy.service <<EOF
[Unit]
Description=omarchy-herd web server (Caddy)
After=network.target
StartLimitIntervalSec=0

[Service]
Type=notify
User=$user
Group=$group
Environment=XDG_DATA_HOME=${caddy_data%/caddy}
ExecStart=/usr/bin/caddy run --config $caddyfile --adapter caddyfile
ExecReload=/usr/bin/caddy reload --config $caddyfile --adapter caddyfile --address unix/$run_dir/caddy-admin.sock
ReadWritePaths=-$caddy_data -$run_dir -$data_dir/log
Restart=on-failure
RestartSec=5
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
    fail "$unit failed to start"
  }
done

# Caddy creates its local CA on first start. Read it as the user (never follow a path as root),
# check it really is a CA certificate, then trust it.
for _ in {1..40}; do
  runuser -u "$user" -- test -f "$ca_root" && break
  sleep 0.25
done
cert=$(mktemp)
trap 'rm -f "$cert"' EXIT
runuser -u "$user" -- cat -- "$ca_root" >"$cert" || fail "couldn't read Caddy's certificate authority at $ca_root"
openssl x509 -in "$cert" -noout -ext basicConstraints 2>/dev/null | grep -q 'CA:TRUE' ||
  fail "$ca_root isn't a CA certificate"
install -m 644 "$cert" /etc/ca-certificates/trust-source/anchors/omarchy-herd.crt
update-ca-trust

if ! nmcli connection show omarchy-herd >/dev/null 2>&1; then
  nmcli connection add type dummy ifname herd0 con-name omarchy-herd \
    connection.autoconnect yes \
    ipv4.method manual ipv4.addresses 192.0.2.53/32 ipv4.never-default yes \
    ipv4.ignore-auto-dns yes ipv4.dns 127.0.0.153 ipv4.dns-search '~test' \
    ipv6.method disabled >/dev/null
fi
nmcli connection up omarchy-herd >/dev/null

echo "$SETUP_VERSION" >/etc/omarchy-herd/setup-version
echo "System setup done."
