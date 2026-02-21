# Agent-to-Agent Communication

How to set up multiple OpenClaw agents that talk to each other.

## Architecture

Each agent gets its own:
- Workspace directory (`~/.openclaw/workspace-{name}/`)
- Config section in `openclaw.json`
- Session key (`agent:{name}:main`)
- Optional: dedicated Telegram channel for output

## Configuration

In your `openclaw.json`:
```json
{
  "agents": {
    "list": ["main", "cipher", "poly", "kai"]
  },
  "agentToAgent": {
    "allow": ["main", "cipher", "poly", "kai"]
  }
}
```

## Sending Messages Between Agents

From your main agent to a sub-agent:
```
sessions_send(sessionKey="agent:cipher:main", message="Check the pipeline status")
```

From any agent, check what other agents are doing:
```
sessions_list(activeMinutes=15, messageLimit=2)
```

## Patterns That Work

### Hub and Spoke
One orchestrator agent dispatches work to specialist agents. Specialists report back.
- Main → dispatches tasks
- Specialists → execute and report
- Main → synthesizes and surfaces results

### Agent Relay
After dispatching, the orchestrator periodically checks agent sessions and relays results to the human without being asked.

### Dedicated Channels
Each agent posts to its own Telegram channel. The orchestrator monitors all channels and summarizes.

## Common Issues

### Timeouts ≠ Failures
Agent-to-agent messages can time out but still be delivered. Don't assume a timeout means the message was lost. Check the target agent's session.

### Session Keys Are Specific
`agent:cipher:main` is not the same as `cipher`. Use the full session key format.

### Agents Need Their Own Workspaces
Don't share workspaces between agents. File conflicts will happen. Each agent gets its own directory with its own memory files.
