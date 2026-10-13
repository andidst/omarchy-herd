# Node

omarchy-herd manages Node through [mise](https://mise.jdx.dev), which Omarchy already uses. It adds no Node machinery of its own: every Node command is a thin wrapper around a `mise` command, so anything you do with mise directly shows up in omarchy-herd too, and the other way round.

Node isn't served by omarchy-herd. To put a Node dev server on a `.test` domain, [proxy it](Sites#proxying).

## Versions

```bash
omarchy-herd node available     # MAJOR, LATEST, LTS, INSTALLED
omarchy-herd node install 22    # newest 22.x
omarchy-herd node list          # what mise has installed
```

`available` shows the newest release of each major line from 18 up, and marks even-numbered majors as LTS. Odd majors never become LTS, and a brand-new even major isn't LTS until its October promotion, so treat that column as a hint.

`install` accepts a major (`22`), a major.minor (`22.11`), an exact version (`22.11.0`), `lts` or `latest`.

```bash
omarchy-herd node uninstall 22.11.0
```

Uninstall needs the exact installed version. Get it from `omarchy-herd node list`.

## Default version

```bash
omarchy-herd node default 22
```

This runs `mise use --global node@22`, which writes mise's global config (normally `~/.config/mise/config.toml`). It applies everywhere that no project config overrides it.

## Per-project version

```bash
omarchy-herd node use 20 shop     # or, inside the project: omarchy-herd node use 20
omarchy-herd node reset shop
```

`use` writes the version to `mise.local.toml` in the site's folder, by explicit path. Without the explicit path mise would update the nearest existing config file, which might be a `~/Work/.mise.toml` that every project shares.

`reset` removes Node from that `mise.local.toml` and leaves the rest of the file alone.

mise picks the file up whenever you `cd` into the project (with mise's shell activation, which Omarchy sets up), so `node`, `npm` and `npx` use that version there.

`mise.local.toml` is meant to stay out of version control. Add it to your global gitignore, which is `~/.config/git/ignore` unless you've set `core.excludesFile`:

```bash
mkdir -p ~/.config/git && echo mise.local.toml >> ~/.config/git/ignore
```

If a project already pins Node in a committed mise config (`mise.toml`, `.mise.toml`) or `.tool-versions`, that's what `omarchy-herd sites` and the dashboard show, unless `mise.local.toml` overrides it.

## What omarchy-herd shows

The NODE column in `omarchy-herd sites` and the dashboard is `mise current node` run in each site's folder. If mise doesn't trust a project's config, or the config is broken, the column is empty instead of failing the whole listing. Run `mise trust` in that folder to fix it.
