#!/usr/bin/env python3
"""Block bundle mode when trust-store scaffold placeholders are still present."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SEVEN_SHADOW = ROOT / ".seven-shadow"
BUNDLE_PATH = SEVEN_SHADOW / "policy.bundle.json"
TRUST_STORE_PATH = SEVEN_SHADOW / "policy-trust-store.json"
PLACEHOLDER_TOKENS = (
    "REPLACE_WITH_",
    "REVOKED_PEM_CONTENT",
)


def _load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise FileNotFoundError(f"missing required file: {path.relative_to(ROOT)}") from None
    except json.JSONDecodeError as exc:
        raise ValueError(f"invalid JSON in {path.relative_to(ROOT)}: {exc}") from exc


def main() -> int:
    if not BUNDLE_PATH.exists():
        print("OK bundle mode not enabled (.seven-shadow/policy.bundle.json absent)")
        return 0

    try:
        trust_store = _load_json(TRUST_STORE_PATH)
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR {exc}")
        return 1

    offending_signers: list[str] = []
    for signer in trust_store.get("signers", []):
        pem = signer.get("publicKeyPem")
        if not isinstance(pem, str):
            continue
        if any(token in pem for token in PLACEHOLDER_TOKENS):
            signer_id = signer.get("id", "<unknown-signer>")
            offending_signers.append(str(signer_id))

    if offending_signers:
        joined = ", ".join(offending_signers)
        print(
            "ERROR bundle mode is enabled but trust-store contains placeholder public keys "
            f"for signer(s): {joined}"
        )
        print("Replace scaffold placeholders before enabling .seven-shadow/policy.bundle.json.")
        return 1

    print("OK bundle mode trust-store validation passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
