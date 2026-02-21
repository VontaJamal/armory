#!/usr/bin/env python3
"""Generate Armory KPI summary from telemetry JSON lines."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Build KPI summary from telemetry event log")
    parser.add_argument(
        "--events",
        default=str(Path.home() / ".armory" / "telemetry" / "events.jsonl"),
        help="Path to JSONL events file",
    )
    args = parser.parse_args()

    events_path = Path(args.events)
    if not events_path.exists():
        print(f"ERROR events file not found: {events_path}")
        return 1

    total = 0
    unique_install_ids: set[str] = set()
    mode_counter: Counter[str] = Counter()
    tool_counter: Counter[str] = Counter()

    for line in events_path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        total += 1
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue

        install_id = event.get("installId")
        if isinstance(install_id, str) and install_id.strip():
            unique_install_ids.add(install_id.strip())

        mode = event.get("mode")
        if isinstance(mode, str):
            mode_counter[mode] += 1

        tool_ids = event.get("toolIds", [])
        if isinstance(tool_ids, list):
            for tool_id in tool_ids:
                if isinstance(tool_id, str) and tool_id:
                    tool_counter[tool_id] += 1

    print("Armory KPI Summary")
    print("------------------")
    print(f"Total events: {total}")
    print(f"Unique installs: {len(unique_install_ids)}")
    print(f"Mode split: {dict(mode_counter)}")
    print("Top tools:")
    for tool_id, count in tool_counter.most_common(10):
        print(f"  - {tool_id}: {count}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
