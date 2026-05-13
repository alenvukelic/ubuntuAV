#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="ubuntuAV"
APP_VERSION="0.1.0"
MANAGED_MARK="# ubuntuAV managed"
EU_COUNTRIES="AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
err() { printf '[ERR ] %s\n' "$*" >&2; }
pause() { read -r -p "Enter za nastavak..." _; }

is_root() { [ "${EUID:-$(id -u)}" -eq 0 ]; }

run_root() {
  if is_root; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    err "Ova akcija treba root prava, a sudo nije dostupan."
    return 1
  fi
}

run_user() {
  local user="$1"
  shift
  if is_root; then
    sudo -u "$user" "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo -u "$user" "$@"
  else
    err "Ova akcija treba sudo za korisnika $user."
    return 1
  fi
}

confirm() {
  local prompt="${1:-Nastaviti?}"
  local answer
  read -r -p "$prompt [y/N]: " answer
  case "${answer,,}" in
    y|yes|da|d) return 0 ;;
    *) return 1 ;;
  esac
}

require_ubuntu() {
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}" in
      ubuntu|debian) return 0 ;;
      *) warn "Detektiran je ${PRETTY_NAME:-nepoznat OS}. Alat je ciljan za Ubuntu/Debian." ;;
    esac
  fi
}

timestamp() { date +%Y%m%d-%H%M%S; }

backup_file() {
  local file="$1"
  if [ ! -e "$file" ]; then
    warn "Datoteka ne postoji, backup preskočen: $file"
    return 0
  fi
  local dir base dest
  dir="$(dirname "$file")"
  base="$(basename "$file")"
  dest="$dir/$(timestamp).$base"
  run_root cp -a "$file" "$dest"
  info "Backup: $dest"
}

safe_append_once() {
  local file="$1"
  local marker="$2"
  local content="$3"
  if [ -f "$file" ] && grep -Fq "$marker" "$file"; then
    info "Blok već postoji u $file"
    return 0
  fi
  backup_file "$file"
  printf '%s\n' "$content" | run_root tee -a "$file" >/dev/null
}

install_packages() {
  local packages=("$@")
  if [ "${#packages[@]}" -eq 0 ]; then return 0; fi
  info "Paketi za instalaciju: ${packages[*]}"
  confirm "Instalirati apt pakete?" || return 0
  run_root apt-get update
  run_root apt-get install -y "${packages[@]}"
}

service_restart() {
  local svc="$1"
  confirm "Restartati servis $svc?" && run_root systemctl restart "$svc"
}

print_cmd() {
  local title="$1"
  shift
  bold "$title"
  if "$@"; then true; else warn "Naredba nije uspjela: $*"; fi
  printf '\n'
}

main_menu() {
  while true; do
    clear || true
    bold "$APP_NAME $APP_VERSION"
    cat <<'MENU'
1. System overview
2. ZeroTier
3. NGINX
4. NGINX GeoIP2
5. NGINX rate limiting
6. AppArmor
7. SSL / OpenSSL / certbot
8. SSH
9. UFW firewall
10. Webmin
11. PostgreSQL
12. Python
13. Backup
14. System tools / Telegram / Disk / SpeedTest
15. GitHub deploy helper
16. Backups list / restore
0. Exit
MENU
    read -r -p "Odabir: " choice
    case "$choice" in
      1) system_overview ;;
      2) menu_zerotier ;;
      3) menu_nginx ;;
      4) menu_geoip2 ;;
      5) menu_rate_limit ;;
      6) menu_apparmor ;;
      7) menu_ssl ;;
      8) menu_ssh ;;
      9) menu_ufw ;;
      10) menu_webmin ;;
      11) menu_postgresql ;;
      12) menu_python ;;
      13) menu_backup ;;
      14) menu_system_tools ;;
      15) menu_github_deploy ;;
      16) menu_backups ;;
      0) exit 0 ;;
      *) warn "Nepoznat odabir." ; pause ;;
    esac
  done
}

system_overview() {
  clear || true
  bold "System overview"
  print_cmd "Hostname" hostnamectl
  print_cmd "Uptime" uptime
  print_cmd "IP adrese" ip -br addr
  print_cmd "Gateway / route" ip route
  print_cmd "DNS" resolvectl status
  print_cmd "Network adapteri" ip -details link
  print_cmd "Disk" df -hT
  print_cmd "Memory" free -h
  pause
}

