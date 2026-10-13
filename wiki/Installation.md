# Installation

## Requirements

- Omarchy: Arch Linux with Hyprland, NetworkManager and systemd-resolved, set up the way Omarchy ships them
- An x86_64 machine (the PHP builds are `linux-x86_64` only)
- `jq`, `curl`, `mise` and `git`, which Omarchy already includes
- A user with `sudo` rights, for the one-time root step

Ports 80 and 443 on `127.0.0.1`/`::1`, and 3306, 5432 and 6379 on `127.0.0.1`, must be free. See [Troubleshooting](Troubleshooting#port-conflicts) if something else uses them.

## Install

```bash
git clone https://github.com/andidst/omarchy-herd.git ~/Work/omarchy-herd
~/Work/omarchy-herd/install.sh
```

You can clone anywhere. The services point at the clone's location, so keep it where it is afterwards. If you move it, run `install.sh` again from the new place.

### What `install.sh` does

1. Symlinks `bin/omarchy-herd` to `~/.local/bin/omarchy-herd`.
2. Symlinks `plugin/` to `~/.config/omarchy/plugins/andidst.herd`, rescans the shell's plugins and enables the bar widget in the right section of the bar (if it isn't enabled already).
3. Runs `omarchy-herd setup`.

### What `omarchy-herd setup` does

Setup runs as you. Only one part, `setup/root-setup.sh`, runs as root, through `sudo` in a terminal or `pkexec` (a graphical password prompt) otherwise.

**As you:**

- Creates `~/.config/omarchy-herd/config.json` and links the dashboard as `herd.test`.
- Parks `~/Work` if it exists and nothing is parked yet.
- Writes the user systemd units for PHP-FPM, MariaDB, PostgreSQL and Valkey to `~/.config/systemd/user/`.
- Writes the project-aware `php` shim to `~/.local/share/omarchy-herd/bin/php`.
- Adds one `PATH` line to `~/.bashrc`, marked `# omarchy-herd: project-aware php`.
- Creates the folders Caddy will write to (`~/.local/share/caddy`, the run and log folders), so root never has to.
- Downloads PHP 8.4 if no PHP version is installed yet, and starts its PHP-FPM.
- Generates the Caddyfile and reloads Caddy.
- Adds Caddy's certificate authority to Chrome's NSS database (`~/.pki/nssdb`), when `certutil` is available.
- Starts MariaDB, PostgreSQL and Valkey, creating their data folders on first start.

**As root** (`setup/root-setup.sh`):

- Installs `caddy`, `dnsmasq`, `mariadb`, `postgresql`, `valkey` and `jq` with `pacman -S --needed`.
- Writes `/etc/omarchy-herd/dnsmasq.conf` and two sandboxed system services, `omarchy-herd-caddy` and `omarchy-herd-dns`, then starts them.
- Waits for Caddy to create its local certificate authority, reads it as you, checks it's a CA certificate and installs it to `/etc/ca-certificates/trust-source/anchors/omarchy-herd.crt` (then `update-ca-trust`).
- Creates the `omarchy-herd` NetworkManager connection (a dummy `herd0` link) that routes `.test` lookups to dnsmasq.
- Records the setup version in `/etc/omarchy-herd/setup-version`.

The root step never creates, changes or copies anything in your home folder. [Security Model](Security-Model#the-root-step) has the details, and [Architecture](Architecture) explains each piece.

## Check it

```bash
omarchy-herd doctor
```

`doctor` checks that every required command is installed, Caddy and DNS are running, `herd.test` resolves to `127.0.0.1`, the certificate authority is trusted, the dashboard answers over HTTPS, a new interactive bash finds the `php` shim first, and every installed PHP version's FPM is running. It exits with status 1 if anything fails.

Open a new terminal afterwards so the `PATH` change applies.

## Browsers

| Browser | What to do |
|---|---|
| Chrome, Chromium and other browsers that use NSS | Restart the browser once. Setup added the CA to `~/.pki/nssdb`. |
| Firefox | Firefox keeps its own certificate store. Open Settings → Privacy & Security → Certificates → View Certificates → Authorities → Import, choose `~/.local/share/caddy/pki/authorities/local/root.crt` and tick "Trust this CA to identify websites". |
| curl, PHP, Node and other command-line tools | Nothing; they use the system trust store, which setup updated. |

## Upgrade

```bash
git -C ~/Work/omarchy-herd pull
omarchy-herd setup
```

`setup` is safe to re-run. It rewrites the user units, the `php` shim, the FPM configs and the Caddyfile, and leaves your `config.json`, `php.ini` files and database data alone.

It only asks for your password again when the root-owned pieces need to change. That happens when:

- a required command (`caddy`, `dnsmasq`, `mariadbd`, `postgres`, `valkey-server`, `jq`, `curl`, `mise`) is missing,
- one of the system units isn't enabled,
- the trusted CA file is missing, or
- `/etc/omarchy-herd/setup-version` doesn't match the version this checkout expects (a release that changed the system units bumps it).

To re-apply the root part by hand, for example after a manual change broke it:

```bash
omarchy-herd setup --system
```

## Uninstall

```bash
omarchy-herd uninstall
```

This stops and disables every omarchy-herd service, removes the user units, the system units, `/etc/omarchy-herd`, the `herd0` connection, the system-wide CA trust and the Chrome NSS entry, the `PATH` lines in `~/.bashrc`, the bar widget and the `~/.local/bin/omarchy-herd` link. It asks for your password once for the root part.

Your PHP builds, `php.ini` files and database data stay in `~/.local/share/omarchy-herd` and `~/.config/omarchy-herd`, so a later install picks them up again.

To delete those too:

```bash
omarchy-herd uninstall --purge          # asks you to type "delete"
omarchy-herd uninstall --purge --yes    # no prompt, for scripts
```

`--purge` deletes **all database data**. Without a terminal it refuses to run unless you add `--yes`.

What stays behind either way:

- The Arch packages. Remove them with `sudo pacman -Rns caddy dnsmasq mariadb postgresql valkey`.
- Caddy's own data in `~/.local/share/caddy`, including the CA's private key. Delete that folder if you don't plan to reinstall.
- The `mise.local.toml` files that `omarchy-herd node use` wrote into your projects.
