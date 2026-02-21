# OpenClaw MS Teams Thread Sessions

Minimal patch set that adds per-thread session routing to the MS Teams extension.
Each channel/group thread gets its own conversation session instead of sharing one.

## What it does

1. Extracts thread ID from Teams conversation IDs (`;messageid=XXXXX` suffix)
2. Routes each thread to its own session by appending `:thread:{threadId}` to the peer ID
3. Preserves full conversation ID in replies so responses go to the correct thread
4. Handles proactive sends to thread-specific conversations

## Files changed

| File | Change |
|------|--------|
| `src/config/types.msteams.ts` | +1 line: `threadSessions?: boolean` |
| `src/config/zod-schema.providers-core.ts` | +1 line: zod field |
| `extensions/msteams/src/monitor-handler/message-handler.ts` | Thread routing (~45 lines) |
| `extensions/msteams/src/messenger.ts` | Preserve conversation ID (~25 lines removed, 5 added) |
| `extensions/msteams/src/send-context.ts` | Thread-aware proactive sends (~15 lines) |

**Total: 5 files, ~42 lines net**

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
git apply patches/message-handler.patch
git apply patches/messenger.patch
git apply patches/send-context.patch
pnpm build
```

## Config

Add `threadSessions: true` to your msteams channel config:

```json
{
  "channels": {
    "msteams": {
      "threadSessions": true,
      "requireMention": false,
      "replyStyle": "thread"
    }
  }
}
```

- `threadSessions: true` enables per-thread session routing
- `requireMention: false` is a stock config option (no code change needed)
- `replyStyle: "thread"` makes replies go to the thread (stock option)

## Verification

1. `pnpm build` - no TypeScript errors
2. `pnpm test` - all tests pass
3. Config validation: `threadSessions: true` passes `OpenClawSchema.safeParse()`
4. Thread routing: message in a channel thread gets its own session
5. DMs: still work normally (no thread routing for direct messages)