menu_zerotier() {
  while true; do
    clear || true
    bold "ZeroTier"
    command -v zerotier-cli >/dev/null 2>&1 && zerotier-cli status || warn "ZeroTier nije instaliran."
    cat <<'MENU'
1. Instaliraj ZeroTier
2. Status / info
3. Join network
4. Leave network
5. List networks
6. List peers
0. Nazad
MENU
    read -r -p "Odabir: " c
    case "$c" in
      1) install_packages curl gnupg; curl -s https://install.zerotier.com | run_root bash ;;
      2) run_root zerotier-cli info; pause ;;
      3) read -r -p "ZeroTier network ID: " id; run_root zerotier-cli join "$id"; pause ;;
      4) read -r -p "ZeroTier network ID: " id; run_root zerotier-cli leave "$id"; pause ;;
      5) run_root zerotier-cli listnetworks; pause ;;
      6) run_root zerotier-cli peers; pause ;;
      0) return ;;
      *) warn "Nepoznat odabir."; pause ;;
    esac
  done
}

menu_nginx() {
  while true; do
    clear || true
    bold "NGINX"
    detect_webservers
    cat <<'MENU'
1. Instaliraj NGINX
2. Ispiši konfiguraciju i siteove
3. Test konfiguracije
4. Dodaj basic website
5. Ukloni enabled website
6. Restart / reload
0. Nazad
MENU
    read -r -p "Odabir: " c
    case "$c" in
      1) install_packages nginx ;;
      2) nginx_show_config ;;
      3) run_root nginx -t; pause ;;
      4) nginx_add_site ;;
      5) nginx_remove_site ;;
      6) confirm "Reload NGINX?" && run_root systemctl reload nginx; pause ;;
      0) return ;;
      *) warn "Nepoznat odabir."; pause ;;
    esac
  done
}

detect_webservers() {
  bold "Webserver procesi/servisi"
  for svc in nginx apache2 lighttpd caddy; do
    if systemctl list-unit-files "$svc.service" >/dev/null 2>&1; then
      systemctl is-active "$svc" >/dev/null 2>&1 && printf '%s: active\n' "$svc" || printf '%s: installed/inactive\n' "$svc"
    fi
  done
  ss -tulpn 2>/dev/null | grep -E ':(80|443)\s' || true
  printf '\n'
}

nginx_show_config() {
  run_root nginx -T 2>/tmp/ubuntuav-nginx.txt || true
  less /tmp/ubuntuav-nginx.txt || cat /tmp/ubuntuav-nginx.txt
  pause
}

nginx_add_site() {
  read -r -p "Domena/site name: " domain
  [ -n "$domain" ] || return 0
  local root="/var/www/$domain/public"
  local conf="/etc/nginx/sites-available/$domain"
  local body
  body=$(cat <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $domain;
    root $root;
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
)
  info "Kreiram $root i $conf"
  confirm "Nastaviti?" || return 0
  run_root mkdir -p "$root"
  printf '<h1>%s</h1>\n' "$domain" | run_root tee "$root/index.html" >/dev/null
  [ -e "$conf" ] && backup_file "$conf"
  printf '%s\n' "$body" | run_root tee "$conf" >/dev/null
  run_root ln -sfn "$conf" "/etc/nginx/sites-enabled/$domain"
  run_root nginx -t && service_restart nginx
  pause
}

nginx_remove_site() {
  ls -1 /etc/nginx/sites-enabled 2>/dev/null || true
  read -r -p "Enabled site za ukloniti: " site
  [ -n "$site" ] || return 0
  local target="/etc/nginx/sites-enabled/$site"
  if [ -e "$target" ] || [ -L "$target" ]; then
    confirm "Maknuti symlink $target?" && run_root rm "$target"
  fi
  run_root nginx -t && service_restart nginx
  pause
}

menu_geoip2() {
  clear || true
  bold "NGINX GeoIP2"
  cat <<'TEXT'
GeoIP2 za NGINX traži modul ngx_http_geoip2_module i MaxMind bazu.
Na Ubuntu paket obično postoji kao libnginx-mod-http-geoip2, a baze se mogu držati u /usr/share/GeoIP/.
TEXT
  cat <<'MENU'
1. Instaliraj modul
2. Dodaj globalni GeoIP2 EU map snippet
3. Dodaj site allow/deny snippet primjer
4. Test NGINX
0. Nazad
MENU
  read -r -p "Odabir: " c
  case "$c" in
    1) install_packages libnginx-mod-http-geoip2 geoipupdate ;;
    2) geoip2_global_snippet ;;
    3) geoip2_site_snippet ;;
    4) run_root nginx -t; pause ;;
    0) return ;;
  esac
}

