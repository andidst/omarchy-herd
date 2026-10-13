# Shared paths, config access, and output helpers for omarchy-herd.

HERD_VERSION="0.1.0"

HERD_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-herd"
HERD_CONFIG="$HERD_CONFIG_DIR/config.json"
HERD_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/omarchy-herd"
HERD_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-herd"
HERD_UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

HERD_RUN="$HERD_DATA/run"
HERD_LOG="$HERD_DATA/log"
HERD_ETC="$HERD_DATA/etc"
HERD_BIN="$HERD_DATA/bin"
HERD_PHP_DIR="$HERD_DATA/php"
HERD_DB_DIR="$HERD_DATA/data"

HERD_CADDYFILE="$HERD_ETC/Caddyfile"
HERD_CADDY_ADMIN="unix/$HERD_RUN/caddy-admin.sock"
HERD_CA_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/caddy/pki/authorities/local/root.crt"
HERD_PHP_MIRROR="https://dl.static-php.dev/static-php-cli/bulk"

# Static PHP builds published by static-php-cli.
HERD_PHP_SERIES=(8.0 8.1 8.2 8.3 8.4 8.5)

# System units installed once by setup/root-setup.sh.
HERD_SYSTEM_UNITS=(omarchy-herd-caddy omarchy-herd-dns)

HERD_JSON=${HERD_JSON:-}

# mise lives in /usr/bin, but php-fpm and systemd start us with a minimal PATH.
export PATH="$HERD_BIN:/usr/local/bin:/usr/bin:$PATH"

info() {
  [[ -n $HERD_JSON ]] || printf '%s\n' "$*" >&2
}

warn() {
  printf 'omarchy-herd: %s\n' "$*" >&2
}

die() {
  if [[ -n $HERD_JSON ]]; then
    jq -cn --arg error "$*" '{ok: false, error: $error}'
  else
    printf 'omarchy-herd: %s\n' "$*" >&2
  fi
  exit 1
}

# Report a successful action: JSON for the dashboard and bar, plain text otherwise.
ok() {
  if [[ -n $HERD_JSON ]]; then
    jq -cn --arg message "$*" '{ok: true, message: $message}'
  else
    printf '%s\n' "$*"
  fi
}

ensure_dirs() {
  mkdir -p "$HERD_CONFIG_DIR" "$HERD_RUN" "$HERD_LOG" "$HERD_ETC" "$HERD_BIN" \
    "$HERD_PHP_DIR" "$HERD_DB_DIR" "$HERD_CACHE" "$HERD_UNIT_DIR"
}

config_init() {
  ensure_dirs
  [[ -f $HERD_CONFIG ]] && return
  jq -n '{tld: "test", php: {default: null}, parked: [], links: {}, proxies: {}, isolated: {}}' >"$HERD_CONFIG"
}

config_get() {
  jq -r "$1 // empty" "$HERD_CONFIG"
}

# Apply a jq filter to the config in place. Extra args are passed to jq.
config_update() {
  local tmp
  tmp=$(mktemp "$HERD_CONFIG.XXXXXX")
  if jq "$@" "$HERD_CONFIG" >"$tmp"; then
    mv "$tmp" "$HERD_CONFIG"
  else
    rm -f "$tmp"
    die "could not update $HERD_CONFIG"
  fi
}

# Serialize commands that change state, so the dashboard and terminal can't race.
take_lock() {
  exec 9>"$HERD_RUN/lock"
  flock -w 120 9 || die "another omarchy-herd command is still running"
}

tld() {
  config_get .tld
}

slugify() {
  local s=${1,,}
  s=${s//[^a-z0-9-]/-}
  while [[ $s == *--* ]]; do s=${s//--/-}; done
  s=${s#-}
  s=${s%-}
  printf '%s' "$s"
}

valid_site_name() {
  [[ $1 =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]
}

valid_php_series() {
  local series
  for series in "${HERD_PHP_SERIES[@]}"; do
    [[ $1 == "$series" ]] && return 0
  done
  return 1
}

# Paths end up inside the generated Caddyfile and php-map, so keep them to safe characters.
valid_path() {
  local unsafe='["\{}[:cntrl:]]'
  [[ $1 == /* && ! $1 =~ $unsafe ]]
}

# Folders that may be served as sites. Refuses / and $HOME (which would publish every
# folder in it) and hidden folders such as ~/.ssh or ~/.config.
servable_dir() {
  local dir=$1
  valid_path "$dir" || die "unsupported characters in $dir"
  [[ $dir != / && $dir != "$HOME" ]] || die "refusing to serve $dir; pick the folder that holds your projects"
  [[ $dir != */.* ]] || die "refusing to serve hidden folder $dir"
}

user_unit_active() {
  systemctl --user is-active --quiet "$1"
}

system_unit_active() {
  systemctl is-active --quiet "$1"
}

wait_for_socket() {
  local i
  for i in {1..50}; do
    [[ -S $1 ]] && return 0
    sleep 0.1
  done
  return 1
}

json_bool() {
  if "$@"; then printf true; else printf false; fi
}
