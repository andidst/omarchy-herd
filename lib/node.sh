# Node versions, managed through mise. Per-site versions live in the site's mise.local.toml.

valid_node_version() {
  [[ $1 =~ ^([0-9]+(\.[0-9]+){0,2}|lts|latest)$ ]]
}

node_default() {
  mise ls --global --json 2>/dev/null | jq -r '.node[0].requested_version // empty' 2>/dev/null || true
}

# Never fails: a broken or untrusted mise config shouldn't take the whole status down.
node_installed_json() {
  local default installed
  default=$(mise ls --global --json 2>/dev/null | jq -r '.node[0].version // empty' 2>/dev/null || true)
  installed=$(mise ls node --installed --json 2>/dev/null || true)
  jq --arg default "$default" '
    map({version, path: .install_path, default: (.version == $default)})
    | sort_by(.version | split(".") | map(tonumber? // 0)) | reverse' <<<"${installed:-[]}" 2>/dev/null || echo '[]'
}

# Newest release of each major line from 18 up.
node_available_json() {
  mise ls-remote node 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | jq -R -s --argjson installed "$(node_installed_json)" '
    split("\n") | map(select(length > 0)) | group_by(split(".")[0] | tonumber)
    | map(sort_by(split(".") | map(tonumber)) | last)
    | map(select(split(".")[0] | tonumber >= 18)) | reverse
    | map(. as $v | {major: (split(".")[0]), latest: $v, lts: ((split(".")[0] | tonumber) % 2 == 0),
        installed: ([$installed[].version | select(split(".")[0] == ($v | split(".")[0]))] | first // null)})'
}

cmd_node() {
  local action=${1:-list}
  shift || true
  case $action in
  list | ls)
    if [[ -n $HERD_JSON ]]; then node_installed_json; else mise ls node; fi
    ;;
  available)
    if [[ -n $HERD_JSON ]]; then
      node_available_json
    else
      node_available_json | jq -r '.[] | [.major, .latest, (if .lts then "LTS" else "" end), (.installed // "-")] | @tsv' |
        column -t -s $'\t' -N MAJOR,LATEST,LTS,INSTALLED
    fi
    ;;
  install | add)
    valid_node_version "${1:-}" || die "usage: omarchy-herd node install <version, e.g. 22>"
    info "Installing Node $1…"
    mise install "node@$1" >&2 || die "mise couldn't install Node $1"
    ok "Node $(mise latest --installed "node@$1" 2>/dev/null) is installed"
    ;;
  uninstall | remove)
    [[ ${1:-} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "usage: omarchy-herd node uninstall <exact version, e.g. 22.11.0>"
    mise uninstall "node@$1" >&2 || die "mise couldn't remove Node $1"
    ok "Removed Node $1"
    ;;
  default)
    valid_node_version "${1:-}" || die "usage: omarchy-herd node default <version>"
    (cd "$HOME" && mise use --global "node@$1" >&2) || die "mise couldn't set Node $1 as default"
    ok "Node $1 is now the default"
    ;;
  use | isolate)
    valid_node_version "${1:-}" || die "usage: omarchy-herd node use <version> [site]"
    local name path
    name=$(resolve_site "${2:-}")
    path=$(site_path "$name") || die "$name has no folder"
    # An explicit path, because mise would otherwise write to the nearest parent config (e.g. ~/Work/.mise.toml).
    mise use --path "$path/mise.local.toml" "node@$1" >&2 || die "mise couldn't set Node $1 for $name"
    ok "$name uses Node $1 (saved in $path/mise.local.toml)"
    ;;
  reset | unisolate)
    local name path
    name=$(resolve_site "${1:-}")
    path=$(site_path "$name") || die "$name has no folder"
    [[ -f $path/mise.local.toml ]] && mise unuse --no-prune --path "$path/mise.local.toml" node >&2
    ok "$name uses the default Node again"
    ;;
  *) die "unknown node command '$action' (list, available, install, uninstall, default, use, reset)" ;;
  esac
}
