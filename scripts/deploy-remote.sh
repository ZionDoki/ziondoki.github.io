#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
TEMPLATE_PATH="$ROOT_DIR/deploy/nginx-site.conf.template"

usage() {
	cat <<'EOF'
Usage:
  ./scripts/deploy-remote.sh --host HOST --domain DOMAIN [options]

Required:
  --host HOST                 Server IP or hostname
  --domain DOMAIN             Main domain, e.g. example.com

Optional:
  --user USER                 SSH user, default: root
  --port PORT                 SSH port, default: 22
  --www                       Also configure www.DOMAIN
  --site-url URL              Build-time PUBLIC_SITE_URL, default: https://DOMAIN
  --remote-dir PATH           Deploy directory, default: /var/www/DOMAIN
  --email EMAIL               Email used by certbot
  --skip-ssl                  Skip certbot HTTPS setup
  --no-build                  Reuse current dist without rebuilding
  --help                      Show this help

Examples:
  ./scripts/deploy-remote.sh --host 1.2.3.4 --domain example.com --www --email ops@example.com
  ./scripts/deploy-remote.sh --host 1.2.3.4 --user ubuntu --domain blog.example.com --skip-ssl
EOF
}

HOST=""
DOMAIN=""
SSH_USER="root"
SSH_PORT="22"
SITE_URL=""
REMOTE_DIR=""
CERTBOT_EMAIL=""
WITH_WWW="false"
SKIP_SSL="false"
SKIP_BUILD="false"

while [[ $# -gt 0 ]]; do
	case "$1" in
	--host)
		HOST="${2:-}"
		shift 2
		;;
	--domain)
		DOMAIN="${2:-}"
		shift 2
		;;
	--user)
		SSH_USER="${2:-}"
		shift 2
		;;
	--port)
		SSH_PORT="${2:-}"
		shift 2
		;;
	--site-url)
		SITE_URL="${2:-}"
		shift 2
		;;
	--remote-dir)
		REMOTE_DIR="${2:-}"
		shift 2
		;;
	--email)
		CERTBOT_EMAIL="${2:-}"
		shift 2
		;;
	--www)
		WITH_WWW="true"
		shift
		;;
	--skip-ssl)
		SKIP_SSL="true"
		shift
		;;
	--no-build)
		SKIP_BUILD="true"
		shift
		;;
	-h|--help)
		usage
		exit 0
		;;
	*)
		echo "Unknown option: $1" >&2
		usage
		exit 1
		;;
	esac
done

if [[ -z "$HOST" || -z "$DOMAIN" ]]; then
	echo "Error: --host and --domain are required." >&2
	usage
	exit 1
fi

if [[ "$SKIP_SSL" == "false" && -z "$CERTBOT_EMAIL" ]]; then
	echo "Error: --email is required unless --skip-ssl is used." >&2
	exit 1
fi

if [[ -z "$REMOTE_DIR" ]]; then
	REMOTE_DIR="/var/www/$DOMAIN"
fi

if [[ -z "$SITE_URL" ]]; then
	SITE_URL="https://$DOMAIN"
fi

SSH_TARGET="$SSH_USER@$HOST"
DOMAIN_NAMES="$DOMAIN"
CERTBOT_ARGS=(-d "$DOMAIN")
SSH_CONTROL_DIR=""
SSH_CONTROL_PATH=""
SSH_BASE_OPTS=()
SCP_BASE_OPTS=()

if [[ "$WITH_WWW" == "true" ]]; then
	DOMAIN_NAMES="$DOMAIN www.$DOMAIN"
	CERTBOT_ARGS+=(-d "www.$DOMAIN")
fi

require_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "Missing required local command: $1" >&2
		exit 1
	fi
}

require_cmd ssh
require_cmd scp
require_cmd rsync
require_cmd npm
require_cmd sed
require_cmd mktemp

if [[ ! -f "$TEMPLATE_PATH" ]]; then
	echo "Missing nginx template: $TEMPLATE_PATH" >&2
	exit 1
fi

SSH_CONTROL_DIR="$(mktemp -d)"
SSH_CONTROL_PATH="$SSH_CONTROL_DIR/control"
SSH_BASE_OPTS=(
	-p "$SSH_PORT"
	-o ConnectTimeout=10
	-o ControlMaster=auto
	-o ControlPersist=600
	-o ControlPath="$SSH_CONTROL_PATH"
)
SCP_BASE_OPTS=(
	-P "$SSH_PORT"
	-o ConnectTimeout=10
	-o ControlMaster=auto
	-o ControlPersist=600
	-o ControlPath="$SSH_CONTROL_PATH"
)

