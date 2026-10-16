# Architecture

omarchy-herd is a Bash CLI that writes configuration files and drives systemd. Everything else, the dashboard and the bar widget included, calls that CLI.

## Components

| Piece | Runs as | Unit | Listens on |
|---|---|---|---|
| Caddy (web server, TLS, local CA) | you, via a sandboxed **system** service | `omarchy-herd-caddy.service` | `127.0.0.1` and `::1`, ports 80 and 443; admin API on a Unix socket |
| dnsmasq (`.test` DNS) | the `dnsmasq` user, system service | `omarchy-herd-dns.service` | `127.0.0.153:53` |
| PHP-FPM, one per version | you, **user** service | `omarchy-herd-php@<version>.service` | `~/.local/share/omarchy-herd/run/php-<version>.sock` |
| MariaDB | you, user service | `omarchy-herd-mariadb.service` | `127.0.0.1:3306` and a socket |
| PostgreSQL | you, user service | `omarchy-herd-postgres.service` | `127.0.0.1:5432` and a socket |
| Valkey | you, user service | `omarchy-herd-valkey.service` | `127.0.0.1:6379` |
| Folder watcher | you, user path unit | `omarchy-herd-watch.path` → `omarchy-herd-watch.service` | – |
| Dashboard tasks | you, transient user services | `omarchy-herd-task-<id>.service` | – |

Caddy is the only piece that needs privileges: binding ports 80 and 443. It gets exactly `CAP_NET_BIND_SERVICE` and runs as your user, so it can read your projects and connect to PHP-FPM's sockets, which are only open to you.

## Code layout

```
bin/omarchy-herd        entry point: argument parsing, --json, locking, dispatch
lib/common.sh           paths, config access, output helpers (ok/die/info), validation
lib/sites.sh            site discovery, Caddyfile and php-map generation, folder watcher
lib/php.sh              PHP downloads, php.ini, FPM configs, versioned wrappers
lib/node.sh             mise wrappers
lib/services.sh         user units for PHP-FPM and databases, start/stop, logs
lib/setup.sh            setup, the php shim, status, doctor
lib/uninstall.sh        uninstall
setup/root-setup.sh     the root half of setup
setup/root-uninstall.sh the root half of uninstall
dashboard/              index.php (page) and api.php (JSON API), plain PHP, no dependencies
plugin/                 the Omarchy bar widget (Quickshell/QML)
```

## The single source of truth

`~/.config/omarchy-herd/config.json` holds everything you've chosen:

```json
{
  "tld": "test",
  "php": {"default": "8.4"},
  "parked": ["/home/you/Work"],
  "links": {"herd": "/home/you/Work/omarchy-herd/dashboard", "shop": "/home/you/code/shop"},
  "proxies": {"app": "127.0.0.1:5173"},
  "isolated": {"legacy": "8.1"}
}
```

Every command that changes sites updates this file (atomically: write a temp file, then rename) and then runs `sites_apply`, which regenerates everything derived from it. The parked folders are listed afresh each time, so the set of sites is always what's on disk now.

Per-site Node versions are the exception: they live in each project's `mise.local.toml`, managed by mise.

## Generated files

`sites_apply` writes:

| File | Purpose |
|---|---|
| `~/.local/share/omarchy-herd/etc/Caddyfile` | One block per site. Folder sites get `root`, a 404 for dotfiles, compression, `php_fastcgi` to their version's socket, `file_server` and an access log. Proxies get `reverse_proxy`. Global options set `local_certs`, `default_bind 127.0.0.1 [::1]`, the admin socket and `auto_https disable_redirects` |
| `~/.local/share/omarchy-herd/etc/php-map` | `default<TAB>8.4`, then one `<folder><TAB><version>` line per folder site. The `php` shim reads it |
| `~/.config/systemd/user/omarchy-herd-watch.{path,service}` | `PathChanged=` for each parked folder; the service runs `omarchy-herd apply` |

