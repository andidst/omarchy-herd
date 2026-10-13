# First-time setup, status overview, and health checks.

HERD_SHELL_MARKER="# omarchy-herd: project-aware php"
HERD_DEFAULT_PHP="8.4"
HERD_REQUIRED=(jq curl mise caddy dnsmasq mariadbd postgres valkey-server)

write_php_shim() {
  cat >"$HERD_BIN/php" <<'EOF'
#!/usr/bin/env bash
# omarchy-herd: run the PHP version assigned to the project you're in.
data="${XDG_DATA_HOME:-$HOME/.local/share}/omarchy-herd"
config="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-herd"
version=${HERD_PHP_VERSION:-}

if [[ -z $version && -r $data/etc/php-map ]]; then
  best=0 fallback=""
  while IFS=$'\t' read -r path ver; do
    if [[ $path == default ]]; then
      fallback=$ver
    elif [[ ($PWD == "$path" || $PWD == "$path"/*) ]] && ((${#path} > best)); then
      best=${#path} version=$ver
    fi
  done <"$data/etc/php-map"
  version=${version:-$fallback}
fi

if [[ -n $version && -x $data/php/$version/php ]]; then
  export PHPRC="$config/php/$version"
  exec "$data/php/$version/php" "$@"
fi
exec /usr/bin/php "$@"
EOF
  chmod +x "$HERD_BIN/php"
}

add_shell_path() {
  local rc="$HOME/.bashrc"
  grep -qF "$HERD_SHELL_MARKER" "$rc" 2>/dev/null && return
  printf '\n%s\nexport PATH="%s:$PATH"\n' "$HERD_SHELL_MARKER" "$HERD_BIN" >>"$rc"
  info "Added $HERD_BIN to PATH in ~/.bashrc (open a new terminal to pick it up)"
}

system_setup_needed() {
  local unit cmd
  for unit in "${HERD_SYSTEM_UNITS[@]}"; do
    systemctl is-enabled --quiet "$unit" 2>/dev/null || return 0
  done
  for cmd in "${HERD_REQUIRED[@]}"; do
    command -v "$cmd" >/dev/null || return 0
  done
  [[ -f /etc/ca-certificates/trust-source/anchors/omarchy-herd.crt ]] || return 0
  # Older installs predate the current units (e.g. the sandboxing); re-apply them.
  [[ $(cat /etc/omarchy-herd/setup-version 2>/dev/null) == "$HERD_SYSTEM_SETUP_VERSION" ]] || return 0
  return 1
}

run_system_setup() {
  local script="$HERD_ROOT/setup/root-setup.sh"
  # Root won't create anything in your home, so make every folder Caddy writes to now.
  local caddy_data=${HERD_CA_ROOT%/pki/authorities/local/root.crt}
  mkdir -p "$caddy_data"
  chmod 700 "$caddy_data"
  ensure_dirs
  info "Setting up the web server, .test DNS and HTTPS certificates (asks for your password)…"
  if [[ -t 0 ]]; then
    sudo "$script" "$HERD_CADDYFILE" "$HERD_RUN" "$HERD_CA_ROOT"
  else
    pkexec "$script" "$HERD_CADDYFILE" "$HERD_RUN" "$HERD_CA_ROOT"
  fi
}

# Chrome reads user-added roots from the NSS database in ~/.pki.
trust_ca_for_browsers() {
  local nssdb="$HOME/.pki/nssdb"
  [[ -f $HERD_CA_ROOT ]] && command -v certutil >/dev/null || return 0
  if [[ ! -f $nssdb/cert9.db ]]; then
    mkdir -p "$nssdb"
    certutil -N -d "sql:$nssdb" --empty-password
  fi
  certutil -d "sql:$nssdb" -D -n omarchy-herd >/dev/null 2>&1 || true
  certutil -d "sql:$nssdb" -A -t "C,," -n omarchy-herd -i "$HERD_CA_ROOT"
}

cmd_setup() {
  local force_system=""
  case ${1:-} in
  --system) force_system=1 ;;
  "") ;;
  *) die "usage: omarchy-herd setup [--system]" ;;
  esac

  config_init
  take_lock

  # Serve the dashboard, and park ~/Work the first time.
  jq -e '.links.herd' "$HERD_CONFIG" >/dev/null ||
    config_update --arg dir "$HERD_ROOT/dashboard" '.links.herd = $dir'
  if [[ -d $HOME/Work ]] && jq -e '.parked | length == 0' "$HERD_CONFIG" >/dev/null; then
    config_update --arg dir "$HOME/Work" '.parked += [$dir]'
  fi

  write_user_units
  write_php_shim
  add_shell_path

  if [[ -n $force_system ]] || system_setup_needed; then
    sites_apply
    run_system_setup || die "system setup didn't finish"
  fi

  [[ -n $(php_installed_series) ]] || php_install "$HERD_DEFAULT_PHP"
  local series
  for series in $(php_installed_series); do
    php_write_fpm_conf "$series"
    php_write_wrapper "$series"
  done
  sites_apply
  trust_ca_for_browsers

  cmd_service start databases >/dev/null
  ok "omarchy-herd is ready: open https://herd.$(tld)"
}

dns_resolves() {
  [[ $(getent ahostsv4 "herd.$(tld)" 2>/dev/null | awk 'NR==1 {print $1}') == 127.0.0.1 ]]
}

ca_trusted() {
  [[ -f /etc/ca-certificates/trust-source/anchors/omarchy-herd.crt ]]
}

cmd_status() {
  local status
  status=$(jq -n \
    --arg version "$HERD_VERSION" \
    --arg tld "$(tld)" \
    --argjson caddy "$(json_bool system_unit_active omarchy-herd-caddy)" \
    --argjson dns "$(json_bool system_unit_active omarchy-herd-dns)" \
    --argjson resolves "$(json_bool dns_resolves)" \
    --argjson trusted "$(json_bool ca_trusted)" \
    --arg php_default "$(config_get .php.default)" \
    --argjson php "$(php_versions_json)" \
    --arg node_default "$(node_default)" \
    --argjson node "$(node_installed_json)" \
    --argjson services "$(services_json)" \
    --argjson sites "$(sites_json with-node)" \
    --slurpfile config "$HERD_CONFIG" '{
      version: $version,
      tld: $tld,
      dashboard: "https://herd.\($tld)",
      web: {caddy: $caddy, dns: $dns, resolves: $resolves, https_trusted: $trusted},
      php: {default: $php_default, versions: $php},
      node: {default: $node_default, versions: $node},
      services: $services,
      parked: $config[0].parked,
      sites: $sites
    }')

  if [[ -n $HERD_JSON ]]; then
    printf '%s\n' "$status"
    return
  fi

  jq -r '
    def mark: if . then "●" else "○" end;
    "Web      \(.web.caddy | mark) Caddy   \(.web.dns | mark) .\(.tld) DNS   \(.web.https_trusted | mark) HTTPS trusted",
    "PHP      " + ([.php.versions[] | "\(.running | mark) \(.version)\(if .default then " (default)" else "" end)"] | join("   ")),
    "Node     " + ([.node.versions[] | "\(.version)\(if .default then " (default)" else "" end)"] | join("   ")),
    "Services " + ([.services[] | "\(.running | mark) \(.name) :\(.port)"] | join("   ")),
    "Parked   " + (.parked | join(", ")),
    "",
    "Sites",
    (.sites[] | "  \(.url)  \(if .proxy then "→ \(.proxy)" else "PHP \(.php)\(if .isolated then " (isolated)" else "" end)" end)\(if .node then "  Node \(.node)" else "" end)")
  ' <<<"$status"
}

cmd_doctor() {
  local failures=0
  check() {
    local label=$1
    shift
    if "$@" >/dev/null 2>&1; then
      printf '  ✓ %s\n' "$label"
    else
      printf '  ✗ %s\n' "$label"
      failures=$((failures + 1))
    fi
  }

  echo "omarchy-herd doctor"
  local cmd
  for cmd in "${HERD_REQUIRED[@]}"; do check "$cmd installed" command -v "$cmd"; done
  check "Caddy web server running" system_unit_active omarchy-herd-caddy
  check ".$(tld) DNS server running" system_unit_active omarchy-herd-dns
  check "herd.$(tld) resolves to 127.0.0.1" dns_resolves
  check "HTTPS certificate authority trusted" ca_trusted
  check "dashboard answers over HTTPS" curl -fsS --max-time 5 -o /dev/null "https://herd.$(tld)"
  check "php shim first on PATH in new shells" bash -ic '[[ $(command -v php) == '"$HERD_BIN"'/php ]]'
  local series
  for series in $(php_installed_series); do
    check "PHP $series FPM running" user_unit_active "omarchy-herd-php@$series"
  done
  if ((failures == 0)); then
    echo "All good."
  else
    echo "$failures problem(s) found."
    return 1
  fi
}
