# Telegram Channel Setup for OpenClaw

How to get your Telegram bot talking to channels, groups, and DMs.

## Getting Your Chat ID

The most common question: "What's my chat ID?"

### For DMs
Send any message to your bot, then hit:
```
https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
```
Look for `"chat": {"id": YOUR_ID}` in the response.

### For Groups/Channels
1. Add your bot to the group
2. Send a message in the group
3. Hit the same `getUpdates` URL
4. Group IDs are negative numbers (e.g., `-5290373854`)

### Quick Script
```bash
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates" | python3 -m json.tool | grep '"id"'
```

## Channel Routing

You can route different agents to different Telegram channels:

| Channel | Purpose |
|---------|---------|
| Main DM | Direct communication with your human |
| Alert channel | Automated notifications, health checks |
| Agent channels | Per-agent output (trade alerts, research, etc.) |

Set the `to` field in cron jobs or `message` tool calls:
```
"to": "channel:-5290373854"
```

## Common Issues

### Bot can't send to channel
Make sure the bot is added as an **administrator** in the channel, not just a member.

### Messages not appearing in getUpdates
Updates expire after 24 hours. If you haven't polled recently, send a new message and try again.

### Rate limits
Telegram limits bots to ~30 messages per second to different chats, and 1 message per second to the same chat. If you're sending bulk alerts, add small delays.
