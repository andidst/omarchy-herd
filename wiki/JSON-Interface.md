# JSON interface

Add `--json` to a command and it prints exactly one JSON value on stdout, with progress messages suppressed. The dashboard (`dashboard/api.php`) and the bar widget (`plugin/Service.qml`) use nothing else to talk to omarchy-herd, which makes this the project's API.

> **For contributors:** the dashboard and bar widget parse these shapes. Changes must stay backwards compatible (adding fields is fine; renaming, removing or changing the type of one isn't), or update both consumers in the same pull request.

## Actions

Commands that change something print one line:

```json
{"ok":true,"message":"Linked https://shop.test → /home/you/code/shop"}
```

and exit 0. The message is the same sentence the command prints without `--json`.

## Errors

Any failure prints

```json
{"ok":false,"error":"no site named 'shop'"}
```

and exits 1. This holds for list commands too, so always check `ok` before treating a result as data. Error JSON is written to the process's real stdout through file descriptor 3, which the CLI opens at start, so an error raised deep inside a helper that runs in a `$(…)` subshell still reaches the caller instead of being captured.

Some messages come from tools the CLI runs (curl, systemctl). They're still wrapped in the JSON error.

## Commands without JSON output

`help`, `version`, `doctor`, `logs` and `dashboard` print the same thing with or without `--json`. `node list` without `--json` prints mise's own table.

## `status`

The dashboard and the bar widget poll this.

```json
{
  "version": "0.1.0",
  "tld": "test",
  "dashboard": "https://herd.test",
  "web": {"caddy": true, "dns": true, "resolves": true, "https_trusted": true},
  "php": {
    "default": "8.4",
    "versions": [ /* same objects as `php list` */ ]
  },
  "node": {
    "default": "22",
    "versions": [ /* same objects as `node list` */ ]
  },
  "services": [ /* same objects as `services` */ ],
  "parked": ["/home/you/Work"],
  "sites": [ /* same objects as `sites` */ ]
}
```

| Field | Meaning |
|---|---|
| `web.caddy` | `omarchy-herd-caddy` system unit is active |
| `web.dns` | `omarchy-herd-dns` system unit is active |
| `web.resolves` | `herd.<tld>` resolves to `127.0.0.1` |
| `web.https_trusted` | the CA is installed in the system trust anchors |
| `php.default` | default PHP series, or `""` before one is installed |
| `node.default` | the version requested in mise's global config (`22`, `lts`, `latest`, …), or `""` |

[`plugin/sample-status.json`](https://github.com/andidst/omarchy-herd/blob/main/plugin/sample-status.json) is a complete example.

## `sites`

An array, sorted by name:

```json
{
  "name": "shop",
  "domain": "shop.test",
  "url": "https://shop.test",
  "path": "/home/you/Work/shop",
  "source": "parked",
  "proxy": null,
  "type": "laravel",
  "docroot": "/home/you/Work/shop/public",
  "php": "8.3",
  "php_installed": true,
  "isolated": true,
  "node": "22.11.0"
}
```

| Field | Values |
|---|---|
| `source` | `link`, `proxy` or `parked` |
| `type` | `laravel`, `php`, `node`, `static`, `unknown` or `proxy` |
| `path`, `docroot` | `null` for proxies |
| `proxy` | the target (`127.0.0.1:5173`) for proxies, otherwise `null` |
| `php` | the version the site uses (its pin, or the default); `null` for proxies |
| `php_installed` | whether that version is installed |
| `isolated` | whether the site has a pin |
| `node` | `mise current node` in the folder, or `null` |

## `php list`

```json
[{"version": "8.4", "patch": "8.4.23", "default": true, "running": true, "ini": "/home/you/.config/omarchy-herd/php/8.4/php.ini"}]
```

Sorted by version. `running` is whether that version's FPM unit is active.

## `php available`

```json
[{"version": "8.4", "latest": "8.4.23", "installed": "8.4.21"}]
```

One entry per series that has a build on the mirror, oldest first. `installed` is the installed patch, or `null`.

## `node list`

```json
[{"version": "22.11.0", "path": "/home/you/.local/share/mise/installs/node/22.11.0", "default": true}]
```

Newest first. `default` marks the version mise's global config resolves to. Never fails: if mise errors, the result is `[]`.

## `node available`

```json
[{"major": "22", "latest": "22.11.0", "lts": true, "installed": "22.9.0"}]
```

Newest major first, majors 18 and up. `major` is a string. `lts` is `true` for even majors. `installed` is an installed version of that major, or `null`.

## `services`

```json
[{
  "id": "mariadb",
  "name": "MariaDB",
  "version": "12.3.3",
  "installed": true,
  "running": true,
  "enabled": true,
  "host": "127.0.0.1",
  "port": 3306,
  "user": "root",
  "password": ""
}]
```

Always three entries, in the order `mariadb`, `postgres`, `valkey`. `version` is `null` when the binary isn't installed. `user` is `null` for Valkey. `enabled` means the unit starts at login, which is what `start` and `stop` toggle.

## Scripting examples

```bash
# Sites that use PHP 8.3
omarchy-herd sites --json | jq -r '.[] | select(.php == "8.3") | .domain'

# Fail a script if anything is down
omarchy-herd status --json | jq -e '.web.caddy and .web.dns and all(.services[]; .running or (.enabled | not))'

# Act and check the result
omarchy-herd start postgres --json | jq -e .ok >/dev/null || echo "PostgreSQL didn't start"
```
