# omarchy-herd

omarchy-herd gives [Omarchy](https://omarchy.org) a [Laravel Herd](https://herd.laravel.com)–style local development environment. Nothing runs in containers: PHP, the databases and the web server run natively, and a dashboard and an Omarchy bar widget let you see and control all of them.

It's for people who build PHP (Laravel, Symfony, WordPress, plain PHP) and Node projects on an Omarchy machine and want what Herd gives you on macOS:

- every project folder served at `https://<folder>.test`, with no per-project setup
- several PHP versions side by side, chosen per project
- MariaDB, PostgreSQL and Valkey (Redis) a click away
- HTTPS your browser trusts

![Dashboard](https://github.com/andidst/omarchy-herd/raw/main/docs/dashboard-sites.png)

## Quick start

```bash
git clone https://github.com/andidst/omarchy-herd.git ~/Work/omarchy-herd
~/Work/omarchy-herd/install.sh
omarchy-herd doctor
```

Then restart Chrome once and open **https://herd.test**. Every folder in `~/Work` is now `https://<folder>.test`.

## In this wiki

| Page | Read it when you want to… |
|---|---|
| [Installation](Installation) | install, upgrade or remove omarchy-herd, and know what each step touches |
| [Sites](Sites) | serve projects: park, link, proxy, and how names and document roots are picked |
| [PHP](PHP) | install versions, pin a project to one, change `php.ini` |
| [Node](Node) | pick Node versions globally or per project |
| [Databases](Databases) | connect to MariaDB, PostgreSQL or Valkey, and know where the data lives |
| [Dashboard and Bar Widget](Dashboard-and-Bar-Widget) | use https://herd.test and the bar icon |
| [Recipes](Recipes) | set up a Laravel app, an old project, a Vite dev server or WordPress |
| [CLI Reference](CLI-Reference) | look up every command and alias |
| [JSON Interface](JSON-Interface) | script omarchy-herd with `--json` |
| [Architecture](Architecture) | understand which process does what, and which files it writes |
| [Security Model](Security-Model) | know what you're trusting before you install |
| [Troubleshooting](Troubleshooting) | fix something that broke |
| [FAQ](FAQ) | check the common questions |
| [Contributing](Contributing) | help out, including with this wiki |

> omarchy-herd is a community project. It isn't affiliated with Laravel, Laravel Herd or Omarchy.
