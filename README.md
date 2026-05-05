# Telegram Router for Zabbix alerts

A small alertscript that lets you fan one Zabbix media type out to many
Telegram chats by routing on an alias (or raw chat_id) passed as the first
parameter.

Useful when you run **one** Telegram bot for the whole environment but want to:

- send `default` → ops channel,
- send `critical` → on-call channel,
- send `info` → "noisy" feed,
- and still allow ad-hoc routing by raw `chat_id`.

## Files

- [`telegram-router.sh`](telegram-router.sh) — the alertscript itself. Drop into `/usr/lib/zabbix/alertscripts/`.
- [`zabbix-action-config.md`](zabbix-action-config.md) — step-by-step Zabbix UI configuration (media type, action, tag-based routing).

## Install

```bash
sudo install -m 0755 telegram-router.sh /usr/lib/zabbix/alertscripts/telegram-router.sh
sudo chown root:zabbix /usr/lib/zabbix/alertscripts/telegram-router.sh

# Bot token — keep this file 0600, root:zabbix
sudo install -m 0600 -o root -g zabbix /dev/null /etc/zabbix/telegram-router.env
sudo tee /etc/zabbix/telegram-router.env > /dev/null <<'EOF'
TELEGRAM_BOT_TOKEN=123456:your-real-bot-token
# Optional outbound proxy:
# HTTPS_PROXY=http://user:pass@proxy.example.com:8118
EOF

# Routes — alias -> chat_id, one per line. Mode 0644 is fine; chat_ids are not secrets.
sudo tee /etc/zabbix/telegram-routes.conf > /dev/null <<'EOF'
default=-1001234567890
critical=-1009876543210
info=-1005551234567
EOF
```

## Use from CLI

```bash
TELEGRAM_BOT_TOKEN=... ./telegram-router.sh default "Test subject" "Test message"
TELEGRAM_BOT_TOKEN=... ./telegram-router.sh -1001234567890 "Raw id" "Bypassing the alias map"
```

## Config knobs

| Env / path | Default | Purpose |
|---|---|---|
| `TELEGRAM_BOT_TOKEN` | — (required) | From [@BotFather](https://t.me/BotFather) |
| `ENV_FILE` | `/etc/zabbix/telegram-router.env` | File sourced for env (mode 0600) |
| `ROUTES_CONF` | `/etc/zabbix/telegram-routes.conf` | `alias=chat_id` map |
| `HTTPS_PROXY` | — | Optional egress proxy |

## License

MIT — same as the parent repo.
