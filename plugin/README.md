# Herd bar widget (`andidst.herd`)

An Omarchy shell bar widget for omarchy-herd. The bar icon (󰟆, nf-md-elephant) shows overall
health. Clicking it opens a panel with web/DNS/HTTPS status, the databases (with
start/stop switches), PHP and Node versions, and the `.test` sites.

## Files

| File | What it does |
|---|---|
| `manifest.json` | Plugin manifest: id `andidst.herd`, kind `bar-widget`, entry point `Panel.qml`, `refreshIntervalSec` setting (default 30). |
| `Panel.qml` | Entry point. Contains the bar icon, the popup (`KeyboardPanel`), keyboard handling, IPC, and the row components. `statusCommand` near the top sets where the data comes from. |
| `Service.qml` | Runs the CLI. It polls `status --json` every 30 s, or every 5 s while the panel is open, and runs `start`/`stop` for the databases. |
| `Model.js` | Pure helpers: parsing CLI output, health/problem detection, row labels, reading the theme's green. |
| `sample-status.json` | Test data in the shape of `omarchy-herd status --json`. |

It uses the same shared pieces as the built-in panels (`qs.Ui` `Panel`, `BarIconButton`,
`KeyboardPanel`, `CursorSurface`, `ToggleSwitch`, `Button`, `PanelSectionHeader`, and the
`qs.Commons` `Style`/`Color` singletons), so it follows the current theme.

## Install

The plugin folder is symlinked into the shell's user plugin directory and placed on the bar
after `omarchy.agents`:

```bash
ln -s ~/Work/omarchy-herd/plugin ~/.config/omarchy/plugins/andidst.herd
omarchy-shell shell rescanPlugins
omarchy plugin enable andidst.herd --section right --after omarchy.agents
```

The `enable` command writes `{ "id": "andidst.herd" }` into `bar.layout.right` in
`~/.config/omarchy/shell.json`. To remove the widget, run `omarchy plugin disable andidst.herd`
and delete the symlink.

### Applying code changes

- The shell watches `~/.config/omarchy/plugins` with `inotifywait -r`, which does not follow
  symlinks. Edits in this folder therefore do not trigger an automatic reload.
- On this machine, `omarchy-shell shell rescanPlugins` re-creates the widget but keeps the QML it
  compiled before, because this Quickshell build has no `Qt.clearComponentCache`. Code changes
  take effect only after `omarchy restart shell`.
- A rescan is enough for manifest changes.

## Using fake data

`Panel.qml` has one data-source property:

```qml
property string statusCommand: "omarchy-herd status --json"
```

To work on the layout without a running Herd, set it to
`"cat ~/Work/omarchy-herd/plugin/sample-status.json"`, then set it back. The command runs
through `bash -c` with `~/.local/bin` added to `PATH`.

## Behaviour

- **Bar icon:** drawn in the bar's normal color when everything is healthy. It switches to the
  theme's alert color if:
  - the CLI fails,
  - Caddy or DNS is down,
  - an enabled database is not running, or
  - the default PHP-FPM is not running.

  The tooltip reads `Herd: N sites` and adds any problems.
- **Mouse:**
  - Left-click opens or closes the panel.
  - Middle-click refreshes.
  - Right-click opens https://herd.test.
- **Panel:**
  - Click a database row to start or stop it. While the command runs, the row shows a busy
    state.
  - If the command fails, the error appears inline, or as a notification if the panel has
    been closed.
  - Click a site to open it with `xdg-open`.
  - If the CLI fails (for example, before `omarchy-herd setup`), the panel shows the error and
    a hint.
- **Keys:**
  - `j`/`k` or the arrow keys move between rows.
  - `Enter` toggles the selected database or opens the selected site.
  - `r` refreshes, `d` opens the dashboard, and `Esc` closes the panel.
  - `Tab` moves to the next bar panel.
- **IPC:** `omarchy-shell andidst.herd toggle|open|close|refresh|status`.
