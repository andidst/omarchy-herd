# Security model

omarchy-herd is built for a **single-user development machine**: your laptop or desktop, used by you. It trades some isolation for convenience in the same places Herd, Valet and DBngin do. This page lists each trade-off so you can decide whether it fits.

## What it protects against

- **Other machines on your network.** Nothing omarchy-herd runs listens on a network interface.
- **Websites you visit.** A page on the internet can't drive the dashboard or read its data (see [The dashboard](#the-dashboard)).
- **Accidentally publishing secrets.** Dotfiles such as `.env` and `.git` are never served, and folders like `/`, your home folder and hidden folders can't be served at all.
- **Privilege creep.** Only one step runs as root, and nothing in your home folder is touched by root.

## What it doesn't protect against

- **Other programs you run.** Any process on the machine can connect to the databases without a password, reach your sites, and use the dashboard's API if it sends the right headers. That's the same as running the CLI, which any of your programs can do anyway.
- **Other user accounts.** Loopback ports aren't per-user. On a shared machine, another account could load your sites and the dashboard and connect to your databases. Don't use omarchy-herd on multi-user systems.
- **Malicious code in your projects.** PHP runs as you, with your permissions, like `php artisan serve` would.

## Network exposure

| Service | Address |
|---|---|
| Caddy | `127.0.0.1` and `::1`, ports 80 and 443; admin API on a Unix socket in your run folder |
| dnsmasq | `127.0.0.153:53`, answering only `*.test` |
| PHP-FPM | Unix sockets, mode `0600` (only you) |
| MariaDB | `127.0.0.1:3306`, plus a socket in your run folder |
| PostgreSQL | `127.0.0.1:5432`, plus a socket in your run folder |
| Valkey | `127.0.0.1:6379` |

## Databases

The databases have **no passwords**: MariaDB's `root` and PostgreSQL's `postgres` are superusers with empty passwords or `trust` authentication, like Herd and DBngin. Don't keep production data or real customer data in them.

## The dashboard

`https://herd.test` can change your setup: add sites, install PHP, start and stop services. It defends against other websites and DNS rebinding with these checks in `dashboard/api.php`:

- **Host:** requests must be addressed to `herd.test`. A rebinding attack that points some other name at `127.0.0.1` is refused.
- **Fetch metadata:** if the browser sends `Sec-Fetch-Site`, it must be `same-origin` or `none`.
- **Origin:** if the browser sends `Origin`, it must be `https://herd.test` or `http://herd.test`.
- **Custom header on every change:** changes must be `POST` requests with `X-Herd: 1`. Other origins can't send a custom header without a CORS preflight, which the API never approves.
- **Allow-listed arguments:** every value is checked against a strict pattern (site names, PHP and Node versions, service names, ports, and folder paths without quotes, backslashes, braces or newlines) before it's passed to the CLI. The CLI runs without a shell, as an argument array, and repeats its own validation.
- **Content Security Policy:** the page allows only its own nonce-tagged script and styles and same-origin requests, sends no referrer, and can't be framed (`frame-ancestors 'none'`, `X-Frame-Options: DENY`). The API's responses have a `default-src 'none'` policy and `X-Content-Type-Options: nosniff`.

Changes run as short-lived user services (`omarchy-herd-task-<id>`) that do exactly what the CLI command does. The dashboard has no extra powers, and less than the CLI: it can't uninstall omarchy-herd, delete database data or run arbitrary commands.

## The root step

`setup/root-setup.sh` runs once through `sudo` or `pkexec` (and again only when an upgrade changes the system pieces). It:

- refuses to run as root directly; it needs to know your real user from `SUDO_UID` or `PKEXEC_UID`,
- accepts only paths inside your home folder without spaces, quotes, `$`, backticks, backslashes, `%` or `..`, because it writes them into unit files,
- checks that every folder Caddy may write to is a real directory owned by you with no symlink anywhere in its path, so systemd can't be tricked into following a link elsewhere,
- never creates, changes, chowns or copies anything in your home folder; the CLI creates those folders as you beforehand,
- reads Caddy's CA certificate **as you** (`runuser`), so root never follows a path you control, then checks it really is a CA certificate before trusting it.

What it changes outside your home: the packages it installs, `/etc/omarchy-herd/`, two units in `/etc/systemd/system/`, one trust anchor and one NetworkManager connection. `omarchy-herd uninstall` removes all of them except the packages.

Caddy and dnsmasq run with strict systemd sandboxing. See [Architecture](Architecture#caddys-sandbox).

## The certificate authority

Setup makes your system and Chrome trust Caddy's local CA. Its private key is in `~/.local/share/caddy/pki/authorities/local/`. **Anything that can read that folder can issue certificates your browser trusts for any domain**, not just `.test`. It's protected by your home folder's permissions (setup creates `~/.local/share/caddy` with mode `700`).

This is the same trade-off Herd, Valet and mkcert make. `omarchy-herd uninstall` removes the trust; delete `~/.local/share/caddy` too if you won't reinstall.

## PHP downloads

PHP binaries come from static-php-cli's server, `dl.static-php.dev`, over HTTPS only (TLS 1.2 or newer). The project doesn't publish checksums or signatures, so the download can't be verified beyond TLS. omarchy-herd:

- extracts only the expected `php` and `php-fpm` files from each archive, refusing symlinks,
- checks the binary runs before installing it,
- records the SHA-256 of the binaries as downloaded (before decompressing them) in `~/.local/share/omarchy-herd/php/<version>/SHA256SUMS`, so you can compare later,
- decompresses the binaries with `upx` from the Arch repositories.

The databases, Caddy, dnsmasq and upx come from the Arch repositories, signed as usual.

## What gets served

Folder sites serve their `public/` folder if it exists, otherwise the project root. Any path segment starting with a dot gets a 404, except `/.well-known/`. Everything else in the document root is served, as with any static web server.

`park` and `link` refuse `/`, your home folder or anything above it, and hidden folders.

## Reporting a vulnerability

Please report security problems privately through GitHub: **Security → Report a vulnerability** on the repository. Don't open a public issue. See [SECURITY.md](https://github.com/andidst/omarchy-herd/blob/main/SECURITY.md).
