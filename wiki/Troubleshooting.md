# Troubleshooting

Start here:

```bash
omarchy-herd doctor
```

It checks each piece in order and marks the failing ones with ✗. Fix the first failure first; later ones often follow from it.

## Common problems

| Problem | Fix |
|---|---|
| `omarchy-herd: not set up yet` | Run `omarchy-herd setup` |
| `omarchy-herd: command not found` | `~/.local/bin` isn't on your `PATH`, or `install.sh` didn't run. Run `~/Work/omarchy-herd/install.sh` |
| Certificate warning in the browser | Restart the browser. Firefox needs the CA imported by hand, see [Installation](Installation#browsers) |
| `curl: (60) SSL certificate problem` | The system trust is missing: `omarchy-herd setup --system` |
| A new project has no domain | It's only automatic for folders directly inside a parked folder. Run `omarchy-herd apply`, and check `omarchy-herd sites` |
| A site shows the wrong project | Two folders have the same name after [slugifying](Sites#names); links win over proxies, which win over parked folders. Link one under another name |
| A site returns 502 | Its PHP-FPM isn't running: `omarchy-herd start php-8.4`. For proxies, the dev server isn't running on that port |
| A site returns 404 for everything | The document root is wrong: a `public/` folder exists but isn't the web root, or the reverse. See [Sites](Sites#document-root) |
| A site returns 403 or a blank page | Check PHP's error log: `omarchy-herd logs php-8.4` |
| `php` in the terminal is the wrong version | Open a new terminal (or `source ~/.bashrc`), then check `omarchy-herd php which` and `command -v php` |
| `php` is `/usr/bin/php` or "command not found" | The site's pinned version isn't installed, so the shim fell back to the system PHP. `omarchy-herd php install <version>` |
| You use zsh or fish | Setup only edits `~/.bashrc`. Add `~/.local/share/omarchy-herd/bin` to the front of `PATH` in your shell's config |
| A database won't start | `omarchy-herd logs mariadb` (or `postgres`, `valkey`). Usually the port is taken, see [Port conflicts](#port-conflicts) |
| PostgreSQL won't start after a system update | A major PostgreSQL upgrade needs the data migrated. See [Databases](Databases#backups-and-major-upgrades) |
| `Can't connect to local server through socket` | The client used `localhost`, which means the system socket. Connect with `-h 127.0.0.1` |
| `.test` names don't resolve | See [DNS](#dns) |
| "another omarchy-herd command is still running" | A change (often a PHP download) holds the lock. Wait, or find it with `pgrep -af omarchy-herd` |
| The dashboard says an action stopped without a result | `journalctl --user -u omarchy-herd-task-<id>` with the id from the message |
| The bar icon is red | Hover it: the tooltip lists the problems. Or open the panel |
| Bar widget changes don't show up | QML is only reloaded by `omarchy restart shell` |

## Diagnostic commands

### Services

```bash
# System services (web server and DNS)
systemctl status omarchy-herd-caddy omarchy-herd-dns
journalctl -u omarchy-herd-caddy -n 50
journalctl -u omarchy-herd-dns -n 50

# User services (PHP, databases, watcher)
systemctl --user list-units 'omarchy-herd-*' --all
systemctl --user status omarchy-herd-php@8.4
journalctl --user -u omarchy-herd-mariadb -n 50
```

### DNS

```bash
resolvectl status herd0        # should show DNS Servers: 127.0.0.153 and DNS Domain: ~test
resolvectl query herd.test     # should answer 127.0.0.1 (and ::1) via herd0
nmcli connection show omarchy-herd
```

If `herd0` is missing or down, bring it back with:

```bash
nmcli connection up omarchy-herd
```

or re-apply the whole root part with `omarchy-herd setup --system`.

If `resolvectl query` works but the browser doesn't resolve `.test`, the browser may be using its own DNS-over-HTTPS resolver. Turn off "secure DNS" in its settings, or add an exception.

### Web server

```bash
cat ~/.local/share/omarchy-herd/etc/Caddyfile     # what Caddy is serving
omarchy-herd logs caddy
curl -v https://herd.test                         # TLS, DNS and Caddy in one go
```

If Caddy rejected a config change, the command that made the change says so with Caddy's error, and Caddy keeps serving the previous config. The rejected Caddyfile is still on disk, though, so Caddy won't start again after a restart until you fix the cause and run `omarchy-herd apply`.

### PHP

```bash
omarchy-herd php list
cat ~/.local/share/omarchy-herd/etc/php-map       # which folder uses which version
omarchy-herd logs php-8.4                         # PHP errors from sites
cat ~/.local/share/omarchy-herd/log/php-8.4-fpm.log
```

## Port conflicts

omarchy-herd needs these ports:

| Port | Address | Used by |
|---|---|---|
| 80, 443 | `127.0.0.1`, `::1` | Caddy |
| 53 | `127.0.0.153` | dnsmasq |
| 3306 | `127.0.0.1` | MariaDB |
| 5432 | `127.0.0.1` | PostgreSQL |
| 6379 | `127.0.0.1` | Valkey |

Find what holds a port:

```bash
sudo ss -ltnp 'sport = :443'
sudo ss -ltnp 'sport = :3306'
```

Typical culprits are a system `nginx`, `apache` or `caddy` service, the Arch `mariadb`, `postgresql` or `valkey`/`redis` system services, or Docker containers publishing those ports. Stop and disable the other service (for example `sudo systemctl disable --now mariadb`), then `omarchy-herd start mariadb`.

## Starting over

To rebuild everything but keep your data:

```bash
omarchy-herd uninstall
~/Work/omarchy-herd/install.sh
```

To start completely fresh, including deleting all databases:

```bash
omarchy-herd uninstall --purge
~/Work/omarchy-herd/install.sh
```

## Still stuck

Open an issue with the output of `omarchy-herd doctor` and `omarchy-herd status`, and the relevant log. Remove anything private first.