ssh_run() {
	ssh "${SSH_BASE_OPTS[@]}" "$SSH_TARGET" "$@"
}

scp_run() {
	scp "${SCP_BASE_OPTS[@]}" "$@"
}

rsync_run() {
	rsync -az --delete -e "ssh ${SSH_BASE_OPTS[*]}" "$@"
}

close_ssh_master() {
	if [[ -n "$SSH_CONTROL_PATH" && -S "$SSH_CONTROL_PATH" ]]; then
		ssh "${SSH_BASE_OPTS[@]}" -O exit "$SSH_TARGET" >/dev/null 2>&1 || true
	fi
}

echo "==> Checking SSH connectivity"
ssh_run "echo connected" >/dev/null

SUDO_PREFIX=""
if ssh_run "test \"\$(id -u)\" -eq 0"; then
	SUDO_PREFIX=""
elif ssh_run "sudo -n true" >/dev/null 2>&1; then
	SUDO_PREFIX="sudo"
else
	echo "Remote user must be root or have passwordless sudo." >&2
	exit 1
fi

if [[ "$SKIP_BUILD" == "false" ]]; then
	echo "==> Installing dependencies"
	(cd "$ROOT_DIR" && npm ci)

	echo "==> Building static site"
	(cd "$ROOT_DIR" && PUBLIC_SITE_URL="$SITE_URL" npm run build)
fi

if [[ ! -d "$DIST_DIR" ]]; then
	echo "Build output not found: $DIST_DIR" >&2
	exit 1
fi

TMP_CONF="$(mktemp)"
cleanup() {
	close_ssh_master
	rm -rf "$SSH_CONTROL_DIR"
	rm -f "$TMP_CONF"
}
trap cleanup EXIT

sed \
	-e "s#__DOMAIN_NAMES__#$DOMAIN_NAMES#g" \
	-e "s#__WEB_ROOT__#$REMOTE_DIR#g" \
	"$TEMPLATE_PATH" >"$TMP_CONF"

echo "==> Installing server packages"
ssh_run "
	set -euo pipefail
	if command -v apt-get >/dev/null 2>&1; then
		export DEBIAN_FRONTEND=noninteractive
		$SUDO_PREFIX apt-get update
		$SUDO_PREFIX apt-get install -y nginx rsync certbot python3-certbot-nginx
	elif command -v dnf >/dev/null 2>&1; then
		$SUDO_PREFIX dnf install -y nginx rsync certbot python3-certbot-nginx
	elif command -v yum >/dev/null 2>&1; then
		$SUDO_PREFIX yum install -y nginx rsync certbot python3-certbot-nginx
	else
		echo 'Unsupported package manager on remote host.' >&2
		exit 1
	fi
"

echo "==> Preparing remote directory"
ssh_run "$SUDO_PREFIX mkdir -p '$REMOTE_DIR' && $SUDO_PREFIX chown -R \"\$(id -un)\":\"\$(id -gn)\" '$REMOTE_DIR'"

echo "==> Uploading static files"
rsync_run "$DIST_DIR"/ "$SSH_TARGET:$REMOTE_DIR/"

echo "==> Uploading nginx config"
scp_run "$TMP_CONF" "$SSH_TARGET:/tmp/$DOMAIN.conf"

ssh_run "
	if [ -d /etc/nginx/sites-available ] || [ -f /etc/debian_version ]; then
		$SUDO_PREFIX mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled &&
		$SUDO_PREFIX mv /tmp/$DOMAIN.conf /etc/nginx/sites-available/$DOMAIN.conf &&
		$SUDO_PREFIX ln -sfn /etc/nginx/sites-available/$DOMAIN.conf /etc/nginx/sites-enabled/$DOMAIN.conf &&
		$SUDO_PREFIX rm -f /etc/nginx/sites-enabled/default
	else
		$SUDO_PREFIX mv /tmp/$DOMAIN.conf /etc/nginx/conf.d/$DOMAIN.conf
	fi &&
	$SUDO_PREFIX nginx -t &&
	$SUDO_PREFIX systemctl enable --now nginx &&
	$SUDO_PREFIX systemctl reload nginx
"

if [[ "$SKIP_SSL" == "false" ]]; then
	echo "==> Applying HTTPS certificate"
	ssh_run "$SUDO_PREFIX certbot --nginx --non-interactive --agree-tos --redirect -m '$CERTBOT_EMAIL' ${CERTBOT_ARGS[*]}"
else
	echo "==> Skipping HTTPS setup"
fi

echo
echo "Deploy complete."
echo "Server: $HOST"
echo "Domain: $DOMAIN_NAMES"
echo "Web root: $REMOTE_DIR"
