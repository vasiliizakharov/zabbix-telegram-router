#!/bin/bash
# telegram-router.sh — universal Zabbix → Telegram alert sender.
#
# Routes alerts from a single Telegram bot to multiple chats based on a
# tag/alias passed as the first CLI argument, so you can fan one Zabbix
# media type out to several team channels (e.g. "default", "critical", "info").
#
# Usage:
#   telegram-router.sh <chat_alias_or_raw_id> <subject> <message>
#
# Example Zabbix media-type "Script parameters":
#   {ALERT.SUBJECT}
#   {ALERT.MESSAGE}
#   {EVENT.TAGS.channel}
#
# Configuration is loaded from $ROUTES_CONF (default /etc/zabbix/telegram-routes.conf).
# The config file uses simple `key=value` lines, one per channel:
#
#   default=-1001234567890
#   critical=-1009876543210
#   info=-1005551234567
#
# A line whose key is a raw integer (positive or negative, like a Telegram
# chat_id) is passed through unchanged.
#
# Required env (set via /etc/zabbix/telegram-router.env, mode 0600):
#   TELEGRAM_BOT_TOKEN     — bot token from @BotFather (REQUIRED)
#   HTTPS_PROXY            — optional egress proxy (e.g. http://user:pass@host:port)
#
# The env file is sourced if it exists; otherwise environment is used as-is.

set -u

ENV_FILE="${ENV_FILE:-/etc/zabbix/telegram-router.env}"
ROUTES_CONF="${ROUTES_CONF:-/etc/zabbix/telegram-routes.conf}"

# shellcheck disable=SC1090
[ -r "$ENV_FILE" ] && . "$ENV_FILE"

: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN is required (set in $ENV_FILE or env)}"

ALIAS="${1:-}"
SUBJECT="${2:-}"
MESSAGE="${3:-}"

if [ -z "$ALIAS" ] || [ -z "$SUBJECT" ]; then
    echo "usage: $0 <chat_alias_or_raw_id> <subject> <message>" >&2
    exit 2
fi

# Resolve alias -> chat_id via routes config; fall back to a raw numeric id.
CHAT=""
if [ -r "$ROUTES_CONF" ]; then
    CHAT=$(awk -F= -v k="$ALIAS" '
        $0 !~ /^[[:space:]]*#/ && $1 == k { print $2; exit }
    ' "$ROUTES_CONF")
fi
if [ -z "$CHAT" ]; then
    if [[ "$ALIAS" =~ ^-?[0-9]+$ ]]; then
        CHAT="$ALIAS"
    else
        echo "ERR: alias '$ALIAS' not found in $ROUTES_CONF and is not a raw chat_id" >&2
        exit 3
    fi
fi

CURL_ARGS=(-sS --max-time 15 -H 'Content-Type: application/json' -X POST)
[ -n "${HTTPS_PROXY:-}" ] && CURL_ARGS+=(--proxy "$HTTPS_PROXY")

curl "${CURL_ARGS[@]}" \
    --data-raw "{\"chat_id\":\"${CHAT}\",\"text\":\"${SUBJECT}\n${MESSAGE}\",\"parse_mode\":\"HTML\",\"disable_web_page_preview\":true}" \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
