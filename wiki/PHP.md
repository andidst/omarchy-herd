# PHP

omarchy-herd installs PHP 8.0, 8.1, 8.2, 8.3, 8.4 and 8.5 side by side. Each installed version runs its own PHP-FPM, and every site uses either the default version or the one you pinned it to.

![PHP versions](https://github.com/andidst/omarchy-herd/raw/main/docs/dashboard-php.png)

## Where the builds come from

The binaries are prebuilt static builds from [static-php-cli](https://static-php.dev), downloaded over HTTPS from `dl.static-php.dev`. Herd uses static-php-cli builds too. Each one is a single self-contained `php` and `php-fpm` with the common extensions compiled in, including `pdo_mysql`, `pdo_pgsql`, `pdo_sqlite`, `intl`, `gd`, `redis` and `opcache`. There's nothing to compile and nothing from the Arch repositories involved.

Run `php -m` inside a project to see the full extension list for that version.

static-php-cli publishes no checksums or signatures. omarchy-herd records the SHA-256 of what it installed in `~/.local/share/omarchy-herd/php/<version>/SHA256SUMS`, so you can compare later.

## Installing and updating

```bash
omarchy-herd php available       # VERSION, LATEST, INSTALLED
omarchy-herd php install 8.3     # newest 8.3.x
omarchy-herd php list            # VERSION, PATCH, DEFAULT, FPM
omarchy-herd php update          # newest patch of every installed version
omarchy-herd php update 8.3      # just one
```

You install a series (`8.3`), and omarchy-herd picks the newest patch release (`8.3.x`) that has both a CLI and an FPM build on the mirror. The mirror listing is cached for six hours in `~/.cache/omarchy-herd/php-index.json`.

`install` on an already-current version doesn't download again; it rewrites the version's FPM config and wrapper and restarts it. Downloads retry a few times on flaky connections.

A new or updated binary is staged next to the installed versions and moved into place in one step, so a running `php` never sees a half-copied file. Before that, omarchy-herd checks the archive contains a real `php` and `php-fpm` (no symlinks) and that the binary runs on your machine.

The first version you install becomes the default.

## Default version

```bash
omarchy-herd php default 8.4
```

The default is used by every site without a pin, and by `php` in the terminal outside any site.

## Pinning a site

```bash
omarchy-herd isolate 8.2 legacy   # legacy.test uses PHP 8.2
omarchy-herd isolate 8.2          # the site you're in
omarchy-herd unisolate legacy     # back to the default
```

The version must be installed first. Pinning starts that version's FPM if it isn't running.

## `php` in the terminal

Setup puts `~/.local/share/omarchy-herd/bin` first on your `PATH`. The `php` there is a small shim that picks a version in this order:

1. `$HERD_PHP_VERSION`, if set: `HERD_PHP_VERSION=8.2 php -v`
2. the site whose folder contains your current directory (the deepest match wins, so a linked folder inside a parked one uses its own pin)
3. the default version

If the chosen version isn't installed, or omarchy-herd has no config yet, the shim runs `/usr/bin/php` instead.

The shim reads `~/.local/share/omarchy-herd/etc/php-map`, a tab-separated list of site folders and their versions that omarchy-herd rewrites on every change. It doesn't start the CLI, so `php` stays as fast as calling the binary directly.

Anything that runs PHP through `PATH` follows the same rules. That includes Composer and `artisan` when their first line is `#!/usr/bin/env php`. omarchy-herd doesn't install Composer itself.

To run a specific version regardless of where you are:

```bash
php8.3 -v
```

There's one `php<version>` command per installed version.

```bash
omarchy-herd php which     # the version php would use here
```

## `php.ini`

Each version has its own file, used by both the CLI and FPM:

```
~/.config/omarchy-herd/php/<version>/php.ini
```

omarchy-herd creates it the first time you install that version and never overwrites it. The generated defaults:

| Setting | Value |
|---|---|
| `memory_limit` | `512M` |
| `upload_max_filesize`, `post_max_size` | `128M` |
| `max_execution_time` | `120` |
| `date.timezone` | your system time zone (`UTC` if it can't be read) |
| `display_errors`, `display_startup_errors`, `log_errors` | `On` |
| `error_reporting` | `E_ALL` |
| `opcache.enable` | `1` (`opcache.enable_cli = 0`) |
| `opcache.validate_timestamps`, `opcache.revalidate_freq` | `1`, `0`: code changes show up on the next request |
| `zend.assertions` | `1` |
| `openssl.cafile`, `curl.cainfo` | `/etc/ssl/certs/ca-certificates.crt` (static builds don't know Arch's CA bundle path) |

Apply changes to sites with:

```bash
omarchy-herd restart php-8.4
```

The CLI picks changes up immediately.

Uninstalling a version keeps its `php.ini`, so reinstalling restores your settings. To go back to the defaults, delete the file and run `omarchy-herd php install <version>`.

## PHP-FPM

Each version runs as a user service, `omarchy-herd-php@<version>.service`, listening on `~/.local/share/omarchy-herd/run/php-<version>.sock` (mode `0600`, so only you can connect). The pool is generated in `~/.local/share/omarchy-herd/etc/php-fpm-<version>.conf`:

| Setting | Value |
|---|---|
| `pm` | `ondemand`: no workers until a request arrives |
| `pm.max_children` | `16` |
| `pm.process_idle_timeout` | `60s` |
| `pm.max_requests` | `500` |
| `clear_env` | `no`: your environment variables reach PHP |

That file is regenerated on install and setup. Put settings in `php.ini` instead.

Every version a site points at is started whenever omarchy-herd regenerates the site configuration. So if you `omarchy-herd stop php-8.4` while sites use it, the next `apply` (including the automatic one when a folder appears in a parked directory) starts it again.

## Logs

| File | Contents |
|---|---|
| `~/.local/share/omarchy-herd/log/php-<version>-errors.log` | PHP errors from your sites (`omarchy-herd logs php-<version>`) |
| `~/.local/share/omarchy-herd/log/php-<version>-fpm.log` | PHP-FPM's own log: pool start, worker crashes |

## Removing a version

```bash
omarchy-herd php uninstall 8.2
```

You can't remove the default version, or one that an existing site is pinned to. Pins left behind by deleted projects are dropped. The binaries, wrapper and FPM config go; `php.ini` stays.

## No Xdebug

Static PHP builds can't load extensions at runtime, so there's no Xdebug, PCOV or other `.so` extension. For step debugging, use Arch's PHP for that session:

```bash
sudo pacman -S php xdebug
/usr/bin/php -dzend_extension=xdebug.so artisan test
```

Arch's `xdebug` package ships an ini file you can enable instead of passing `-d` each time; check `/etc/php/conf.d/xdebug.ini`. Sites served by omarchy-herd keep using the static builds.
