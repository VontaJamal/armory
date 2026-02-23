# OpenClaw Ecosystem — Tools & Extensions

Third-party tools, libraries, and patterns that make OpenClaw agents sharper. Everything here has been vetted and either installed or queued for integration.

> *"Build small, sharp tools. Let the agent call them. Keep the agent dumb, keep the tools sharp."*

---

## Installed & Active

### Scrapling — Stealth Web Scraping
- **What:** Undetectable scraper that adapts when sites change structure. Bypasses Cloudflare Turnstile automatically. 774x faster than BeautifulSoup+lxml.
- **Install:** `pip install "scrapling[ai]"` + `python -m playwright install chromium`
- **Source:** [@hasantoxr](https://x.com/hasantoxr/status/2025902150296236050) | [GitHub](https://github.com/D4Vinci/Scrapling) | BSD-3
- **Our scripts:** `scripts/anime-scraper.py`, `scripts/sass-restock.py`
- **Use cases:** Image harvesting (Pinterest/Tumblr), anime news for daily briefs, crypto data fallback, SyncLink button placement testing
- **Status:** ✅ Installed on Windows. Playwright Chromium ready.

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

### Humanizer — AI Detection Removal
Source: [blader/humanizer](https://github.com/blader/humanizer) — 5.7K stars
- Removes AI writing patterns using 24 detection rules
- Potential Armory spell: "Glamour" — run content through before publishing
- **Status:** 📋 Logged, not yet integrated

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
