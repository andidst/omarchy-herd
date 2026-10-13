# CLI reference

```
omarchy-herd <command> [arguments] [--json]
```

`--json` can go anywhere on the line. See [JSON Interface](JSON-Interface).

Where a command takes an optional `[site]`, leaving it out means the site whose folder contains your current directory. Where it takes an optional `[dir]`, leaving it out means the current directory.

## Sites

| Command | What it does |
|---|---|
| `park [dir]` | Serve every folder directly inside `dir` as `<folder>.test` |
| `unpark [dir]` | Stop serving a parked folder |
| `link [name] [dir]` | Serve `dir` as `<name>.test`. `name` defaults to the folder's name |
| `unlink [name]` | Remove a link. `name` defaults to the current folder's name. Also drops the site's PHP pin |
| `proxy <name> <port\|host:port>` | Send `<name>.test` to a server. A bare port means `127.0.0.1:<port>`; `http://` or `https://` in front of `host:port` is allowed |
| `unproxy <name>` | Remove a proxy |
| `sites` | List every site: domain, type, PHP version or proxy target, Node version, folder. Alias: `links` |
| `open [site]` | Open the site in your browser |
| `isolate <php-version> [site]` | Pin a site to an installed PHP version |
| `unisolate [site]` | Use the default PHP for that site again |
| `apply` | Regenerate the Caddyfile and php map from `config.json` and reload Caddy. The folder watcher runs this |

Details: [Sites](Sites).

## PHP

| Command | Aliases | What it does |
|---|---|---|
| `php list` | `php ls`, `php` | Installed versions with patch release, default and FPM state |
| `php available` | | Every series with its newest patch on the mirror, and what you have |
| `php install <8.x>` | `php add` | Download the newest patch of a series and start its FPM |
| `php update [8.x]` | | Update one or all installed versions to the newest patch |
| `php default <8.x>` | `php use` | Make an installed version the default |
| `php uninstall <8.x>` | `php remove` | Remove a version (not the default, not one a site is pinned to) |
| `php which` | | Print the PHP version `php` would use in the current directory |

Versions are series: `8.0` to `8.5`. Details: [PHP](PHP).

## Node

| Command | Aliases | What it does |
|---|---|---|
| `node list` | `node ls`, `node` | Installed versions (from mise) |
| `node available` | | Newest release of each major line from 18 up |
| `node install <version>` | `node add` | Install through mise. `22`, `22.11`, `22.11.0`, `lts` or `latest` |
| `node uninstall <x.y.z>` | `node remove` | Remove an exact installed version |
| `node default <version>` | | Set the global mise default |
| `node use <version> [site]` | `node isolate` | Pin a site in its `mise.local.toml` |
| `node reset [site]` | `node unisolate` | Remove the site's pin |

Details: [Node](Node).

## Databases and services

| Command | What it does |
|---|---|
| `services` | MariaDB, PostgreSQL and Valkey: status, address, user, version |
| `start [service]` | Start and enable |
| `stop [service]` | Stop and disable, so it stays stopped after the next login |
| `restart [service]` | Restart and enable |
| `logs <service\|site>` | Follow a log (last 200 lines, then live) |

Services for `start`, `stop` and `restart`:

| Name | Aliases | Means |
|---|---|---|
| `mariadb` | `mysql` | MariaDB |
| `postgres` | `postgresql`, `pgsql` | PostgreSQL |
| `valkey` | `redis` | Valkey |
| `php-<version>` | | That version's PHP-FPM, e.g. `php-8.4` |
| `databases` | `dbs` | All three databases |
| `all` | *(none given)* | All three databases and every installed PHP-FPM |

`logs` accepts `caddy`, `mariadb` (or `mysql`), `postgres` (from the journal), `valkey` (or `redis`), `php-<version>` (PHP's error log) or a site name (its access log).

Details: [Databases](Databases).

## Setup and status

| Command | What it does |
|---|---|
| `setup` | First-time setup, and safe to re-run after an upgrade. Asks for your password when the root-owned parts need (re)applying |
| `setup --system` | Re-apply the root-owned parts even if they look current |
| `uninstall` | Remove services, DNS route, CA trust, `PATH` line, bar widget and CLI link. Keeps data |
| `uninstall --purge` | Also delete PHP builds, settings, cache and all database data. Asks you to type `delete` |
| `uninstall --purge --yes` | Same, without asking (`-y` works too). Required when there's no terminal |
| `status` | Everything at a glance: web, PHP, Node, services, parked folders, sites |
| `doctor` | Check every piece and say which one fails |
| `dashboard` | Open https://herd.test |
| `help` | Usage. Also `-h`, `--help`, or no command |
| `version` | Print the version. Also `--version` |

Details: [Installation](Installation).

## Locking

Commands that change something wait for a lock (`~/.local/share/omarchy-herd/run/lock`), so the dashboard, the bar widget, the folder watcher and your terminal can't change the configuration at the same time. They wait up to 120 seconds, then fail with "another omarchy-herd command is still running".

These take the lock: `park`, `unpark`, `link`, `unlink`, `proxy`, `unproxy`, `isolate`, `unisolate`, `start`, `stop`, `restart`, `apply`, `setup`, and every `php` and `node` subcommand except `list`, `ls`, `available` and `which`.

Everything else (`status`, `sites`, `services`, `doctor`, `open`, `logs`, …) reads without waiting, so it stays instant while, say, a PHP download is running.

## Exit status

| Status | Meaning |
|---|---|
| `0` | Success |
| `1` | The command failed; the reason is on stderr, or in the JSON error with `--json`. `doctor` also exits 1 when any check fails |

Every command except `help`, `version`, `setup` and `uninstall` fails with `not set up yet; run: omarchy-herd setup` until setup has created `~/.config/omarchy-herd/config.json`.

## Environment

| Variable | Effect |
|---|---|
| `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME` | Move the config, data and cache folders. Set them the same way for your session and services, or the pieces won't find each other |
| `HERD_PHP_VERSION` | Read by the `php` shim only: force a PHP version for that command |
