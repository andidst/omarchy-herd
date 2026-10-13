# FAQ

### Why not Docker (Sail, DDEV, Lando)?

Those are good tools, and the right choice when your team needs identical environments or services omarchy-herd doesn't offer. omarchy-herd is for the other case: you want sites to just work, with native speed, no containers to start, and files that stay plain files in your home folder. It's the Herd/Valet approach, for Omarchy.

The two can coexist if they don't fight over ports. See [Port conflicts](Troubleshooting#port-conflicts).

### Can I use Xdebug?

Not with the omarchy-herd PHP builds. They're statically linked and can't load extensions at runtime. Use Arch's PHP with the `xdebug` package for debugging sessions; see [PHP](PHP#no-xdebug).

### Can I add PHP extensions?

Only those compiled into the static builds. Run `php -m` to see them. If you need one that's missing, use the system PHP for that project's command-line work.

### Why MariaDB and not MySQL?

Arch doesn't package MySQL. MariaDB speaks the MySQL protocol and works with Laravel's `mysql` and `mariadb` drivers, and with most MySQL applications. If you depend on a MySQL-only feature, run MySQL separately on another port.

### Can I use a different TLD, like `.localhost` or `.dev`?

No. `.test` is fixed. It's reserved for testing ([RFC 6761](https://www.rfc-editor.org/rfc/rfc6761)), so it never collides with a real domain, and browsers don't force HTTPS on it the way they do for `.dev`. The DNS setup, the dashboard's host check and other pieces assume `.test`; changing `tld` in `config.json` breaks them.

### Does it work with Firefox?

Yes, after you import the certificate authority once; Firefox doesn't use the system or Chrome trust stores. See [Installation](Installation#browsers).

### Does it work on a multi-user machine?

It runs, but don't. Loopback ports are shared between users, so another account could reach your sites, dashboard and password-less databases. See [Security Model](Security-Model).

### Can I run another web server on ports 80 and 443?

Not on the same addresses. Caddy binds `127.0.0.1` and `::1` on ports 80 and 443. Another server on those ports conflicts with it if it binds all addresses (`0.0.0.0`, `::`) or loopback. Either stop the other server or move it to other ports, and [proxy](Sites#proxying) to it if you want a `.test` name for it.

### Can I use a different shell than bash?

Yes, but setup only adds the `php` shim's folder to `~/.bashrc`. For zsh, fish or others, put `~/.local/share/omarchy-herd/bin` at the front of `PATH` yourself.

### Does it work without Omarchy?

It's built for Omarchy. It relies on Arch packages, NetworkManager, systemd-resolved and mise, and the bar widget needs the Omarchy shell. Another Arch setup with the same pieces might work, but isn't supported.

### Does it work on ARM?

Not yet. It downloads `linux-x86_64` PHP builds.

### Can I serve sites to my phone or other devices?

No. Everything listens on loopback only, by design.

### Where do I change PHP settings like `memory_limit`?

In `~/.config/omarchy-herd/php/<version>/php.ini`, then `omarchy-herd restart php-<version>`. See [PHP](PHP#phpini).

### Is it affiliated with Laravel, Laravel Herd or Omarchy?

No. omarchy-herd is an independent community project. It borrows Herd's ideas and Omarchy's look, nothing else.
