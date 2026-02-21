# OpenClaw MS Teams Thread Sessions

Minimal patch set that adds per-thread session routing to the MS Teams extension.
Each channel/group thread gets its own conversation session instead of sharing one.
Messages in active threads are implicitly directed at the bot — no @mention required
after the initial mention.

## What it does

1. Extracts thread ID from Teams conversation IDs (`;messageid=XXXXX` suffix)
2. Routes each thread to its own session by appending `:thread:{threadId}` to the peer ID
3. Preserves full conversation ID in replies so responses go to the correct thread
4. Handles proactive sends to thread-specific conversations
5. Tracks "bot-active" threads so subsequent messages don't need an @mention
6. Records thread activity when the bot sends replies (implicit mention propagation)

## Prerequisites — Azure AD & Teams App Manifest

For the bot to receive non-@mention messages in channel threads, **Resource-Specific
Consent (RSC)** must be properly configured. Without RSC, Teams will only deliver
messages where the bot is explicitly @mentioned.

### Azure AD App Registration

The bot's Azure AD app registration must have:

1. **Redirect URIs** (under *Authentication*):
   - **Web platform:**
     - `https://YOUR_DOMAIN/api/oauth/callback`
     - `http://localhost:3978/auth/callback`
     - `https://jwt.ms`
     - `https://YOUR_DOMAIN/auth/callback`
   - **Mobile and desktop:**
     - `https://login.microsoftonline.com/common/oauth2/nativeclient`

2. **Application ID URI** (under *Expose an API*):
   - Must be set to: `api://YOUR_DOMAIN/YOUR_BOT_APP_ID`
   - This must match the `resource` field in the Teams manifest

3. **Streaming endpoint**: **Disabled** (under *Bot Configuration*)
   - The OpenClaw webhook handler uses standard HTTP POST, not streaming

### Teams App Manifest

The manifest must include all of the following (see `manifest-template/manifest.json`):

```json
{
  "manifestVersion": "1.17",
  "permissions": ["identity", "messageTeamMembers"],
  "webApplicationInfo": {
    "id": "YOUR_BOT_APP_ID",
    "resource": "api://YOUR_DOMAIN/YOUR_BOT_APP_ID"
  },
  "authorization": {
    "permissions": {
      "resourceSpecific": [
        {"name": "ChannelMessage.Read.Group", "type": "Application"},
        {"name": "ChannelMessage.Send.Group", "type": "Application"},
        {"name": "ChatMessage.Read.Chat", "type": "Application"}
      ]
    }
  }
}
```

Key requirements:
- `manifestVersion` must be `1.12` or higher (we use `1.17`)
- `permissions` array at top level is required
- `webApplicationInfo.resource` must include your domain (not just the GUID)
- After uploading the manifest, **remove and re-add the app** to the channel
  so that RSC consent is freshly granted

## Files changed

| File | Change |
|------|--------|
| `src/config/types.msteams.ts` | +1 line: `threadSessions?: boolean` |
| `src/config/zod-schema.providers-core.ts` | +1 line: zod field |
| `extensions/msteams/src/sent-message-cache.ts` | Thread activity tracking (~30 lines) |
| `extensions/msteams/src/monitor-handler/message-handler.ts` | Thread routing + implicit mention (~65 lines) |
| `extensions/msteams/src/messenger.ts` | Preserve conversation ID (~25 lines removed, 5 added) |
| `extensions/msteams/src/send-context.ts` | Thread-aware proactive sends (~15 lines) |

**Total: 6 files, ~70 lines net**

## Install

From your OpenClaw source directory:

```bash
# Apply patches
./path/to/apply.sh

# Rebuild
pnpm build
```

Or apply individual patches:

```bash
git apply patches/core-schema.patch
git apply patches/sent-message-cache.patch
git apply patches/message-handler.patch
git apply patches/messenger.patch
git apply patches/send-context.patch
pnpm build
```

### For npm installs

If you installed OpenClaw via npm (no source tree), apply the extension patches
directly to the user extension directory with adjusted strip level:

```bash
cd ~/.openclaw/extensions/msteams
git apply -p3 /path/to/patches/sent-message-cache.patch
git apply -p3 /path/to/patches/message-handler.patch
git apply -p3 /path/to/patches/messenger.patch
git apply -p3 /path/to/patches/send-context.patch
```

The `core-schema.patch` must be applied to the compiled dist files instead.
See the [npm install guide](https://github.com/CyberFitz-LLC/openclaw-msteams-threaded/wiki)
for details on patching the zod schema in dist builds.

## Config

Add `threadSessions: true` to your msteams channel config:

```json
{
  "channels": {
    "msteams": {
      "threadSessions": true,
      "requireMention": true,
      "replyStyle": "thread"
    }
  }
}
```

- `threadSessions: true` enables per-thread session routing
- `requireMention: true` requires an initial @mention to engage the bot; subsequent
  messages in the same thread are delivered via RSC without @mention
- `replyStyle: "thread"` makes replies go to the thread (stock option)

## How implicit mention works

1. User @mentions the bot in a channel thread
2. Bot responds — thread is now marked "bot-active"
3. Subsequent messages in that thread are delivered to the webhook via RSC
4. The handler checks if the thread is bot-active and treats the message as
   an implicit mention — no @mention needed
5. Thread activity expires after the sent-message-cache TTL (default: ~2 hours)

## Verification

1. `pnpm build` — no TypeScript errors
2. `pnpm test` — all tests pass
3. Config validation: `threadSessions: true` passes `OpenClawSchema.safeParse()`
4. Thread routing: message in a channel thread gets its own session
5. Non-@mention delivery: messages in bot-active threads are processed without @mention
6. DMs: still work normally (no thread routing for direct messages)