geoip2_global_snippet() {
  local file="/etc/nginx/conf.d/ubuntuav-geoip2.conf"
  local maps=""
  for cc in $EU_COUNTRIES; do maps="$maps    $cc 1;\n"; done
  local content
  content=$(printf '%s\ngeoip2 /usr/share/GeoIP/GeoLite2-Country.mmdb {\n    $geoip2_data_country_code country iso_code;\n}\n\nmap $geoip2_data_country_code $is_eu {\n    default 0;\n%b}\n' "$MANAGED_MARK" "$maps")
  safe_append_once "$file" "$MANAGED_MARK" "$content"
  run_root nginx -t
  pause
}

geoip2_site_snippet() {
  local file="/etc/nginx/snippets/ubuntuav-geoip2-site-policy.conf"
  local content
  content=$(cat <<'EOF'
# ubuntuAV managed
# Include inside server/location block, then customize as needed.
# Block specific countries:
# if ($geoip2_data_country_code ~ (CN|RU)) { return 403; }

# Allow only Croatia:
# if ($geoip2_data_country_code != "HR") { return 403; }

# Allow only EU countries from global map:
if ($is_eu = 0) {
    return 403;
}
EOF
)
  safe_append_once "$file" "$MANAGED_MARK" "$content"
  info "U site dodaj: include snippets/ubuntuav-geoip2-site-policy.conf;"
  pause
}

menu_rate_limit() {
  clear || true
  bold "NGINX Rate Limiting"
  local global="/etc/nginx/conf.d/ubuntuav-rate-limit.conf"
  local snippet="/etc/nginx/snippets/ubuntuav-rate-limit-location.conf"
  local gcontent="$MANAGED_MARK
limit_req_zone \$binary_remote_addr zone=req_limit:10m rate=5r/s;"
  local scontent="$MANAGED_MARK
limit_req zone=req_limit burst=10 nodelay;"
  confirm "Dodati globalni req_limit i location snippet?" || return 0
  safe_append_once "$global" "$MANAGED_MARK" "$gcontent"
  safe_append_once "$snippet" "$MANAGED_MARK" "$scontent"
  info "U željeni location dodaj: include snippets/ubuntuav-rate-limit-location.conf;"
  run_root nginx -t
  pause
}

menu_apparmor() {
  clear || true
  bold "AppArmor"
  command -v aa-status >/dev/null 2>&1 || install_packages apparmor apparmor-utils
  run_root aa-status || true
  cat <<'MENU'
1. Enforce profile
2. Complain profile
3. Reload AppArmor
0. Nazad
MENU
  read -r -p "Odabir: " c
  case "$c" in
    1) read -r -p "Profile path/name: " p; run_root aa-enforce "$p"; pause ;;
    2) read -r -p "Profile path/name: " p; run_root aa-complain "$p"; pause ;;
    3) run_root systemctl reload apparmor; pause ;;
    0) return ;;
  esac
}

menu_ssl() {
  clear || true
  bold "SSL / certbot"
  cat <<'MENU'
1. OpenSSL self-signed cert
2. Instaliraj certbot NGINX plugin
3. Izradi/obnovi Let's Encrypt cert za domenu
4. Test renewal
0. Nazad
MENU
  read -r -p "Odabir: " c
  case "$c" in
    1) ssl_self_signed ;;
    2) install_packages certbot python3-certbot-nginx ;;
    3) read -r -p "Domena: " d; run_root certbot --nginx -d "$d"; pause ;;
    4) run_root certbot renew --dry-run; pause ;;
    0) return ;;
  esac
}

ssl_self_signed() {
  read -r -p "Domena/CN: " domain
  [ -n "$domain" ] || return 0
  local dir="/etc/ssl/ubuntuav/$domain"
  run_root mkdir -p "$dir"
  run_root openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$dir/privkey.pem" -out "$dir/fullchain.pem" -subj "/CN=$domain"
  info "Cert: $dir/fullchain.pem"
  pause
}

menu_ssh() {
  while true; do
    clear || true
    bold "SSH"
    ssh_audit
    cat <<'MENU'
1. Disable root login
2. Disable global password authentication
3. Dodaj ZeroTier subnet Match rule za password auth
4. Test sshd config
5. Restart SSH
0. Nazad
MENU
    read -r -p "Odabir: " c
    case "$c" in
      1) ssh_set_option PermitRootLogin no ;;
      2) ssh_set_option PasswordAuthentication no ;;
      3) ssh_zt_password_rule ;;
      4) run_root sshd -t; pause ;;
      5) service_restart ssh; pause ;;
      0) return ;;
    esac
  done
}

