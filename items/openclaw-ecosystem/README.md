# OpenClaw Ecosystem — Tools & Extensions

Third-party tools, libraries, and patterns that make OpenClaw agents sharper. Everything here has been vetted and either installed or queued for integration.

> *"Build small, sharp tools. Let the agent call them. Keep the agent dumb, keep the tools sharp."*

---

## Installed & Active

### Scrapling — Stealth Web Scraping
- **What:** Undetectable scraper that adapts when sites change structure. Bypasses Cloudflare Turnstile automatically. 774x faster than BeautifulSoup+lxml.
- **Install:** `pip install "scrapling[ai]"` + `python -m playwright install chromium`
- **Source:** [@hasantoxr](https://x.com/hasantoxr/status/2025902150296236050) | [GitHub](https://github.com/D4Vinci/Scrapling) | BSD-3
- **Use cases:** Image harvesting (Pinterest/Tumblr), news scraping, data fallback, UI testing
- **Status:** ✅ Ready to use

### keep.md — Bookmark-to-Markdown API
- **What:** Save bookmarks from anywhere, access them as markdown through an API
- **URL:** https://keep.md
- **Use cases:** Feed bookmarks into nightly synthesis, content pipeline research
- **Status:** 📋 Logged, not yet integrated

### playbooks get — URL-to-Markdown Fetcher
- **What:** Fetch any URL as clean markdown, even client-side rendered pages
- **Usage:** `npx playbooks get <url>`
- **Source:** [@iannuttall](https://x.com/iannuttall/status/2017237629008249128)
- **Use cases:** Web research, content scraping, competitor analysis
- **Status:** 📋 Logged, not yet integrated

---

## Patterns

### Local-first CLI > API calls
Wrap external APIs in small CLI tools. Agent runs CLI, reads stdout. Faster, cacheable, testable, works offline.
- **Our examples:** `gmail.py`, `jutsu`, `ramuh`, `shiva`, anime-scraper.py

### Context Window Management
Source: [@johann_sath](https://x.com/johann_sath/status/2025440759416045702)
- Orchestrator pattern: main session stays lean, subagents do heavy work
- MEMORY.md as external brain — read/write, don't remember in-context
- Heartbeats as fast check-ins (<3s), no file loading unless idle
- Target: main session under 30K context
- **Lossless Claw (LCM):** Plugin that replaces sliding-window compaction with a DAG-based summarization system. Every message persists in SQLite; agents recall details via `lcm_grep`, `lcm_expand`, `lcm_describe`. Install: `openclaw plugins install @martian-engineering/lossless-claw` | [GitHub](https://github.com/martian-engineering/lossless-claw) | [Visualization](https://losslesscontext.ai)

### Humanizer — AI Detection Removal
Source: [blader/humanizer](https://github.com/blader/humanizer) — 5.7K stars
- Removes AI writing patterns using 24 detection rules
- Potential Armory spell: "Glamour" — run content through before publishing
- **Status:** 📋 Logged, not yet integrated

### Write Discipline > Read Discipline
Write things down immediately rather than trying to remember them. Files persist across sessions, memory doesn't.
- **Core principle:** Text > Brain — if you want to remember it, write it to a file
- **Examples:** Update MEMORY.md when learning lessons, capture decisions in daily files, document patterns in AGENTS.md
- **Why it matters:** Agent memory is ephemeral; file-based memory is permanent and shareable across sessions

### Marker Test Protocol
Strategic testing pattern for validating system behavior under different conditions.
- **Method:** Place markers/checkpoints in code/config, run test scenarios, verify markers behave as expected
- **Use cases:** Memory management validation, context switching verification, agent handover testing
- **Source:** Chiti's OpenClaw memory management guide (Feb 2026)

### Readonly Access by Default
When integrating with external data (email, messages, calendars, bookmarks), default to readonly access. The agent can READ and analyze but cannot send, delete, or modify. Reduces blast radius if agent gets confused or prompt-injected. Upgrade to write access only for specific, well-tested actions.

### Nightly Conversation Archiving
Set up a cron that auto-distills the day's chat into key decisions, action items, and learnings. Write to daily memory log. Reduces manual memory maintenance and ensures nothing falls through the cracks even if the human forgets to ask for a summary.

---

## Community Knowledge

### 13-Step OpenClaw Security Hardening Guide
- **Author:** [@johann_sath](https://x.com/johann_sath/status/2025671363504337282)
- **Key concepts:** Dedicated user (never root), custom port, Tailscale for invisibility, SSH keys + Fail2ban, UFW firewall, Telegram allowlists, DM-only policy, Docker sandboxing for subagents (capDrop ALL), daily security audit cron, self-audit prompt, config drift detection
- **Why it matters:** Most thorough single-source security guide for OpenClaw deployments. Covers Linux VPS and home server setups.
- **Takeaway:** Comprehensive guide — covers everything from firewall rules to Docker sandboxing for subagents.

### 5 Days Fixing Agent Memory — Chiti's OpenClaw Memory Guide
- **Author:** Unknown (shared via Telegram, OpenClaw community)
- **Key concepts:** memory flush before compaction, hybrid search (BM25 + vectors), LEARNINGS.md pattern, marker test protocol, context pruning (cache-ttl), write discipline > read discipline, handover protocol for model switches, boot sequence placement in AGENTS.md
- **Why it matters:** Most comprehensive single-user writeup on OpenClaw memory management. Practical, battle-tested advice.
- **Status:** 📋 Documented

### Felix's OpenClaw Automation Setup (Feb 2026)
- **Author:** Felix (ContextSDK founder, OpenClaw power user)
- **Source:** Personal blog, shared via Telegram
- **Key concepts:**
  - Travel bot with readonly access to booking confirmations (parsed from email, stored as structured markdown)
  - Beeper CLI for cross-messenger search (Telegram, WhatsApp, iMessage unified)
  - Nightly cron to archive key learnings from conversations automatically
  - ContextSDK phone awareness: agent knows if user is walking, at desk, in car — adjusts response style
  - Smart home automation via Homey based on calendar (shift-based heating, lighting, ventilation)
  - Readonly access pattern as security principle for all integrations
  - Voice messages for natural rambling input (Telegram voice + OpenClaw transcription)
- **Key takeaways:**
  - Nightly conversation archiving cron — auto-distill daily chat into key decisions
  - Readonly access as formal design principle
  - Voice message workflow for capturing ideas on-the-go

---

## People to Watch

| Handle | Why |
|--------|-----|
| [@iannuttall](https://x.com/iannuttall) | OpenClaw power user. Builds local-first agent tools. |
| [@hasantoxr](https://x.com/hasantoxr) | Scrapling creator. Stealth scraping for AI agents. |
| [@johann_sath](https://x.com/johann_sath) | Context management patterns. Runs 24/7 agents under 30K. |

---

## Adding Tools

When you find something worth adding:
1. Add it here with: **What**, **Install/URL**, **Source**, **Use cases**, **Status**
2. Status options: ✅ Installed | 📋 Logged | 🔨 Building | ❌ Rejected
3. If it could become an Armory weapon/spell, note the candidate name
