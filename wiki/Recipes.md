# Recipes

These assume `~/Work` is parked (setup parks it if it exists).

## A new Laravel app

```bash
cd ~/Work
composer create-project laravel/laravel shop
```

`https://shop.test` works as soon as the folder exists: the watcher notices it and the `public/` folder becomes the document root. Composer and `php artisan` run with the default PHP, through the [`php` shim](PHP#php-in-the-terminal).

If you use the Laravel installer (`laravel new shop`), the same applies.

### With MariaDB

```bash
mariadb -h 127.0.0.1 -u root -e 'CREATE DATABASE shop'
```

In `shop/.env`:

```dotenv
DB_CONNECTION=mariadb
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=shop
DB_USERNAME=root
DB_PASSWORD=
```

### With PostgreSQL

```bash
createdb -h 127.0.0.1 -U postgres shop
```

```dotenv
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=shop
DB_USERNAME=postgres
DB_PASSWORD=
```

Then:

```bash
cd ~/Work/shop
php artisan migrate
omarchy-herd open
```

Laravel's defaults use SQLite, which needs no server at all: the PHP builds include `pdo_sqlite`.

Set `APP_URL=https://shop.test` so generated links use the right domain.

## An old project on an older PHP and Node

```bash
omarchy-herd php install 8.1
omarchy-herd node install 16           # mise can install it, even though `node available` lists 18 and up
cd ~/Work/legacy
omarchy-herd isolate 8.1               # legacy.test and `php` in this folder use 8.1
omarchy-herd node use 16               # writes mise.local.toml
composer install
npm install
```

Check with `omarchy-herd sites` or `omarchy-herd php which`.

## A project outside `~/Work`

```bash
omarchy-herd link client-site ~/Clients/acme/website
```

## Proxy a Vite or other dev server

To reach a dev server on a `.test` domain with HTTPS:

```bash
omarchy-herd proxy app 5173
npm run dev
```

Caddy forwards the original `Host` header, `app.test`. Recent Vite versions (6.0.9 and later, and the matching 5.4 and 4.5 security releases) reject requests for host names they don't know, with an error saying the host is not allowed. Allow `.test` in `vite.config.js`:

```js
export default defineConfig({
  server: {
    allowedHosts: ['.test'],
  },
})
```

A leading dot allows the domain and all its subdomains. Other dev servers (webpack-dev-server, Angular, and so on) have similar host checks; look for an "allowed hosts" option.

Caddy proxies WebSockets, so hot reloading normally works through the proxy too. If it doesn't, check your dev server's documentation for setting the client-side HMR host or port (the browser should connect to `app.test` on port 443).

### Laravel with Vite

A Laravel project usually doesn't need a proxy for Vite. Serve the app at `https://shop.test` as usual and run `npm run dev`; the page loads assets straight from the Vite dev server, whose address Laravel's Vite plugin writes to `public/hot`.

If the assets don't load, the browser console says why, usually CORS. Set `APP_URL=https://shop.test` in `.env` and make sure `laravel-vite-plugin` is up to date, since newer releases allow the app's own URL by default.

## WordPress

```bash
cd ~/Work
curl -fsSLO https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz && rm latest.tar.gz
mv wordpress blog
mariadb -h 127.0.0.1 -u root -e 'CREATE DATABASE blog'
```

Open `https://blog.test` and use:

| Field | Value |
|---|---|
| Database name | `blog` |
| Username | `root` |
| Password | *(empty)* |
| Database host | `127.0.0.1` |

Use `127.0.0.1`, not `localhost`: with `localhost`, PHP looks for a MariaDB socket in its default location, where nothing is listening.

WordPress has no `public/` folder, so the project root is served. Dotfiles are hidden, but other files in the root are reachable as usual for WordPress.

## A plain static site

Any folder with an `index.html` in `~/Work` is a static site. If it has a `public/` folder, that's served instead.
