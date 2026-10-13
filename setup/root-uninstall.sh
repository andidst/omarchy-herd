#!/usr/bin/env bash
# Root half of `omarchy-herd uninstall`: undoes everything setup/root-setup.sh did,
# except the packages, which other tools may use.

set -euo pipefail

[[ $EUID == 0 ]] || { echo "run this through sudo or pkexec" >&2; exit 1; }

for unit in omarchy-herd-caddy omarchy-herd-dns; do
  systemctl disable --now "$unit.service" 2>/dev/null || true
  rm -f "/etc/systemd/system/$unit.service"
done
systemctl daemon-reload

if nmcli connection show omarchy-herd >/dev/null 2>&1; then
  nmcli connection delete omarchy-herd >/dev/null
fi

rm -rf /etc/omarchy-herd  # includes setup-version

if [[ -f /etc/ca-certificates/trust-source/anchors/omarchy-herd.crt ]]; then
  rm -f /etc/ca-certificates/trust-source/anchors/omarchy-herd.crt
  update-ca-trust
fi

echo "System pieces removed. Packages stay installed; remove them with:"
echo "  sudo pacman -Rns caddy dnsmasq mariadb postgresql valkey"
