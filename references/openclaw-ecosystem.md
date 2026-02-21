# OpenClaw Ecosystem — Curated Tools & Resources

A living collection of tools, CLIs, and patterns that make OpenClaw agents smarter without making the agent do more. The philosophy: build small, sharp tools. Let the agent call them. Keep the agent dumb, keep the tools sharp.

> *"Build your own local-first API/CLI tools for it and keep your personal agent dumber."* — [@iannuttall](https://x.com/iannuttall/status/2025262008913068268)

---

## Bookmarks & Content

### keep.md
- **What:** Save bookmarks from anywhere, access them as markdown through an API
- **URL:** https://keep.md
- **Why it matters:** Feed bookmarks directly into agent workflows. Save an X post, a GitHub repo, an article — your agent reads it as markdown later. Perfect for the nightly synthesis or content research.
- **Sovereign use:** Could feed Shadow Vault content pipeline. Bookmark interesting tweets/articles throughout the day → nightly synthesis reads them and generates content ideas.

### playbooks get
- **What:** Fetch any URL as clean markdown, even client-side rendered pages
- **Usage:** `npx playbooks get <url>`
- **Source:** [@iannuttall](https://x.com/iannuttall/status/2017237629008249128)
- **Why it matters:** Agents struggle with URLs that need JavaScript rendering. This handles it. Create an OpenClaw skill that always uses this when fetching URLs.
- **Sovereign use:** Web research tasks, content scraping, competitor analysis, documentation fetching.

---

## SEO & Marketing

### Google Search Console CLI
- **What:** CLI for querying Google Search Console data — impressions, clicks, rankings
- **Status:** Referenced by @iannuttall, specific tool TBD
- **Why it matters:** When djws.io and Sovereign repos start getting traffic, you need to track what's working. An Armory weapon that pulls GSC data and reports trends.
- **Sovereign use:** Future Armory tool — `armory seo` or FF-named equivalent. Track which repos/pages are ranking, what keywords are growing.
- **Build candidate:** Yes — once site traffic justifies it.

### Agent-first Email Marketing CLI
- **What:** CLI for drafting and sending emails/newsletters with agent assistance
- **Status:** We already have `gmail.py` for basic send/read. This would be the leveled-up version.
- **Why it matters:** Content + email = distribution. Agent drafts the newsletter based on the week's work, you review and send.
- **Sovereign use:** Weekly Sovereign newsletter — what shipped, what's coming, links to new tools. Faye drafts, Indra approves.
- **Build candidate:** Yes — after content pipeline is flowing.

---

## Agent Patterns

### Local-first CLI > API calls
- **Pattern:** Instead of having your agent call external APIs directly, wrap them in small CLI tools. The agent runs the CLI, reads stdout.
- **Why:** Faster, cacheable, testable, works offline, doesn't burn agent context on API formatting.
- **Examples in Sovereign:** `gmail.py`, `jutsu` (key swap), `ramuh` (diagnostics), `shiva` (snapshots)

### Event system to wake agents
- **Pattern:** Scripts that trigger agent turns based on file changes, webhooks, or system events — not just cron.
- **Why:** Cron is time-based. Events are trigger-based. "New file appeared in inbox → wake agent" is more efficient than "check inbox every 5 minutes."
- **Status:** OpenClaw supports this via `openclaw agent` command. Explore further.

### Skill files as agent contracts
- **Pattern:** Instead of stuffing instructions into prompts, write SKILL.md files that agents read on demand. The agent loads the skill when it needs it.
- **Why:** Keeps agent context small. Skills are version-controlled. Multiple agents can share skills.
- **Sovereign use:** Every Armory tool could have a companion SKILL.md that agents read before using it.

---

## People to Watch

| Handle | Why |
|--------|-----|
| [@iannuttall](https://x.com/iannuttall) | OpenClaw power user. Builds local-first agent tools. keep.md creator. |
| [@anthropaborat](https://x.com/alexalbert__) | Anthropic developer relations. Claude/MCP updates. |
| [@OpenClaw](https://x.com/opencaborat) | Official updates, new features, skill drops. |

---

## Adding to This File

## Agentic Engineering Patterns

### Behavioral Testing Philosophy
- **Source:** [@nnennahacks](https://x.com/nnennahacks/status/2025311312037994558) (Feb 21, 2026)
- **What:** Made Claude Code produce behavioral tests (spec-style) instead of implementation-detail tests. Removed 11 tests, deleted 293 lines, maintained 100% coverage. Test names read as specifications — you know the system guarantees without opening the implementation.
- **Key insight:** "Test names are specifications." Fewer, better tests > more tests. Removing tests that maintain coverage is an improvement, not a regression.
- **Sovereign use:** Built into Seven Shadow System as `sss test-quality` — behavioral test quality gate under the Shadow of Testing.
- **Build candidate:** Already specced → `BUILD-SPEC-SENTINEL-EYE.md`

### Don't Test What the Type System Guarantees
- **Source:** [@mattpocockuk](https://x.com/mattpocockuk) (Feb 17, 2026) — 1K likes, 95K views, reposted by @VontaJamal
- **What:** "Don't write tests for what the type system already guarantees." Helps eliminate an entire class of useless tests — type-checking a string is a string, verifying an interface shape that TypeScript already enforces.
- **Key insight:** If the compiler catches it, a test for it is waste. Agents especially need this rule because they default to writing tests for everything including type contracts.
- **Sovereign use:** Feeds into `sss test-quality` — flag tests that duplicate type system guarantees as candidates for removal.
- **Build candidate:** Already covered by Sentinel Eye spec

### Agent PR Monitoring
- **Source:** [@jarredsumner](https://x.com/jarredsumner) (Feb 21, 2026, Bun creator)
- **What:** Feature request for `gh` CLI: agent-friendly subcommand for monitoring PRs — unresolved comments with file:line, failing CI logs filtered to errors, lint errors from actions.
- **Sovereign use:** Built into Seven Shadow System as Sentinel Eye (`sss comments`, `sss failures`, `sss lint`).
- **Build candidate:** Already specced → `BUILD-SPEC-SENTINEL-EYE.md`

---

When you find a tool, tweet, repo, or pattern that could benefit the Sovereign ecosystem:

1. Add it to the appropriate section
2. Include: **What**, **URL/Source**, **Why it matters**, **Sovereign use**
3. Tag it as **Build candidate: Yes/No** if it could become an Armory tool
4. The nightly synthesis reviews this file and may act on build candidates

---

*Sharp tools, dumb agents. That's the pattern.*
