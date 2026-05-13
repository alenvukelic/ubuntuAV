# ubuntuAV

Interactive Ubuntu server bootstrap, audit, hardening, and maintenance helper for fresh VPS/server setups.

The tool is a plain Bash text application. It uses numbered menus, Yes/No confirmations, and standard Ubuntu commands so it can run over SSH without a desktop, browser, Python app server, or Node runtime.

Version `1.2.0` adds a more application-like TUI with a persistent header, best-practice recommendation counters, richer status views, and a local replay script for performed actions.

## Quick Run From Ubuntu

Run directly from the public GitHub repository:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/alenvukelic/ubuntuAV/main/ubuntuav.sh)"
```

If `curl` is not installed:

```bash
wget -qO- https://raw.githubusercontent.com/alenvukelic/ubuntuAV/main/ubuntuav.sh | bash
```

For local editing:

```bash
git clone https://github.com/alenvukelic/ubuntuAV.git
cd ubuntuAV
chmod +x ubuntuav.sh
./ubuntuav.sh
```

## What It Does

- Shows server identity and network state: hostname, OS, uptime, IPs, gateway, DNS, routes, and network adapters.
- Keeps a persistent header visible with app version, host, IP, gateway, and key package versions.
- Highlights best-practice recommendations in menus, for example risky SSH or firewall defaults that should be reviewed.
- Manages safety backups for edited system files and can list or restore backups by timestamp.
- Guides ZeroTier install/status/join/leave flows and displays visible peers where available.
- Audits and configures NGINX sites, GeoIP2 snippets, rate limiting snippets, AppArmor status, and SSL/certbot flows.
- Audits SSH users and hardening settings, including root login, password login, and optional ZeroTier-only password access patterns.
- Installs and configures UFW baseline firewall rules.
- Installs or audits Webmin.
- Installs and audits PostgreSQL basics: version, clusters, users, databases, memory-related settings, dumps, and replication guidance.
- Shows installed Python versions and supports installing/removing versions through apt.
- Creates backup jobs for filesystem and PostgreSQL dumps, including FTP upload examples and cron scheduling.
- Provides system tools for updates, basic health, Telegram notifications, disk inspection, mount guidance, and performance testing with `fio`/`speedtest-cli` where installed.
- Helps generate deployment SSH keys and shows what public key to add to GitHub repository secrets or deploy keys.
- Writes a local action replay script in `ubuntuav-logs/` so installs and configuration changes can be reviewed or reused on another server.

## Safety Model

Before this tool edits a file, it creates a timestamped backup next to the original file:

```text
20260513-110400.sshd_config
```

Use `Backups` from the main menu to list and restore matching backups.

Most actions first show current state, then ask for explicit confirmation before installing packages, restarting services, changing firewall rules, or modifying access controls.

For risky SSH hardening changes, the tool now checks whether a non-root shell user and sudo-capable account exist before it allows disabling root login.

## Action Replay Log

Each run creates a local replay script under:

```text
./ubuntuav-logs/ubuntuav-<hostname>-<timestamp>.sh
```

The file records the important mutating actions the tool performed. Review it before reusing it on another server.

## Recommended First Run Order

1. `System Overview`
2. `SSH`
3. `UFW Firewall`
4. `NGINX`
5. `NGINX GeoIP2`
6. `PostgreSQL`
7. `Backup`
8. `System / Telegram / SpeedTest`

## Private Notes

Create a local `PRIVATE.md` for server-specific notes, credentials, Telegram tokens, MaxMind license keys, or deployment details. It is ignored by git.

```bash
cp PRIVATE.example.md PRIVATE.md
```

Do not commit `PRIVATE.md`.

## Publishing From A Local Machine

Authenticate outside the repository. Do not put tokens or passwords in files:

```bash
gh auth login -h github.com
git push -u origin main
```

If using SSH instead of HTTPS, add your public SSH key to GitHub and set:

```bash
git remote set-url origin git@github.com:alenvukelic/ubuntuAV.git
git push -u origin main
```
