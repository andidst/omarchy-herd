# Databases

MariaDB, PostgreSQL and Valkey run as systemd **user** services. They start at login, store their data in your home folder, and start or stop without a password.

![Databases](https://github.com/andidst/omarchy-herd/raw/main/docs/dashboard-databases.png)

| Database | Host | Port | User | Password | Unit |
|---|---|---|---|---|---|
| MariaDB (MySQL) | 127.0.0.1 | 3306 | `root` | *(empty)* | `omarchy-herd-mariadb.service` |
| PostgreSQL | 127.0.0.1 | 5432 | `postgres` | *(empty)* | `omarchy-herd-postgres.service` |
| Valkey (Redis) | 127.0.0.1 | 6379 | – | – | `omarchy-herd-valkey.service` |

The binaries come from the Arch packages `mariadb`, `postgresql` and `valkey`, which setup installs. Their versions follow normal system updates.

All three listen on `127.0.0.1` only, so nothing outside this machine can reach them. Read [Security Model](Security-Model) before keeping anything sensitive in them: any program on this machine can connect without a password.

## Starting and stopping

```bash
omarchy-herd services            # SERVICE, STATUS, ADDRESS, USER, VERSION
omarchy-herd start mariadb
omarchy-herd stop postgres
omarchy-herd restart valkey
omarchy-herd start databases     # all three
omarchy-herd start               # all three, plus every installed PHP-FPM
```

| Name | Also accepted |
|---|---|
| `mariadb` | `mysql` |
| `postgres` | `postgresql`, `pgsql` |
| `valkey` | `redis` |
| `databases` | `dbs` |
| `all` | *(no argument)* |
| `php-<version>` | e.g. `php-8.4` |

`start` also enables the service, so it comes back at the next login. `stop` disables it, so a database you stopped stays stopped until you start it again.

`omarchy-herd setup` starts and enables all three every time it runs, including when you re-run it after an upgrade. Stop the ones you don't use again afterwards.

## First start

The first `start` creates the data folder:

- **MariaDB:** `mariadb-install-db` with normal password authentication for `root` and no test database. Once the server is up, omarchy-herd adds `root@127.0.0.1` and `root@::1` with empty passwords and all privileges, because a fresh install only knows `root@localhost`, and Laravel connects over TCP. Character set `utf8mb4`, collation `utf8mb4_unicode_ci`.
- **PostgreSQL:** `initdb` with superuser `postgres`, `trust` authentication, `UTF8` encoding and the `C.UTF-8` locale.
- **Valkey:** just its folder.

Setup output for the first two goes to `mariadb-init.log` and `postgres-init.log` in the log folder.

## Where things live

| | MariaDB | PostgreSQL | Valkey |
|---|---|---|---|
| Data | `~/.local/share/omarchy-herd/data/mariadb` | `~/.local/share/omarchy-herd/data/postgres` | `~/.local/share/omarchy-herd/data/valkey` |
| Socket | `~/.local/share/omarchy-herd/run/mariadb.sock` | `~/.local/share/omarchy-herd/run/.s.PGSQL.5432` | – |
| Config | `~/.local/share/omarchy-herd/etc/mariadb.cnf` (generated) | command-line flags in the unit | command-line flags in the unit |
| Log | `log/mariadb.log` | the journal | `log/valkey.log` |

`log/` is `~/.local/share/omarchy-herd/log`. Follow a log with `omarchy-herd logs mariadb` (or `postgres`, `valkey`).

The generated config and units are rewritten on every `omarchy-herd setup`, so don't edit them; your changes would be lost.

## Connecting from the terminal

```bash
mariadb -h 127.0.0.1 -u root
psql -h 127.0.0.1 -U postgres
valkey-cli
```

Use `-h 127.0.0.1`, not `localhost`. With `localhost`, the clients look for a socket in the system location (`/run/mysqld`, `/run/postgresql`), where nothing is listening. To use the sockets instead:

```bash
mariadb --defaults-file="$HOME/.local/share/omarchy-herd/etc/mariadb.cnf" -u root
psql -h "$HOME/.local/share/omarchy-herd/run" -U postgres
```

Create a database:

```bash
mariadb -h 127.0.0.1 -u root -e 'CREATE DATABASE shop'
createdb -h 127.0.0.1 -U postgres shop
```

## Connecting from a GUI

Any client works with the details in the table above. Some options on Omarchy:

- [Beekeeper Studio](https://www.beekeeperstudio.io): `omarchy pkg aur add beekeeper-studio-bin`
- [DBeaver](https://dbeaver.io): `omarchy pkg add dbeaver`
- TablePlus

## Laravel `.env`

The dashboard's Databases tab has these ready to copy.

MariaDB:

```dotenv
DB_CONNECTION=mariadb
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=root
DB_PASSWORD=
```

`DB_CONNECTION=mysql` works too.

PostgreSQL:

```dotenv
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=laravel
DB_USERNAME=postgres
DB_PASSWORD=
```

Valkey:

```dotenv
REDIS_CLIENT=phpredis
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=null
```

The PHP builds include the `redis` extension, so `phpredis` works without Predis.

## Backups and major upgrades

Data lives in plain folders, so the usual tools work: `mariadb-dump -h 127.0.0.1 -u root --all-databases` and `pg_dumpall -h 127.0.0.1 -U postgres`.

A major PostgreSQL release in Arch (for example 17 → 18) can't open the old data folder; the service fails to start. Dump before upgrading the `postgresql` package, or follow the [Arch wiki's upgrade steps](https://wiki.archlinux.org/title/PostgreSQL#Upgrading_PostgreSQL) using the data folder above. If you don't need the data, stop PostgreSQL, delete `~/.local/share/omarchy-herd/data/postgres` and start it again to get a fresh one.

## Removing the data

`omarchy-herd uninstall` keeps the data. `omarchy-herd uninstall --purge` deletes it, together with everything else. To reset one database, stop it, delete its data folder and start it again.
