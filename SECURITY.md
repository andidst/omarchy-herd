# Security policy

omarchy-herd runs a web server, a DNS server and a certificate authority on your machine, and part of its setup runs as root. Security reports are taken seriously.

## Reporting a vulnerability

Report privately through GitHub: **[Security → Report a vulnerability](https://github.com/andidst/omarchy-herd/security/advisories/new)**.

Please don't open a public issue, discussion or pull request for a security problem.

Include:

- what an attacker can do, and from where (another website, another local user, a malicious project folder…)
- steps to reproduce, or a proof of concept
- the commit you tested (`git -C ~/Work/omarchy-herd rev-parse HEAD`)

The maintainer aims to acknowledge reports within a week. Once a fix is ready, it's released and an advisory is published, crediting you unless you'd rather stay anonymous.

## Supported versions

Only the latest commit on `main` is supported. Update with:

```bash
git -C ~/Work/omarchy-herd pull && omarchy-herd setup
```

## Scope

omarchy-herd is built for a **single-user development machine**. The [Security model](README.md#security-model) describes what it protects against and the trade-offs it accepts deliberately.

In scope, for example:

- a website you visit being able to read from or change your setup through the dashboard (CSRF, DNS rebinding, CORS bypass)
- anything reachable from another machine on the network
- the root half of setup (`setup/root-setup.sh`) being tricked into writing or reading the wrong files
- input that escapes validation into the generated Caddyfile, unit files or shell commands
- files served that shouldn't be (for example dotfiles like `.env`)

Out of scope, because they're documented trade-offs:

- databases without passwords being reachable by programs running on your own machine
- other local user accounts reaching your sites on a shared machine
- the local certificate authority's private key being readable by your own user
- the integrity of PHP builds from `dl.static-php.dev` (upstream publishes no signatures)
