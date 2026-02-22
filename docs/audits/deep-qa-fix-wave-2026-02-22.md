# Deep QA Fix Wave - 2026-02-22

## Scope
- Maintenance and hardening only.
- No net-new product features.
- Priority order: logic, security, accessibility.
- Mac runtime is mandatory; Windows remains courtesy coverage.

## Required Sequence
1. `git -C /Users/vonta/Documents/Code Repos/armory pull --ff-only` -> PASS (`Already up to date.`)
2. Baseline Armory-native checks (pre-change) -> PASS
3. Logic fixes -> completed
4. Security fixes -> completed
5. Accessibility fixes -> completed
6. Full Armory-native + Seven Shadow re-validation -> PASS

## Baseline (Pre-Change) Command Matrix
| Command | Result |
|---|---|
| `python3 scripts/ci/validate_readmes.py` | PASS |
| `python3 scripts/validate_shop_catalog.py` | PASS |
| `python3 scripts/ci/check_manifest_determinism.py` | PASS |
| `python3 scripts/ci/secret_hygiene.py` | PASS |
| `python3 scripts/ci/validate_trust_store.py` | PASS |
| `python3 scripts/release/validate_release.py --mode ci` | PASS |
| `bash scripts/ci/mac-smoke.sh` | PASS |
| `bash scripts/ci/quartermaster-smoke.sh` | PASS |

## Logic Fixes Shipped
### 1) Jutsu vault mutation hardening
- File: `/Users/vonta/Documents/Code Repos/armory/weapons/jutsu/jutsu.sh`
- Changes:
  - Removed unsafe inline Python string interpolation from `add/remove/swap`.
  - Switched to argument-safe Python calls (`sys.argv`) for provider/name/key inputs.
  - Added strict error propagation on vault parse/update failures.
  - Prevented empty-payload vault writes.
  - Hardened SSH invocation by using an argument array instead of string-eval behavior.
- Result:
  - Quoted/special-char provider names now persist safely.
  - Malformed vault JSON now fails with exit `1` and no false success message.

### 2) Dispatcher help contract
- File: `/Users/vonta/Documents/Code Repos/armory/scripts/lib/dispatch_routes.sh`
- Change:
  - Added `-h|--help` routing to the normal help path with exit `0`.

### 3) Mac smoke coverage extension
- File: `/Users/vonta/Documents/Code Repos/armory/scripts/ci/mac-smoke.sh`
- Changes:
  - Added `dispatcher --help` assertion.
  - Added zsh Jutsu help smoke.
  - Added quoted-provider Jutsu add scenario and persisted-vault assertion.

## Security Fixes Shipped
### 1) Dashboard HTML injection hardening
- File: `/Users/vonta/Documents/Code Repos/armory/docs/assets/app.js`
- Changes:
  - Replaced manifest-driven card/cart `innerHTML` rendering with DOM node creation and `textContent`.
  - Replaced error-state `innerHTML` with safe text-node rendering.
- Result:
  - Manifest text can no longer be interpreted as HTML in dashboard card/cart/error rendering paths.

### 2) CI guard for unsafe dashboard HTML APIs
- File: `/Users/vonta/Documents/Code Repos/armory/scripts/ci/validate_dashboard_security.py` (new)
- Behavior:
  - Fails if `docs/assets/app.js` contains `innerHTML=`, `outerHTML=`, or `insertAdjacentHTML(`.
- Wiring:
  - Added to CI workflow step:
    - `/Users/vonta/Documents/Code Repos/armory/.github/workflows/armory-ci.yml`
  - Added to Alexander preflight checks:
    - `/Users/vonta/Documents/Code Repos/armory/summons/alexander/alexander.py`
  - Updated Alexander docs to include new skip/check name:
    - `/Users/vonta/Documents/Code Repos/armory/summons/alexander/README.md`

## Accessibility Fixes Shipped
### Dashboard semantics and keyboard support
- Files:
  - `/Users/vonta/Documents/Code Repos/armory/docs/index.html`
  - `/Users/vonta/Documents/Code Repos/armory/docs/assets/app.js`
  - `/Users/vonta/Documents/Code Repos/armory/docs/assets/styles.css`
- Changes:
  - Added explicit labels for search/status/division controls.
  - Added explicit `type="button"` on button controls.
  - Added accessible names for cart remove buttons.
  - Added mode-toggle `aria-pressed` state updates.
  - Added dialog semantics to tour overlay (`role="dialog"`, `aria-modal`, title/body mapping).
  - Added Escape and Tab-focus trap handling for tour dialog.
  - Added focus restoration after dialog close.
  - Added visible `:focus-visible` outline styles.
  - Added `sr-only` utility class for non-visual labels.

