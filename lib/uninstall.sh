# Remove omarchy-herd. Keeps PHP builds, database data and settings unless --purge is given.

cmd_uninstall() {
  local purge="" yes="" arg unit
  for arg in "$@"; do
    case $arg in
    --purge) purge=1 ;;
    --yes | -y) yes=1 ;;
    *) die "usage: omarchy-herd uninstall [--purge] [--yes]" ;;
    esac
  done

  if [[ -n $purge && -z $yes ]]; then
    [[ -t 0 ]] || die "--purge deletes all database data; add --yes to confirm"
    printf 'This deletes every database, PHP build and setting in:\n  %s\n  %s\nType "delete" to continue: ' "$HERD_DATA" "$HERD_CONFIG_DIR" >&2
    read -r arg
    [[ $arg == delete ]] || die "aborted"
  fi

  info "Stopping services…"
  while read -r unit; do
    [[ -n $unit ]] || continue
    systemctl --user disable --now "$unit" >/dev/null 2>&1 || true
  done < <(systemctl --user list-units --all --plain --no-legend 'omarchy-herd-*' 2>/dev/null | awk '{print $1}')
  for unit in mariadb postgres valkey; do
    systemctl --user disable --now "omarchy-herd-$unit.service" >/dev/null 2>&1 || true
  done
  rm -f "$HERD_UNIT_DIR"/omarchy-herd-*.service
  systemctl --user daemon-reload

  info "Removing the web server, .test DNS and certificate authority (asks for your password)…"
  if [[ -t 0 ]]; then
    sudo "$HERD_ROOT/setup/root-uninstall.sh"
  else
    pkexec "$HERD_ROOT/setup/root-uninstall.sh"
  fi

  certutil -d "sql:$HOME/.pki/nssdb" -D -n omarchy-herd >/dev/null 2>&1 || true

  # Drop the PATH lines setup added to ~/.bashrc.
  if grep -qF "$HERD_SHELL_MARKER" "$HOME/.bashrc" 2>/dev/null; then
    sed -i "\|^$HERD_SHELL_MARKER\$|,+1d" "$HOME/.bashrc"
  fi

  local plugin="$HOME/.config/omarchy/plugins/andidst.herd"
  if [[ -L $plugin ]]; then
    if command -v omarchy >/dev/null; then
      omarchy plugin disable andidst.herd >/dev/null 2>&1 || true
    fi
    rm -f "$plugin"
  fi

  [[ $(readlink -f "$HOME/.local/bin/omarchy-herd" 2>/dev/null) == "$HERD_ROOT/bin/omarchy-herd" ]] &&
    rm -f "$HOME/.local/bin/omarchy-herd"

  if [[ -n $purge ]]; then
    rm -rf "${HERD_DATA:?}" "${HERD_CONFIG_DIR:?}" "${HERD_CACHE:?}"
    ok "omarchy-herd is uninstalled and its data deleted. Caddy's CA stays in ~/.local/share/caddy."
  else
    ok "omarchy-herd is uninstalled. Databases, PHP builds and settings are kept in $HERD_DATA and $HERD_CONFIG_DIR (delete them with --purge)."
  fi
}
