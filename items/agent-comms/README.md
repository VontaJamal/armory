# Agent-To-Agent Communication

How to run an Armory scout/equip loop with OpenClaw agents.

## Architecture

Each agent gets its own:

- Workspace directory (`~/.openclaw/workspace-{name}/`)
- Config section in `openclaw.json`
- Session key (`agent:{name}:main`)
- Optional dedicated Telegram output channel

## Required Scout/Eqip Loop

Use this sequence for Armory work:

1. Refresh Armory clone:
   - `git -C <armoryRepoRoot> pull --ff-only`
2. Run `quartermaster scout -Task "<task>"`.
3. Run `quartermaster plan -Task "<task>"` and return shortlist/cart.
4. Wait for explicit approval.
5. Run `quartermaster equip -FromLastPlan -Approve`.
6. Run `quartermaster report -FromLastPlan` in active mode tone (`mode=saga|civ`).

If pull fails, stop and report immediately.

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
sessions_send(sessionKey="agent:cipher:main", message="Scout Armory for this repo issue and report a shortlist")
```

Quartermaster command pattern:

```
<commandWord> quartermaster scout -Task "repo issue summary"
<commandWord> quartermaster plan -Task "repo issue summary"
<commandWord> quartermaster equip -FromLastPlan -Approve
<commandWord> quartermaster report -FromLastPlan
```

From any agent, check active sessions:

```
sessions_list(activeMinutes=15, messageLimit=2)
```

## Reporting Tone Contract

Shared mode flag controls human-facing language:

- `mode=civ`: plain language
- `mode=saga`: Final Fantasy style

Example completion styles:

- Civ: `Install complete. Added: remedy, chronicle.`
- Saga: `I used a Potion, equipped Masamune, and we are battle-ready.`

## Seven Shadow Requirement

If `governance/seven-shadow-system` exists, run real checks from that repo before final report.
If it is missing, report that explicitly and continue with Armory checks.

## Common Issues

### Timeouts Are Not Always Failures

Agent-to-agent messages can time out but still deliver. Validate by checking target session.

### Session Keys Are Specific

`agent:cipher:main` is not the same as `cipher`.

### Dedicated Workspaces

Do not share workspaces between agents. It causes file conflicts.