ssh_config_file() {
  [ -f /etc/ssh/sshd_config ] && printf '%s\n' /etc/ssh/sshd_config || printf '%s\n' /etc/ssh/ssh_config
}

ssh_audit() {
  local cfg
  cfg="$(ssh_config_file)"
  printf 'Config: %s\n' "$cfg"
  grep -Ei '^(PermitRootLogin|PasswordAuthentication|KbdInteractiveAuthentication|PubkeyAuthentication|AllowUsers|Match)' "$cfg" || true
  printf '\nKorisnici s shell pristupom:\n'
  awk -F: '$7 !~ /(nologin|false)$/ {print $1 " -> " $7}' /etc/passwd
  printf '\nAuthorized keys:\n'
  find /home /root -maxdepth 3 -name authorized_keys -type f -printf '%p\n' 2>/dev/null || true
}

ssh_set_option() {
  local key="$1" val="$2" cfg
  cfg="$(ssh_config_file)"
  confirm "Postaviti $key $val u $cfg?" || return 0
  backup_file "$cfg"
  if grep -Eq "^[#[:space:]]*$key[[:space:]]+" "$cfg"; then
    run_root sed -i -E "s|^[#[:space:]]*$key[[:space:]]+.*|$key $val|" "$cfg"
  else
    printf '%s %s\n' "$key" "$val" | run_root tee -a "$cfg" >/dev/null
  fi
  run_root sshd -t
  pause
}

ssh_zt_password_rule() {
  local cfg subnet
  cfg="$(ssh_config_file)"
  read -r -p "ZeroTier subnet/CIDR koji smije password auth (npr 10.147.0.0/16): " subnet
  [ -n "$subnet" ] || return 0
  local block
  block="$MANAGED_MARK
Match Address $subnet
    PasswordAuthentication yes"
  safe_append_once "$cfg" "$MANAGED_MARK" "$block"
  run_root sshd -t
  pause
}

menu_ufw() {
  clear || true
  bold "UFW firewall"
  command -v ufw >/dev/null 2>&1 || install_packages ufw
  run_root ufw status verbose || true
  cat <<'MENU'
1. Primijeni baseline: deny incoming, allow outgoing, allow 22/80/443
2. Allow port
3. Deny port
4. Enable UFW
5. Disable UFW
0. Nazad
MENU
  read -r -p "Odabir: " c
  case "$c" in
    1) ufw_baseline ;;
    2) read -r -p "Port/protocol (npr 5432/tcp): " p; run_root ufw allow "$p"; pause ;;
    3) read -r -p "Port/protocol: " p; run_root ufw deny "$p"; pause ;;
    4) run_root ufw enable; pause ;;
    5) run_root ufw disable; pause ;;
    0) return ;;
  esac
}

ufw_baseline() {
  confirm "Primijeniti UFW baseline pravila?" || return 0
  run_root ufw default deny incoming
  run_root ufw default allow outgoing
  run_root ufw allow 22/tcp
  run_root ufw allow 80/tcp
  run_root ufw allow 443/tcp
  run_root ufw status verbose
  pause
}

menu_webmin() {
  clear || true
  bold "Webmin"
  if command -v webmin >/dev/null 2>&1 || systemctl list-unit-files webmin.service >/dev/null 2>&1; then
    run_root systemctl status webmin --no-pager || true
  else
    warn "Webmin nije detektiran."
  fi
  confirm "Instalirati Webmin repo i paket?" || { pause; return; }
  install_packages curl gnupg ca-certificates
  curl -fsSL https://download.webmin.com/jcameron-key.asc | run_root gpg --dearmor -o /usr/share/keyrings/webmin.gpg
  echo "deb [signed-by=/usr/share/keyrings/webmin.gpg] https://download.webmin.com/download/repository sarge contrib" | run_root tee /etc/apt/sources.list.d/webmin.list >/dev/null
  install_packages webmin
  pause
}

