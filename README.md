# omarchy-herd

A Laravel Herd–style local development environment for [Omarchy](https://omarchy.org), without Docker.

- **Sites on `.test` domains**: park a folder and every project in it becomes `https://<folder>.test`. Link single folders, or proxy a name to a dev server (Vite, Next.js).
- **PHP versions**: 8.0 – 8.5 from prebuilt [static-php-cli](https://static-php.dev) binaries, installed in seconds. A default version, plus per-site isolation. In the terminal, `php` (and Composer) follows the project you're in.
- **Node versions** through [mise](https://mise.jdx.dev), per site via `mise.local.toml`.
- **Databases**: MariaDB, PostgreSQL and Valkey (Redis) running natively as your user. Start and stop them without a password.
- **Visibility**: a browser dashboard at `https://herd.test` and an Omarchy bar widget.

## Install

```bash
git clone git@github.com:andidst/omarchy-herd.git ~/Work/omarchy-herd
~/Work/omarchy-herd/install.sh
```

Setup asks for your password once, to install packages and set up the always-on pieces (web server, `.test` DNS, HTTPS certificate authority). Everything else runs as your user.

## Everyday commands

```bash
omarchy-herd status                 # everything at a glance
omarchy-herd park ~/Work            # every folder in ~/Work → <folder>.test
omarchy-herd link shop ~/code/shop  # one folder → shop.test
omarchy-herd proxy app 5173         # app.test → Vite dev server
omarchy-herd php install 8.3
omarchy-herd isolate 8.3 shop       # shop.test uses PHP 8.3
omarchy-herd node use 20 shop       # shop uses Node 20
omarchy-herd start mariadb          # or postgres, valkey, databases, all
omarchy-herd doctor                 # check every piece
```

Run `omarchy-herd help` for the full list. Every command takes `--json`, which is what the dashboard and bar widget use.

### Database connections

| Database | Host | Port | User | Password |
|---|---|---|---|---|
| MariaDB (MySQL) | 127.0.0.1 | 3306 | root | *(empty)* |
| PostgreSQL | 127.0.0.1 | 5432 | postgres | *(empty)* |
| Valkey (Redis) | 127.0.0.1 | 6379 | – | – |

## How it works

| Piece | What runs | Where |
|---|---|---|
| Web server | Caddy as a system service running as you, bound to localhost on ports 80/443 | `/etc/systemd/system/omarchy-herd-caddy.service` |
| `.test` DNS | dnsmasq on `127.0.0.153`, reached through a dummy NetworkManager link (`herd0`) that routes only `~test` | `/etc/systemd/system/omarchy-herd-dns.service`, `/etc/omarchy-herd/dnsmasq.conf` |
| HTTPS | Caddy's local certificate authority, trusted system-wide and in Chrome's NSS database | `~/.local/share/caddy/pki` |
| PHP | One PHP-FPM user service per version | `omarchy-herd-php@<version>.service` |
| Databases | User services | `omarchy-herd-{mariadb,postgres,valkey}.service` |

Files:

- `~/.config/omarchy-herd/config.json`: parked folders, links, proxies, per-site PHP
- `~/.config/omarchy-herd/php/<version>/php.ini`: your PHP settings (never overwritten)
- `~/.local/share/omarchy-herd/`: PHP binaries, database data, sockets, logs, generated Caddyfile

The `.test` route lives on its own link, so `omarchy dns` (which rewrites the global resolver config) doesn't break it.

## Repository layout

- `bin/omarchy-herd`: the CLI entry point
- `lib/`: CLI modules (sites, PHP, Node, services, setup)
- `setup/root-setup.sh`: the one-time root part of setup
- `dashboard/`: the `herd.test` dashboard, served by omarchy-herd's own PHP
- `plugin/`: the Omarchy bar widget

## Limitations

- Prebuilt static PHP can't load extensions like Xdebug at runtime.
- MariaDB stands in for MySQL (Arch doesn't ship MySQL); it's compatible with Laravel's `mysql` and `mariadb` drivers.