## Post-Change Validation Matrix
### Armory-native checks
| Command | Result |
|---|---|
| `python3 scripts/ci/validate_readmes.py` | PASS |
| `python3 scripts/validate_shop_catalog.py` | PASS |
| `python3 scripts/ci/check_manifest_determinism.py` | PASS |
| `python3 scripts/ci/secret_hygiene.py` | PASS |
| `python3 scripts/ci/validate_trust_store.py` | PASS |
| `python3 scripts/release/validate_release.py --mode ci` | PASS |
| `python3 scripts/ci/validate_dashboard_security.py` | PASS |
| `bash scripts/ci/mac-smoke.sh` | PASS |
| `bash scripts/ci/quartermaster-smoke.sh` | PASS |

### Targeted regression checks
| Scenario | Result |
|---|---|
| `jutsu add` with quoted provider (`acme'corp`) | PASS |
| `jutsu add` with malformed vault JSON returns non-zero | PASS |
| `bin/armory-dispatch --help` exits `0` and prints help | PASS |
| `node --check docs/assets/app.js` | PASS |
| `rg "innerHTML|outerHTML|insertAdjacentHTML" docs/assets/app.js` | PASS (no matches) |

### Seven Shadow real checks
| Command | Result |
|---|---|
| `node --test governance/seven-shadow-system/dist/test/*.test.js` | PASS (`92 passed`) |
| `node --test governance/seven-shadow-system/dist/test/property/*.test.js` | PASS |
| `node --test governance/seven-shadow-system/dist/test/fuzz/*.test.js` | PASS |
| `node governance/seven-shadow-system/dist/scripts/run-conformance.js` | PASS |
| `node governance/seven-shadow-system/dist/scripts/validate-security-gates.js` | PASS |
| `node governance/seven-shadow-system/dist/scripts/gitlab-smoke.js` | PASS |
| `node governance/seven-shadow-system/dist/scripts/rc-soak.js --iterations 3 --report /tmp/seven-shadow-rc-soak.json` | PASS |
| `node governance/seven-shadow-system/dist/scripts/policy-trust-store.js lint --trust-store governance/seven-shadow-system/config/policy-trust-store.sample.json --format json` | PASS |
| `node governance/seven-shadow-system/dist/scripts/policy-trust-store.js lint --trust-store governance/seven-shadow-system/config/policy-trust-store.v2.sample.json --format json` | PASS |

## Manual Browser Keyboard Walkthrough Addendum
- Date: `2026-02-22` (post-fix verification rerun)
- Harness: temporary local Playwright script (Chromium, headless) against `http://127.0.0.1:4173/docs/index.html`
- Evidence artifact: `/tmp/armory-dashboard-keyboard-walkthrough.json`

Walkthrough assertions:
- Labels present for search/filter/approval/telemetry controls -> PASS
- Keyboard reachability pre-approval (`search`, `division`, `status`, `tour`, add control, cart remove control, approval checkbox) -> PASS
- Post-approval checkout reachability by keyboard -> PASS
- Tour dialog semantics + keyboard behavior (`role="dialog"`, `aria-modal`, Escape close, focus restore) -> PASS
- Mode switch semantic state (`aria-pressed`) -> PASS

Issue discovered during walkthrough and fixed in this wave:
- A runtime parse defect in `/Users/vonta/Documents/Code Repos/armory/docs/assets/app.js` blocked dashboard JS execution in Chromium.
- Cause: unescaped shell-style `${...}` expansions inside a JavaScript template literal used for installer generation.
- Fix: escaped shell expansions (`\${...}`) where literal bash parameter expansion is intended.
- Verification after fix: card render restored (`5` cards / `5` action buttons), no page errors, keyboard walkthrough passed.

## Seven Shadow Domain Status
| Domain | Status | Evidence |
|---|---|---|
| Security | PASS | security gate validation, trust lint, runtime/provider tests |
| Accessibility | PASS | accessibility snapshot test, contract markers in runtime reports |
| Testing | PASS | dist test suites + property + fuzz |
| Execution | PASS | conformance + smoke scripts + zero test failures |
| Scales | PASS | RC soak deterministic replay (`4 cases x 3 iterations`) |
| Value | PASS | deterministic policy/runtime behavior validated end-to-end |
| Aesthetics | PASS | dashboard interaction/focus/tour behavior remains coherent after a11y hardening |

## Residual Risks
- Windows remains courtesy-only. CI still includes Windows jobs, but this wave optimized for Mac runtime correctness.
- Dashboard security guard is intentionally narrow to prevent HTML API regressions in `docs/assets/app.js`.
- No Seven Shadow `src/` files changed in this wave; source/dist sync policy remained satisfied.

## Attestation
- This wave is a fix/update hardening pass only.
