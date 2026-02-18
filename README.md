# OpenClaw MS Teams Plugin (Threaded Sessions)

A custom Microsoft Teams channel plugin for [OpenClaw](https://openclaw.ai) with **per-thread session routing**. Each thread in a Teams channel or group chat gets its own independent AI conversation context, so parallel discussions don't bleed into each other.

The stock `@openclaw/msteams` plugin treats an entire channel as one session. This fork adds `threadSessions: true`, which gives every thread its own session -- exactly like having separate DM conversations, but inside a shared channel.

## Prerequisites

- **OpenClaw** already installed and running (`openclaw status` shows the gateway is up)
- **Node.js 22+**
- **An Azure Bot registration** (see [Azure Bot Setup](#azure-bot-setup) below if you don't have one yet)

## Install

### Step 1: Clone this repo

```bash
git clone https://github.com/CyberFitz-LLC/openclaw-msteams-threaded.git
cd openclaw-msteams-threaded
```

### Step 2: Install into OpenClaw

```bash
openclaw plugins install ./
```

This copies the plugin into `~/.openclaw/extensions/msteams/`, installs its dependencies, and registers it in your config. OpenClaw compiles the TypeScript on the fly -- no build step needed.

If you already have the stock `@openclaw/msteams` plugin installed, this replaces it (same plugin ID: `msteams`).

### Step 3: Add your Azure Bot credentials

Add these to `~/.openclaw/.env`:

```bash
MSTEAMS_APP_ID=your-azure-bot-app-id
MSTEAMS_APP_PASSWORD=your-azure-bot-client-secret
MSTEAMS_TENANT_ID=your-azure-ad-tenant-id
```

Or add them to `~/.openclaw/openclaw.json`:

```json5
{
  channels: {
    msteams: {
      enabled: true,
      appId: "YOUR-APP-ID",
      appPassword: "YOUR-APP-PASSWORD",
      tenantId: "YOUR-TENANT-ID",
    }
  }
}
```

### Step 4: Enable threaded sessions

Add `threadSessions: true` to your msteams config in `~/.openclaw/openclaw.json`:

```json5
{
  channels: {
    msteams: {
      enabled: true,
      threadSessions: true,       // <-- the key feature
      appId: "YOUR-APP-ID",
      appPassword: "YOUR-APP-PASSWORD",
      tenantId: "YOUR-TENANT-ID",
      webhook: {
        port: 3978,
        path: "/api/messages"
      },
      groupPolicy: "open",        // respond in channels/group chats
      requireMention: true,        // only respond when @mentioned
      replyStyle: "thread",        // reply in threads (not top-level)
    }
  }
}
```

### Step 5: Restart the gateway

```bash
openclaw gateway --port 18789 --verbose
```

Or if you installed the daemon:

```bash
# systemd (Linux)
systemctl --user restart openclaw

# launchd (macOS)
launchctl kickstart -k gui/$(id -u)/com.openclaw.gateway
```

---

## How thread sessions work

Without `threadSessions`:
- All messages in a Teams channel share **one** session. The AI sees every message as part of the same conversation. If three people are discussing three different topics, the AI mixes them all together.

With `threadSessions: true`:
- Each thread gets its **own** session. When someone replies in a thread, the AI only sees the context from that specific thread. Different threads are completely independent conversations.

**Technical details**: Teams embeds a thread identifier in the conversation ID as a `;messageid=XXXXX` suffix. When `threadSessions` is enabled, the plugin extracts this ID and routes the message to a session keyed as `{conversationId}:thread:{threadId}`. Replies are sent back to the same thread automatically.

---

## Azure Bot Setup

If you don't have an Azure Bot registration yet, here's the full setup.

### 1. Create an Azure Bot

1. Go to [Azure Portal > Create Azure Bot](https://portal.azure.com/#create/Microsoft.AzureBot).
2. Fill in:

   | Field | Value |
   |---|---|
   | Bot handle | A unique name, e.g. `my-openclaw-bot` |
   | Subscription | Your Azure subscription |
   | Resource group | Create new or pick existing |
   | Pricing tier | **Free** (fine for personal use) |
   | Type of App | **Single Tenant** |
   | Creation type | Create new Microsoft App ID |

3. Click **Review + create**, then **Create**. Wait 1-2 minutes.

### 2. Get your credentials

1. Go to your Azure Bot resource > **Configuration**.
2. Copy the **Microsoft App ID** -- this is your `appId`.
3. Click **Manage Password** to go to the App Registration.
4. Under **Certificates & secrets** > **New client secret** > copy the **Value** -- this is your `appPassword`.
5. Go to **Overview** > copy **Directory (tenant) ID** -- this is your `tenantId`.

### 3. Enable the Teams channel in Azure

1. In your Azure Bot resource > **Channels**.
2. Click **Microsoft Teams** > Configure > Save.
3. Accept the Terms of Service.

### 4. Expose your webhook to the internet

Teams sends messages to your bot via HTTPS. Your machine needs to be reachable from the internet on port 3978 (or whatever you set in `webhook.port`).

**Option A: ngrok (easiest for testing)**
```bash
ngrok http 3978
```
Copy the `https://` URL (e.g. `https://abc123.ngrok.io`).

**Option B: Tailscale Funnel**
```bash
tailscale funnel 3978
```

**Option C: Reverse proxy** on your own server/VPS (nginx, caddy, etc.).

### 5. Set the messaging endpoint in Azure

1. Go to your Azure Bot resource > **Configuration**.
2. Set **Messaging endpoint** to: `https://YOUR-PUBLIC-URL/api/messages`

### 6. Create and upload the Teams app

1. Go to [dev.teams.microsoft.com/apps](https://dev.teams.microsoft.com/apps).
2. Click **+ New app**.
3. Fill in basic info (name, description, developer info).
4. Go to **App features** > **Bot**.
5. Select **Enter a bot ID manually** and paste your Azure Bot App ID.
6. Check scopes: **Personal**, **Team**, **Group Chat**.
7. Click **Distribute** > **Download app package**.
8. In Teams: **Apps** > **Manage your apps** > **Upload a custom app** > select the ZIP.

### 7. Test it

Send a direct message to your bot in Teams. You should see the message in the gateway logs and get a reply.

For channels: @mention the bot in a thread. With `threadSessions: true`, each thread will maintain its own context.

---

## Full config reference

All options for the `channels.msteams` section:

| Option | Type | Default | Description |
|---|---|---|---|
| `enabled` | boolean | `true` | Enable/disable the Teams provider |
| `threadSessions` | boolean | `false` | Give each thread its own session context |
| `appId` | string | -- | Azure Bot App ID |
| `appPassword` | string | -- | Azure Bot client secret |
| `tenantId` | string | -- | Azure AD tenant ID |
| `webhook.port` | number | `3978` | Webhook server port |
| `webhook.path` | string | `"/api/messages"` | Webhook endpoint path |
| `dmPolicy` | string | `"pairing"` | DM access: `"open"`, `"pairing"`, `"disabled"` |
| `allowFrom` | string[] | `[]` | Allowlisted DM senders (AAD object IDs or UPNs) |
| `groupPolicy` | string | `"allowlist"` | Group access: `"open"`, `"allowlist"`, `"disabled"` |
| `groupAllowFrom` | string[] | `[]` | Allowlisted group senders |
| `requireMention` | boolean | `true` | Require @mention in channels/groups |
| `replyStyle` | string | `"thread"` | `"thread"` or `"top-level"` |
| `textChunkLimit` | number | `4000` | Max chars per outbound message chunk |
| `historyLimit` | number | -- | Max group history messages for context |
| `teams` | object | -- | Per-team config overrides (see below) |
| `sharePointSiteId` | string | -- | For file uploads in group chats |
| `mediaMaxMb` | number | `100` | Max media size in MB |

### Per-team / per-channel overrides

```json5
{
  channels: {
    msteams: {
      threadSessions: true,
      teams: {
        "your-team-id": {
          requireMention: false,
          replyStyle: "thread",
          channels: {
            "19:channel-id@thread.tacv2": {
              requireMention: true,
              replyStyle: "top-level",
            }
          }
        }
      }
    }
  }
}
```

---

## Updating

To update to a newer version:

```bash
cd openclaw-msteams-threaded
git pull
openclaw plugins install ./
```

Then restart the gateway.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Bot doesn't respond | Check gateway logs (`openclaw gateway --verbose`). Verify the messaging endpoint URL is correct and reachable. |
| "Unable to reach app" in Teams | Your webhook URL isn't reachable. Check ngrok/tunnel is running. |
| Messages appear but no reply | Check your AI API key is set (`openclaw doctor`). |
| Threads sharing context | Verify `threadSessions: true` is set. Check logs for `[THREAD-DEBUG]` -- `threadSessionsEnabled` should be `true`. |
| Group messages ignored | Set `groupPolicy: "open"` or add users to `groupAllowFrom`. |
| File uploads fail in group chats | Configure `sharePointSiteId` + Graph permissions. |

## License

Same license as OpenClaw. See the main [OpenClaw repository](https://github.com/openclaw/openclaw) for details.
