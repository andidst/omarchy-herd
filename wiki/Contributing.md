# Contributing

Contributions are welcome: bug reports, fixes, features and documentation. Start with [CONTRIBUTING.md](https://github.com/andidst/omarchy-herd/blob/main/CONTRIBUTING.md) in the repository. It covers setting up a development checkout, the checks CI runs, and how pull requests are reviewed.

## Editing this wiki

This wiki is generated from the [`wiki/`](https://github.com/andidst/omarchy-herd/tree/main/wiki) folder in the repository. Every push to `main` that changes it publishes it here. To change a page:

1. Edit `wiki/<Page-Name>.md` in a fork.
2. Open a pull request.

Edits made directly on the wiki are overwritten by the next sync, so make them in the repository instead.

Conventions:

- One file per page, named with hyphens: `Dashboard-and-Bar-Widget.md` is the page "Dashboard and Bar Widget".
- Link to other pages without the extension: `[PHP](PHP)`, `[Names](Sites#names)`.
- Link images and repository files by their GitHub URL, since the wiki is a separate repository.
- Keep `_Sidebar.md` up to date when you add a page.
- Describe what the code does. If you're not sure, read the code or ask in the pull request.

## Internals

- [Architecture](Architecture): every component, generated file and folder, and how setup works.
- [JSON Interface](JSON-Interface): the `--json` contract the dashboard and bar widget depend on.
- [Security Model](Security-Model): the guarantees a change mustn't weaken.
- [`plugin/README.md`](https://github.com/andidst/omarchy-herd/blob/main/plugin/README.md): how the bar widget is built.

## Reporting security problems

Not in public issues. Use **Security → Report a vulnerability** on the repository; see [SECURITY.md](https://github.com/andidst/omarchy-herd/blob/main/SECURITY.md).