Then it starts any installed PHP version a site uses, reloads Caddy through its admin socket (Caddy validates the new config first and keeps the old one if it's rejected), and updates the watcher. The watcher units are only rewritten and restarted when their content changed.

Other generated files:

| File | Written by | Purpose |
|---|---|---|
| `~/.config/systemd/user/omarchy-herd-{php@,mariadb,postgres,valkey}.service` | `setup` | User units |
| `~/.local/share/omarchy-herd/etc/php-fpm-<version>.conf` | `php install`, `setup` | FPM pool |
| `~/.local/share/omarchy-herd/etc/mariadb.cnf` | `setup` | MariaDB server and client config |
| `~/.local/share/omarchy-herd/bin/php` | `setup` | Project-aware `php` shim |
| `~/.local/share/omarchy-herd/bin/php<version>` | `php install`, `setup` | Versioned wrappers that set `PHPRC` |
| `~/.config/omarchy-herd/php/<version>/php.ini` | `php install`, once | Your PHP settings; never overwritten |

Files that readers might see mid-write (the php map, `VERSION`) are written to a sibling temp file and renamed into place.

## Setup flow

`omarchy-herd setup`:

1. Creates `config.json` if needed, takes the lock, links the dashboard as `herd`, parks `~/Work` on first run.
2. Writes the user units and the `php` shim, adds the `PATH` line to `~/.bashrc`.
3. If the system part is missing or outdated (or `--system` was given): generates a first Caddyfile, creates the folders Caddy will write to, and runs `setup/root-setup.sh` through `sudo` (in a terminal) or `pkexec`.
4. Installs PHP 8.4 if no version is installed; rewrites FPM configs and wrappers for every installed version.
5. Regenerates the Caddyfile and reloads Caddy.
6. Adds the CA to Chrome's NSS database.
7. Starts the databases.

### Versioning the root part

The root half only runs when it has to. `setup/root-setup.sh` has `SETUP_VERSION`, and writes it to `/etc/omarchy-herd/setup-version`. `lib/common.sh` has `HERD_SYSTEM_SETUP_VERSION`, the value this checkout expects. When they differ, `setup` runs the root half again.

**Contributors:** when you change anything `root-setup.sh` writes (units, sandbox, dnsmasq config, the NetworkManager connection), bump both numbers together, so existing installs pick the change up on their next `setup`.

## DNS routing

`.test` names have to resolve to `127.0.0.1` without touching the rest of your DNS.

1. dnsmasq listens only on `127.0.0.153`, reads no `/etc/hosts` or upstream servers, and answers every `*.test` name with `127.0.0.1` and `::1`.
2. A NetworkManager connection named `omarchy-herd` creates a dummy link, `herd0`, with address `192.0.2.53/32` (a documentation range, never routed), DNS server `127.0.0.153` and the route-only domain `~test`. It never becomes a default route.
3. systemd-resolved sends a query to the DNS servers of the link whose route-only domain matches it. So `.test` goes to dnsmasq, and nothing else does.

This is independent of the global DNS settings, which `omarchy dns` rewrites, so switching DNS providers in Omarchy can't break `.test`.

## HTTPS

Caddy runs its own certificate authority (`local_certs`) and issues a certificate for each site's `.test` name when it loads the config. The CA lives in `~/.local/share/caddy/pki/authorities/local/`. Setup trusts its root certificate:

- system-wide, in `/etc/ca-certificates/trust-source/anchors/omarchy-herd.crt` (curl, PHP, Node, most apps),
- in Chrome's NSS database (`~/.pki/nssdb`), named `omarchy-herd`.

Caddy's own trust-store installation is turned off (`skip_install_trust`); setup does it instead, in a controlled way.

## Caddy's sandbox

Both system units share these systemd hardening settings: `NoNewPrivileges`, `ProtectSystem=strict` (the whole OS read-only), `PrivateTmp`, `PrivateDevices`, the `ProtectKernel*`, `ProtectControlGroups`, `ProtectClock` and `ProtectHostname` options, `RestrictNamespaces`, `RestrictRealtime`, `RestrictSUIDSGID`, `LockPersonality`, `MemoryDenyWriteExecute`, `SystemCallArchitectures=native`, address families limited to Unix, IPv4, IPv6 and netlink, and a capability bounding set of `CAP_NET_BIND_SERVICE` only.

Caddy can write only to its data folder (`~/.local/share/caddy`), the run folder and the log folder (`ReadWritePaths`). dnsmasq additionally gets `ProtectHome=true`.

## Locking

State-changing commands take an exclusive `flock` on `~/.local/share/omarchy-herd/run/lock` and wait up to 120 seconds. Read-only commands don't, so `status` stays fast during long operations. See [CLI Reference](CLI-Reference#locking).

## Where everything lives

| Path | Contents |
|---|---|
| `~/.config/omarchy-herd/config.json` | Parked folders, links, proxies, pins, default PHP |
| `~/.config/omarchy-herd/php/<version>/php.ini` | Your PHP settings |
| `~/.local/share/omarchy-herd/php/<version>/` | `php`, `php-fpm`, `VERSION`, `SHA256SUMS` |
| `~/.local/share/omarchy-herd/bin/` | `php` shim and `php<version>` wrappers |
| `~/.local/share/omarchy-herd/etc/` | Caddyfile, php-map, FPM and MariaDB configs |
| `~/.local/share/omarchy-herd/data/` | Database data |
| `~/.local/share/omarchy-herd/run/` | Sockets, PID files, the lock, dashboard task results |
| `~/.local/share/omarchy-herd/log/` | Caddy, PHP, MariaDB and Valkey logs; `sites/<name>.log` |
| `~/.cache/omarchy-herd/` | Cached PHP mirror listing |
| `~/.local/share/caddy/` | Caddy's CA and issued certificates |
| `~/.pki/nssdb/` | Chrome's certificate database (shared with other NSS apps) |
| `~/.config/systemd/user/omarchy-herd-*` | User units |
| `/etc/systemd/system/omarchy-herd-{caddy,dns}.service` | System units |
| `/etc/omarchy-herd/` | `dnsmasq.conf`, `setup-version` |
| `/etc/ca-certificates/trust-source/anchors/omarchy-herd.crt` | Trusted CA |
| NetworkManager connection `omarchy-herd` | The `herd0` DNS route |
| `~/.local/bin/omarchy-herd` | Symlink to the CLI |
| `~/.config/omarchy/plugins/andidst.herd` | Symlink to the bar widget |
