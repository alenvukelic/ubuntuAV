# AGENTS.md

## Project Intent

`ubuntuAV` is an interactive text-mode Ubuntu server bootstrap and audit tool. It must stay usable on a fresh VPS with only standard Ubuntu shell utilities available. Prefer Bash and system commands already present on Ubuntu. Do not introduce mandatory Python, Node, Docker, ncurses, whiptail, dialog, or other runtime dependencies for the main app.

## Operating Rules

- Never commit secrets, tokens, private keys, host credentials, Telegram bot tokens, database passwords, or private server addresses.
- Keep local/private operator notes in `PRIVATE.md`; this file is intentionally ignored by git.
- Save work locally whenever needed, including local git commits when they help preserve progress.
- Do not run `git push` automatically. Push to GitHub only after the user explicitly asks to make a commit in the GitHub/publication sense.
- Use three-level semantic versioning in all projects: `major.minor.patch`.
- Keep commits and releases aligned with that model, and update the project version when changes warrant it.
- Before changing any existing system file, use the project backup helper. Backups must be stored next to the original file and named with `YYYYMMDD-HHMMSS.original-name`.
- Prefer dry-run style previews and explicit Yes/No confirmation before package installs, service restarts, firewall changes, SSH hardening, database changes, or destructive cleanup.
- Commands that require root should be routed through `run_root` or clearly check for privileges.
- Keep menus number-based and readable over plain SSH.
- Favor practical diagnostics over hidden automation. Show current state before proposing changes.
- Treat the app as a guided tool for novice operators: explain current state, show best-practice recommendations, and block risky hardening steps when prerequisites are missing.
- Every mutating action should be mirrored into a local replay script/log so the operator can review what happened and reuse it on another fresh server.

## Code Style

- Main entrypoint: `ubuntuav.sh`.
- Shell target: Bash 4+ on Ubuntu.
- Use `set -Eeuo pipefail` and quote paths.
- Keep functions small and named by module, for example `menu_nginx`, `ssh_audit`, `ufw_apply_baseline`.
- Any generated config block should be visibly marked with `# ubuntuAV managed`.
- Avoid hard-coding private domains, IPs, credentials, or personal paths.

## Validation

Before committing changes, run:

```bash
bash -n ubuntuav.sh
```

When possible on Ubuntu, also run:

```bash
shellcheck ubuntuav.sh
```

`shellcheck` is optional and must not become a runtime requirement.
