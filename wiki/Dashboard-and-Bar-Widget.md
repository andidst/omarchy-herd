# Dashboard and bar widget

Both are front ends to the same CLI: every button runs an `omarchy-herd … --json` command, so the terminal, the dashboard and the bar always agree.

## Dashboard

Open **https://herd.test**, or run `omarchy-herd dashboard`, or right-click the bar icon.

The header shows three health chips: **Web server** (Caddy), **.test DNS** (dnsmasq running and `herd.test` resolving) and **HTTPS** (the CA is trusted system-wide). The page refreshes itself every 10 seconds while it's visible and nothing is running. The URL fragment remembers the tab (`https://herd.test/#php`).

### Sites

![Sites tab](https://github.com/andidst/omarchy-herd/raw/main/docs/dashboard-sites.png)

- **Add:** park a folder, link one folder under a name, or proxy a name to a port. `~` in a folder path means your home folder.
- **Sites table:** each site's domain (opens it), type, PHP and Node version, and folder (click to copy the path).
  - The **PHP** menu pins the site to an installed version, or back to the default. A *missing* badge means the site is pinned to a version that isn't installed.
  - The **Node** menu writes the site's `mise.local.toml`, or resets it with *use default*.
  - **Unlink** and **Remove** delete links and proxies. Parked sites have no button; unpark the folder or move the project out of it. The dashboard's own `herd.test` link can't be removed from here.
- **Parked folders:** each with a × to unpark it.

### PHP

![PHP tab](https://github.com/andidst/omarchy-herd/raw/main/docs/dashboard-php.png)

One card per PHP series, newest first. Installed versions show the patch release, how many sites use it, whether FPM is running, and the path to its `php.ini` (click to copy). Buttons: **Make default**, **Start**/**Restart**, **Update** (when a newer patch exists) and **Remove**. Versions that aren't installed have an **Install** button.

### Node

Installed Node versions (with **Make default** and **Remove**) and the newest release of each major line (with **Install** or **Update**).

### Databases

![Databases tab](https://github.com/andidst/omarchy-herd/raw/main/docs/dashboard-databases.png)

One card per database with its status, version and connection details, and a Laravel `.env` snippet you can click to copy. Buttons: **Start**, **Stop** and **Restart**.

### Theme

The dashboard reads your current Omarchy theme's colors from `~/.local/state/omarchy/current/theme/colors.toml` on every page load, so it follows theme changes after a reload. If the file is missing it falls back to Tokyo Night colors.

### How changes run

Reads (status, available PHP and Node versions) run the CLI inline.

Changes run as **background tasks**: the dashboard starts the CLI as its own transient user service (`systemd-run --user`, unit `omarchy-herd-task-<id>`) and returns at once. The page polls for the result every 0.7 seconds, for up to 15 minutes, and shows it as a toast.

This keeps a change running even when it restarts the PHP-FPM that serves the dashboard itself (switching the default PHP, for example), or when you close the tab. Results wait in `~/.local/share/omarchy-herd/run/tasks/` until the page collects them. Uncollected results older than an hour are deleted when the next task starts.

If a task dies without a result, the error names its unit. Read what happened with:

```bash
journalctl --user -u omarchy-herd-task-<id>
```

The dashboard refuses to **stop** the PHP version it runs on, since nothing would be left to start it again from the browser. Stop it from a terminal: `omarchy-herd stop php-8.4`.

Every request is validated before it reaches the CLI. [Security Model](Security-Model#the-dashboard) lists the checks.

## Bar widget

![Bar widget](https://github.com/andidst/omarchy-herd/raw/main/docs/bar-panel.png)

The Herd icon (󰟆) sits in the right section of the Omarchy bar. `install.sh` adds it; to add it by hand:

```bash
omarchy plugin enable andidst.herd --section right
```

### The icon

The icon uses the bar's normal color when everything is healthy, and the theme's alert color when:

- the CLI fails (for example before setup),
- Caddy or DNS is down, or `.test` doesn't resolve,
- a database that's enabled isn't running, or
- the default PHP version's FPM isn't running.

The tooltip reads `Herd: N sites`, followed by any problems.

| Mouse | Action |
|---|---|
| Left-click | Open or close the panel |
| Middle-click | Refresh |
| Right-click | Open the dashboard |

### The panel

The panel shows web, DNS and HTTPS status, the databases with start/stop switches, PHP and Node versions, and the `.test` sites.

- Click a database to start or stop it. The row shows a busy state while the command runs. Errors appear inline, or as a notification if you closed the panel.
- Click a site to open it in your browser.
- If the CLI fails, the panel shows the error and a hint (for example, to run `omarchy-herd setup`).

| Key | Action |
|---|---|
| `j` / `k`, arrow keys | Move between rows |
| `Enter` | Toggle the selected database, or open the selected site |
| `r` | Refresh |
| `d` | Open the dashboard |
| `Esc` | Close |
| `Tab` | Next bar panel |

### Refresh interval

The widget polls `omarchy-herd status --json` every 30 seconds, and every 5 seconds while the panel is open. Change the 30 in the widget's settings (**Bar refresh interval**, 10–3600 seconds).

### IPC

```bash
omarchy-shell andidst.herd toggle    # also: open, close, show, hide
omarchy-shell andidst.herd refresh
omarchy-shell andidst.herd status    # prints the tooltip text
```

Bind these to keys in Hyprland if you like, for example `omarchy-shell andidst.herd toggle`.

### Developing the widget

See [`plugin/README.md`](https://github.com/andidst/omarchy-herd/blob/main/plugin/README.md): how the files fit together, running it against `sample-status.json`, and why QML changes need `omarchy restart shell`.