menu_postgresql() {
  while true; do
    clear || true
    bold "PostgreSQL"
    pg_audit
    cat <<'MENU'
1. Instaliraj PostgreSQL
2. List users/databases
3. Show memory settings
4. Create dump task primjer
5. Replication setup checklist
0. Nazad
MENU
    read -r -p "Odabir: " c
    case "$c" in
      1) install_packages postgresql postgresql-contrib ;;
      2) run_user postgres psql -c '\du'; run_user postgres psql -c '\l'; pause ;;
      3) run_user postgres psql -c "show shared_buffers; show effective_cache_size; show work_mem; show maintenance_work_mem;"; pause ;;
      4) pg_dump_task ;;
      5) pg_replication_checklist ;;
      0) return ;;
    esac
  done
}

pg_audit() {
  command -v psql >/dev/null 2>&1 && psql --version || warn "PostgreSQL klijent nije instaliran."
  command -v pg_lsclusters >/dev/null 2>&1 && pg_lsclusters || true
}

pg_dump_task() {
  read -r -p "Database name: " db
  read -r -p "Backup dir [/var/backups/postgresql]: " dir
  dir="${dir:-/var/backups/postgresql}"
  local script="/usr/local/sbin/ubuntuav-pg-dump-$db.sh"
  local content
  content="#!/usr/bin/env bash
set -Eeuo pipefail
mkdir -p '$dir'
pg_dump -Fc '$db' > '$dir/$db-\$(date +%Y%m%d-%H%M%S).dump'"
  confirm "Kreirati $script i cron dnevno u 02:30?" || return 0
  printf '%s\n' "$content" | run_root tee "$script" >/dev/null
  run_root chmod +x "$script"
  printf '30 2 * * * postgres %s\n' "$script" | run_root tee "/etc/cron.d/ubuntuav-pg-dump-$db" >/dev/null
  pause
}

pg_replication_checklist() {
  cat <<'TEXT'
Replication checklist:
1. Primary: set wal_level=replica, max_wal_senders, hot_standby=on.
2. Primary: create replication user with strong password.
3. Primary: add standby IP to pg_hba.conf with replication permission.
4. Standby: run pg_basebackup from primary.
5. Standby: create standby.signal and primary_conninfo.
6. Test failover plan before relying on it.
TEXT
  pause
}

menu_python() {
  clear || true
  bold "Python"
  ls -1 /usr/bin/python* 2>/dev/null | sort || true
  python3 --version 2>/dev/null || true
  cat <<'MENU'
1. Instaliraj python3/pip/venv
2. Instaliraj specifični apt paket (npr python3.12)
3. Ukloni apt python paket
0. Nazad
MENU
  read -r -p "Odabir: " c
  case "$c" in
    1) install_packages python3 python3-pip python3-venv ;;
    2) read -r -p "Package: " p; install_packages "$p" ;;
    3) read -r -p "Package za remove: " p; confirm "Ukloniti $p?" && run_root apt-get remove -y "$p"; pause ;;
    0) return ;;
  esac
}

menu_backup() {
  while true; do
    clear || true
    bold "Backup"
    cat <<'MENU'
1. Filesystem tar.gz backup task
2. FTP upload task primjer
3. PostgreSQL dump task
4. List cron ubuntuAV tasks
0. Nazad
MENU
    read -r -p "Odabir: " c
    case "$c" in
      1) fs_backup_task ;;
      2) ftp_backup_task ;;
      3) pg_dump_task ;;
      4) ls -l /etc/cron.d/ubuntuav-* 2>/dev/null || true; pause ;;
      0) return ;;
    esac
  done
}

fs_backup_task() {
  read -r -p "Path za backup: " src
  read -r -p "Backup dir [/var/backups/ubuntuav]: " dir
  dir="${dir:-/var/backups/ubuntuav}"
  local name
  name="$(basename "$src" | tr -c 'A-Za-z0-9_.-' '_')"
  local script="/usr/local/sbin/ubuntuav-fs-backup-$name.sh"
  local content
  content="#!/usr/bin/env bash
set -Eeuo pipefail
mkdir -p '$dir'
tar -czf '$dir/$name-\$(date +%Y%m%d-%H%M%S).tar.gz' '$src'"
  confirm "Kreirati $script i cron dnevno u 03:00?" || return 0
  printf '%s\n' "$content" | run_root tee "$script" >/dev/null
  run_root chmod +x "$script"
  printf '0 3 * * * root %s\n' "$script" | run_root tee "/etc/cron.d/ubuntuav-fs-backup-$name" >/dev/null
  pause
}

