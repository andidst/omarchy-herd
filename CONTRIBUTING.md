# Contributing to omarchy-herd

Thanks for helping. Bug reports, fixes, docs and new features are all welcome. This page explains how to get a change merged without breaking anyone's machine.

omarchy-herd runs a root-owned web server, rewrites DNS routing and trusts a certificate authority, so a careless change can do real damage. That's why every change goes through a pull request and needs passing CI and a maintainer review before it's merged.

## Before you start

- **Bugs:** open an [issue](https://github.com/andidst/omarchy-herd/issues/new/choose) with the output of `omarchy-herd doctor`.
- **Questions and ideas:** use [Discussions](https://github.com/andidst/omarchy-herd/discussions).
- **Larger changes** (a new service, a new command, anything that touches `setup/` or the dashboard API): open an issue first so we can agree on the approach before you write it.
- **Security problems:** don't open an issue. Follow [SECURITY.md](SECURITY.md).

## Development setup

You need an Omarchy machine (x86_64). Work from a fork:

```bash
git clone https://github.com/<you>/omarchy-herd.git ~/Work/omarchy-herd
~/Work/omarchy-herd/install.sh
```

`install.sh` symlinks `~/.local/bin/omarchy-herd` and the bar widget to your clone, so your edits take effect immediately. The dashboard at https://herd.test is served from your clone too.

For lint, install the tools CI uses:

```bash
sudo pacman -S --needed shellcheck php
```

## Project layout

```
bin/omarchy-herd        CLI entry point: argument parsing, locking, dispatch
lib/                    CLI modules: common, sites, php, node, services, setup, uninstall
setup/                  root-owned half of setup and uninstall (runs through sudo/pkexec)
dashboard/              the herd.test dashboard (plain PHP, no dependencies)
plugin/                 the Omarchy bar widget (Quickshell/QML)
wiki/                   source of the GitHub wiki
```

The [Architecture](https://github.com/andidst/omarchy-herd/wiki/Architecture) and [JSON interface](https://github.com/andidst/omarchy-herd/wiki/JSON-Interface) wiki pages explain how the pieces fit together.

## Rules that keep things from breaking

1. **The `--json` output is an API.** The dashboard and the bar widget both parse it. Add fields freely, but don't rename or remove existing ones, or change their types, without updating `dashboard/index.php`, `dashboard/api.php`, `plugin/Model.js` and `plugin/sample-status.json` in the same pull request.
2. **Root code stays minimal.** `setup/root-setup.sh` and `setup/root-uninstall.sh` run as root. They must never create, change or follow paths inside the user's home folder. Keep new work in the user half (`lib/`) whenever you can.
3. **Changing the system units or system config?** Bump `SETUP_VERSION` in `setup/root-setup.sh` and `HERD_SYSTEM_SETUP_VERSION` in `lib/common.sh` together, so existing installs re-apply them on the next `omarchy-herd setup`. CI fails if they differ.
4. **Validate input at the edge.** Every value that reaches the generated Caddyfile, a unit file or a shell command must be checked against an allow-list (see `valid_site_name`, `valid_path` and the patterns in `dashboard/api.php`). If you add a dashboard action, add its argument pattern too.
5. **Never lose user data.** `php.ini` files, database data and `config.json` belong to the user. Write generated files atomically (`write_atomic`, `config_update`) and don't overwrite user-owned files.
6. **Re-running is safe.** `setup` and `apply` must be idempotent: running them twice changes nothing the second time.
7. **Every state-changing command takes the lock** (`take_lock` in `bin/omarchy-herd`), so the dashboard and terminal can't race.

## Code style

- Bash: `set -euo pipefail`, 2-space indent, `[[ ]]`, `local` for every function variable, quote everything. Match the surrounding code. A short comment explains *why*, not *what*.
- Messages: `ok` for success, `info` for progress (hidden in `--json` mode), `warn` for non-fatal problems, `die` for errors. Never print plain text to stdout from a command that has `--json` output.
- PHP: `declare(strict_types=1)`, no dependencies, no shell (`proc_open` with an argument array).
- QML: follow `plugin/Panel.qml`. The widget picks up QML changes only after `omarchy restart shell`.

## Before you open a pull request

Run what CI runs:

```bash
shellcheck -x bin/omarchy-herd lib/*.sh setup/*.sh install.sh
for f in dashboard/*.php; do php -l "$f"; done
jq empty plugin/manifest.json plugin/sample-status.json
```

Then test the change on your machine:

```bash
omarchy-herd setup     # re-applies everything, including the root half if it changed
omarchy-herd doctor    # every check should pass
omarchy-herd status
```

Also exercise the commands you touched, with and without `--json`. If you changed the dashboard or the bar widget, check them in the browser and the bar.

## Pull requests

- One change per pull request. Small ones get reviewed faster.
- Explain what changed and why, and how you tested it. The pull request template asks for this.
- Update the README or the `wiki/` pages when behavior changes.
- Use imperative commit messages, e.g. "Retry PHP downloads", not "Retried" or "Retrying".
- Pull requests are squash-merged, so the title becomes the commit message on `main`.

`main` is protected. Every change needs:

- the `lint` and `smoke` checks to pass,
- an approving review from a code owner,
- every review conversation resolved,
- a branch that's up to date with `main`.

Workflows from first-time contributors need a maintainer's approval before they run. That's normal, so please don't worry if your checks wait for a bit.

## Editing the wiki

The [wiki](https://github.com/andidst/omarchy-herd/wiki) is built from the `wiki/` folder. Edit the Markdown there in a pull request. When it merges, a workflow publishes the folder to the wiki. Edits made directly in the wiki are overwritten by the next publish.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
