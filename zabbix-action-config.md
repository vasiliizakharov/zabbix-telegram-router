# Configuring the Telegram Router in Zabbix

Step-by-step setup for routing alerts from one Telegram bot to multiple chats based on event tags.

Tested on Zabbix 7.0 LTS. The same flow works on 6.x with minor UI label differences.

## 1. Create the media type

**Administration → Media types → Create media type**

| Field | Value |
|---|---|
| Name | `Telegram Router` |
| Type | `Script` |
| Script name | `telegram-router.sh` |
| Script parameters | one per line, in this order: |
|     | `{ALERT.SENDTO}` |
|     | `{ALERT.SUBJECT}` |
|     | `{ALERT.MESSAGE}` |
| Enabled | yes |

`{ALERT.SENDTO}` is what the user / action passes to the script's first
argument — that is the alias (`default`, `critical`, …) or a raw chat_id.

## 2. Add the alertscript

Place [`telegram-router.sh`](telegram-router.sh) in
`/usr/lib/zabbix/alertscripts/` (the path Zabbix expects by default —
`AlertScriptsPath` in `zabbix_server.conf`). Make it executable and readable
by the `zabbix` group.

```bash
sudo install -m 0755 telegram-router.sh /usr/lib/zabbix/alertscripts/
```

Configure the bot token and routes (see [README.md](README.md) → Install).

## 3. Create a user with the new media

**Users → Users → (your alert user) → Media → Add**

| Field | Value |
|---|---|
| Type | `Telegram Router` |
| Send to | `default` (or `critical`, or a raw chat_id) |
| When active | (your on-call schedule) |
| Use if severity | tick the severities to deliver |
| Enabled | yes |

You'll typically add **multiple** Media entries for the same user, one per
alias, each filtered to the severities or hosts you want to fan out
differently. Or — better — drive the choice from the action.

## 4. Action — choose the alias from a tag

**Configuration → Actions → Trigger actions → Create action**

In the action's **Operations**, set the recipient to the user above and the
"Send to" field to a tag-driven macro:

```
{EVENT.TAGS.channel}
```

Then on each trigger you want routed, add a tag:

| Tag | Value |
|---|---|
| `channel` | `default` |
| `channel` | `critical` |
| `channel` | `info` |

Triggers without the tag fall back to whatever default you pin in the user
media's `Send to` field.

## 5. Test

Use **Administration → Media types → Telegram Router → Test**:

| Send to | `default` |
| Subject | `Zabbix test` |
| Message | `Hello from the router` |

You should see the message in the chat mapped by `default=` in
`/etc/zabbix/telegram-routes.conf`.

## Troubleshooting

- **Nothing arrives, no error in `zabbix_server.log`** — check that the
  `zabbix` user can read `/etc/zabbix/telegram-router.env` (group `zabbix`,
  mode `0640` works) and execute the script.
- **`ERR: alias '...' not found ...`** — the alias is not in
  `/etc/zabbix/telegram-routes.conf` and is not a raw integer. Add the
  mapping or pass a chat_id directly.
- **`curl: (7) Failed to connect ...`** — set `HTTPS_PROXY=` in the env file
  if your Zabbix host has no direct egress.
- **`Bad Request: chat not found`** from Telegram — the bot has not been
  added to the target chat yet, or the chat_id is wrong (group chat_ids
  start with `-100…`).