ftp_backup_task() {
  cat <<'TEXT'
FTP preporuka:
- Nemoj spremati FTP lozinku u repo.
- Na serveru koristi /root/.netrc s chmod 600 ili SFTP/SSH key gdje je moguće.
- Script može uploadati postojeći backup direktorij pomoću lftp mirror -R.
TEXT
  install_packages lftp
  pause
}

menu_system_tools() {
  while true; do
    clear || true
    bold "System tools"
    cat <<'MENU'
1. Check updates
2. Basic info
3. Telegram test/send setup
4. Disk/partitions
5. Mount network disk guidance
6. SpeedTest / fio
0. Nazad
MENU
    read -r -p "Odabir: " c
    case "$c" in
      1) run_root apt-get update; apt list --upgradable; pause ;;
      2) system_overview ;;
      3) telegram_setup ;;
      4) lsblk -f; df -hT; pause ;;
      5) network_disk_guidance ;;
      6) speedtest_fio ;;
      0) return ;;
    esac
  done
}

telegram_setup() {
  cat <<'TEXT'
Telegram:
1. Kod BotFather kreiraj bot i token spremi lokalno, ne u repo.
2. Dohvati chat_id slanjem poruke botu pa otvori getUpdates.
3. Preporuka: spremi /etc/ubuntuav/telegram.env s chmod 600:
   TELEGRAM_BOT_TOKEN=...
   TELEGRAM_CHAT_ID=...
TEXT
  confirm "Kreirati helper /usr/local/bin/ubuntuav-telegram-send?" || return 0
  run_root mkdir -p /etc/ubuntuav
  local helper="/usr/local/bin/ubuntuav-telegram-send"
  local content
  content='#!/usr/bin/env bash
set -Eeuo pipefail
. /etc/ubuntuav/telegram.env
msg="${1:-ubuntuAV test}"
curl -fsS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=${msg}"'
  printf '%s\n' "$content" | run_root tee "$helper" >/dev/null
  run_root chmod +x "$helper"
  pause
}

network_disk_guidance() {
  cat <<'TEXT'
Network disk mapping:
- SMB/CIFS: apt install cifs-utils, credentials in /root/.smbcredentials chmod 600.
- NFS: apt install nfs-common, mount server:/export /mnt/name.
- Always test manually before adding /etc/fstab.
TEXT
  pause
}

speedtest_fio() {
  cat <<'MENU'
1. Instaliraj fio i speedtest-cli
2. Run fio quick disk test
3. Run network speedtest
0. Nazad
MENU
  read -r -p "Odabir: " c
  case "$c" in
    1) install_packages fio speedtest-cli ;;
    2) fio --name=ubuntuav --filename=/tmp/ubuntuav-fio-test --size=256M --rw=readwrite --bs=4k --iodepth=16 --runtime=30 --time_based --group_reporting; rm -f /tmp/ubuntuav-fio-test; pause ;;
    3) speedtest-cli; pause ;;
    0) return ;;
  esac
}

menu_github_deploy() {
  clear || true
  bold "GitHub deploy helper"
  cat <<'TEXT'
Ovaj helper generira SSH deploy key na serveru i ispisuje public key.
Public key dodaj u GitHub repo kao Deploy key ili u Actions secret, ovisno o deployment flowu.
Private key ostaje na serveru i ne smije ići u repo.
TEXT
  cat <<'MENU'
1. Generiraj deploy SSH key
2. Ispiši public key
3. Test git SSH prema GitHubu
0. Nazad
MENU
  read -r -p "Odabir: " c
  local key="$HOME/.ssh/ubuntuav_github_deploy"
  case "$c" in
    1) mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"; ssh-keygen -t ed25519 -C "ubuntuav-deploy-$(hostname)" -f "$key"; pause ;;
    2) cat "$key.pub"; pause ;;
    3) ssh -T git@github.com || true; pause ;;
    0) return ;;
  esac
}

menu_backups() {
  clear || true
  bold "Backups list / restore"
  read -r -p "Original file path za pretragu backupova: " file
  [ -n "$file" ] || return 0
  local dir base
  dir="$(dirname "$file")"
  base="$(basename "$file")"
  ls -1 "$dir"/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]."$base" 2>/dev/null || true
  read -r -p "Backup file za restore (prazno za nazad): " backup
  [ -n "$backup" ] || return 0
  [ -f "$backup" ] || { warn "Ne postoji: $backup"; pause; return 1; }
  confirm "Restore $backup -> $file?" || return 0
  backup_file "$file"
  run_root cp -a "$backup" "$file"
  pause
}

require_ubuntu
main_menu
