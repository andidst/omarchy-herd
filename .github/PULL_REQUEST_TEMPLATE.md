## What and why

<!-- What does this change, and why? Link the issue it fixes, e.g. "Fixes #12". -->

## How I tested it

<!-- Commands you ran and what you checked, e.g. `omarchy-herd setup`, `omarchy-herd doctor`, the dashboard tab you clicked through. -->

## Checklist

- [ ] Lint passes locally (see [CONTRIBUTING.md](https://github.com/andidst/omarchy-herd/blob/main/CONTRIBUTING.md#before-you-open-a-pull-request))
- [ ] `omarchy-herd setup` and `omarchy-herd doctor` pass on my machine with this change
- [ ] `--json` output stays backwards compatible, or the dashboard and bar widget are updated too
- [ ] If I changed `setup/root-setup.sh` or the system units, I bumped `SETUP_VERSION` and `HERD_SYSTEM_SETUP_VERSION`
- [ ] README or `wiki/` updated if behavior changed
