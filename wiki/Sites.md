# Sites

A site is a folder (or a dev server) answering at `<name>.test`. There are three ways to add one.

| Kind | Command | What it serves |
|---|---|---|
| Parked folder | `omarchy-herd park ~/Work` | Every folder directly inside `~/Work`, each as `<folder>.test` |
| Link | `omarchy-herd link shop ~/code/shop` | One folder, anywhere, as `shop.test` |
| Proxy | `omarchy-herd proxy app 5173` | Whatever listens on that port, as `app.test` |

Every site answers on both `http://` and `https://`. Plain HTTP isn't redirected to HTTPS.

## Parking

```bash
omarchy-herd park              # park the current folder
omarchy-herd park ~/Work
omarchy-herd unpark ~/Work
```

A parked folder is the Herd and Valet idea: put projects in one place and each gets a domain without further commands. Only folders **directly** inside a parked folder become sites; `~/Work/clients/acme` doesn't, unless you park `~/Work/clients` too.

New and removed folders are picked up automatically. A systemd path unit (`omarchy-herd-watch.path`) watches each parked folder and runs `omarchy-herd apply` when its contents change, so a freshly cloned project gets its domain within a second or two. It only watches the top level of each parked folder. If a domain doesn't appear, run `omarchy-herd apply`.

## Linking

```bash
omarchy-herd link                   # current folder, named after it
omarchy-herd link shop              # current folder as shop.test
omarchy-herd link shop ~/code/shop
omarchy-herd unlink shop
omarchy-herd unlink                 # the link named after the current folder
```

Use a link for a project outside your parked folders, or to give a project a different name. Unlinking also drops the site's PHP pin.

## Proxying

```bash
omarchy-herd proxy app 5173                  # https://app.test → 127.0.0.1:5173
omarchy-herd proxy api 10.0.0.5:8080
omarchy-herd proxy api https://localhost:8443
omarchy-herd unproxy app
```

The target is a port (meaning `127.0.0.1:<port>`), or `host:port` with an optional `http://` or `https://` in front. Caddy forwards the original `Host` header (`app.test`), which some dev servers check. See [Recipes](Recipes#proxy-a-vite-or-other-dev-server).

Proxies have no PHP version, no Node version and no access log.

## Names

Folder and link names are turned into DNS-safe names:

1. lowercased,
2. every character other than `a-z`, `0-9` and `-` becomes `-`,
3. runs of `-` collapse to one,
4. leading and trailing `-` are removed.

So `My_Shop v2` becomes `my-shop-v2.test`. Link and proxy names must then be 1–63 characters, starting and ending with a letter or digit.

If two sources claim the same name, the first wins in this order: **links**, then **proxies**, then **parked folders** (sorted by path, so `/home/you/Code/shop` beats `/home/you/Work/shop`). Linking or proxying a name removes any proxy or link of that name, so a name is never both.

`herd` is the dashboard's link. If you remove it, `omarchy-herd setup` adds it back.

## Document root

If the project has a `public/` folder (Laravel, Symfony and most frameworks), that's the document root. Otherwise the project folder itself is.

Requests for files that exist are served as static files. Everything else goes to `index.php` through PHP-FPM, using Caddy's [`php_fastcgi`](https://caddyserver.com/docs/caddyfile/directives/php_fastcgi) defaults, so pretty URLs work without configuration.

### Hidden files

Any path with a segment starting with `.` (for example `/.env`, `/.git/config`, `/assets/.DS_Store`) gets a 404, except under `/.well-known/`. This protects projects served from their root, where `.env` would otherwise be downloadable.

Everything else in the document root is served, as with any static web server. If a project keeps secrets in non-dotfiles at its root, give it a `public/` folder.

## Site types

`omarchy-herd sites` and the dashboard label each site by what's in its folder:

| Type | Detected by |
|---|---|
| `laravel` | an `artisan` file |
| `php` | `composer.json`, `index.php` or `public/index.php` |
| `node` | `package.json` |
| `static` | `index.html` or `public/index.html` |
| `unknown` | none of the above |
| `proxy` | a proxy |

The type is only a label. Every non-proxy site is configured the same way.

## Folders that can't be sites

To avoid publishing more than you meant to, `park` and `link` refuse:

- `/`
- your home folder, or any folder that contains it
- hidden folders, or anything inside one (any path segment starting with `.`, such as `~/.config`)
- paths containing `"`, `\`, `{`, `}` or control characters, because they end up in the generated Caddyfile

Paths are resolved through symlinks first, so the checks apply to the real location.

Folders under `/tmp` can be parked, but their sites won't work: the web server runs with a private `/tmp`.

## Listing and opening

```bash
omarchy-herd sites           # SITE, TYPE, PHP/PROXY, NODE, PATH
omarchy-herd open            # the site you're in
omarchy-herd open shop
```

## Logs

Each folder site writes an access log (Caddy's JSON format) to `~/.local/share/omarchy-herd/log/sites/<name>.log`:

```bash
omarchy-herd logs shop
```

PHP errors go to the PHP version's log instead: `omarchy-herd logs php-8.4`. See [PHP](PHP#logs).

## Behind the scenes

Every change rewrites `~/.local/share/omarchy-herd/etc/Caddyfile` and reloads Caddy, which keeps open connections. Don't edit that file; the next change overwrites it. [Architecture](Architecture#generated-files) shows what it contains.
