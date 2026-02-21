import { normalizeMode, persistMode, resolveMode } from "./mode.js";
import { markTourSeen, shouldAutoStartTour, tourSteps } from "./tour.js";

const MANIFEST_PATH = "./data/armory-manifest.v1.json";

const state = {
  manifest: null,
  entries: [],
  cart: new Set(),
  mode: resolveMode(),
  telemetryOptOut: false,
  approved: false,
  tourIndex: 0,
};

const el = {
  heroTitle: document.getElementById("heroTitle"),
  heroSubtitle: document.getElementById("heroSubtitle"),
  modeSaga: document.getElementById("modeSaga"),
  modeCiv: document.getElementById("modeCiv"),
  searchInput: document.getElementById("searchInput"),
  classFilter: document.getElementById("classFilter"),
  statusFilter: document.getElementById("statusFilter"),
  catalogGrid: document.getElementById("catalogGrid"),
  cartList: document.getElementById("cartList"),
  cartHint: document.getElementById("cartHint"),
  approveCheck: document.getElementById("approveCheck"),
  checkoutBtn: document.getElementById("checkoutBtn"),
  checkoutMeta: document.getElementById("checkoutMeta"),
  replayTour: document.getElementById("replayTour"),
  telemetryOptOut: document.getElementById("telemetryOptOut"),
  tourOverlay: document.getElementById("tourOverlay"),
  tourTitle: document.getElementById("tourTitle"),
  tourBody: document.getElementById("tourBody"),
  tourNext: document.getElementById("tourNext"),
  tourSkip: document.getElementById("tourSkip"),
};

function toneCopy(mode) {
  if (mode === "civ") {
    return {
      title: "Armory Tool Catalog",
      subtitle: "Scout, approve, install, and return to work.",
      cartHint: "Select tools to build your install plan.",
    };
  }

  return {
    title: "The Armory Shopfront",
    subtitle: "Scout, approve, equip, and return to the fight.",
    cartHint: "Select tools to build your loadout.",
  };
}

function setMode(mode) {
  state.mode = normalizeMode(mode);
  persistMode(state.mode);

  const copy = toneCopy(state.mode);
  el.heroTitle.textContent = copy.title;
  el.heroSubtitle.textContent = copy.subtitle;
  el.cartHint.textContent = copy.cartHint;

  el.modeSaga.classList.toggle("active", state.mode === "saga");
  el.modeCiv.classList.toggle("active", state.mode === "civ");

  renderCatalog();
  renderCart();
}

function filteredEntries() {
  const q = el.searchInput.value.trim().toLowerCase();
  const classFilter = el.classFilter.value;
  const statusFilter = el.statusFilter.value;

  return state.entries.filter((entry) => {
    if (classFilter && entry.class !== classFilter) return false;
    if (statusFilter && entry.status !== statusFilter) return false;

    if (!q) return true;

    const display = entry.display?.[state.mode] || {};
    const haystack = [
      entry.id,
      entry.class,
      entry.status,
      display.name,
      display.description,
      ...(entry.tags || []),
    ]
      .filter(Boolean)
      .join(" ")
      .toLowerCase();

    return haystack.includes(q);
  });
}

function renderCatalog() {
  const rows = filteredEntries();
  el.catalogGrid.innerHTML = "";

  for (const entry of rows) {
    const display = entry.display?.[state.mode] || {};
    const card = document.createElement("article");
    card.className = "card";

    const selected = state.cart.has(entry.id);
    const disabled = entry.status !== "active";

    card.innerHTML = `
      <div class="meta">${entry.class.toUpperCase()} · ${entry.status}</div>
      <strong>${display.name || entry.id}</strong>
      <div class="desc">${display.description || "No description available."}</div>
      <div class="tags">${(entry.tags || []).map((t) => `#${t}`).join(" ")}</div>
      <button ${disabled ? "disabled" : ""}>${selected ? "Remove" : "Add To Cart"}</button>
    `;

    card.querySelector("button").addEventListener("click", () => {
      if (selected) {
        state.cart.delete(entry.id);
      } else {
        state.cart.add(entry.id);
      }
      renderCatalog();
      renderCart();
    });

    el.catalogGrid.appendChild(card);
  }
}

function resolveLoadout() {
  const map = new Map(state.entries.map((e) => [e.id, e]));
  const selected = new Set(state.cart);
  const queue = [...selected];

  while (queue.length > 0) {
    const id = queue.shift();
    const entry = map.get(id);
    if (!entry) continue;
    const deps = entry.install?.dependencies || [];
    for (const dep of deps) {
      if (!selected.has(dep) && map.has(dep)) {
        selected.add(dep);
        queue.push(dep);
      }
    }
  }

  return [...selected].map((id) => map.get(id)).filter(Boolean);
}

function renderCart() {
  const loadout = resolveLoadout();
  el.cartList.innerHTML = "";

  for (const entry of loadout) {
    const li = document.createElement("li");
    const display = entry.display?.[state.mode] || {};
    const removeDisabled = !state.cart.has(entry.id);
    li.innerHTML = `
      <span>${display.name || entry.id}</span>
      <button ${removeDisabled ? "disabled" : ""}>x</button>
    `;

    if (!removeDisabled) {
      li.querySelector("button").addEventListener("click", () => {
        state.cart.delete(entry.id);
        renderCatalog();
        renderCart();
      });
    }

    el.cartList.appendChild(li);
  }

  const depsAdded = loadout.length - state.cart.size;
  el.checkoutMeta.textContent = loadout.length
    ? `Selected ${state.cart.size}; dependencies auto-added: ${Math.max(0, depsAdded)}.`
    : "";

  state.approved = el.approveCheck.checked;
  el.checkoutBtn.disabled = !(loadout.length > 0 && state.approved);
}

function shSingleQuote(value) {
  return String(value).replace(/'/g, `'\"'\"'`);
}

function createInstallerScript(loadout) {
  const generatedAt = state.manifest.generatedAt;
  const repo = state.manifest.repo;
  const ref = state.manifest.ref;
  const defaultMode = state.mode;
  const telemetryEndpoint = state.manifest.telemetry?.endpoint || "";

  const bundles = [];
  for (const entry of loadout) {
    const install = entry.install || {};
    const checksums = install.checksums || {};
    for (const path of install.bundlePaths || []) {
      bundles.push({
        toolId: entry.id,
        path,
        url: `https://raw.githubusercontent.com/${repo}/${ref}/${path}`,
        sha256: checksums[path] || "",
      });
    }
  }

  const bundlesJson = shSingleQuote(JSON.stringify(bundles));
  const toolIdsJson = shSingleQuote(JSON.stringify(loadout.map((x) => x.id)));

  return `#!/usr/bin/env bash
# Armory one-shot installer
# Generated from manifest ${generatedAt}

set -euo pipefail

MODE=""
NO_TELEMETRY=0
INSTALL_ROOT="${shSingleQuote("$(pwd)/armory-loadout")}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:-}"
      shift
      ;;
    --civ)
      MODE="civ"
      ;;
    --saga)
      MODE="saga"
      ;;
    --no-telemetry)
      NO_TELEMETRY=1
      ;;
    --install-root)
      INSTALL_ROOT="${2:-}"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

resolve_mode() {
  if [[ -n "$MODE" ]]; then
    echo "$MODE"
    return
  fi
  if [[ -f "$HOME/.armory/config.json" ]]; then
    mode_from_cfg="$(python3 - "$HOME/.armory/config.json" <<'PY'
import json,sys
path=sys.argv[1]
try:
    obj=json.load(open(path))
except Exception:
    print("")
    raise SystemExit(0)
raw=str(obj.get("mode","")).strip().lower()
if raw=="civ":
    print("civ")
elif raw in {"saga","lore","crystal"}:
    print("saga")
elif obj.get("civilianAliases") is True:
    print("civ")
else:
    print("")
PY
)"
    if [[ -n "$mode_from_cfg" ]]; then
      echo "$mode_from_cfg"
      return
    fi
  fi
  if [[ "${ARMORY_MODE:-}" == "civ" || "${SOVEREIGN_MODE:-}" == "civ" ]]; then
    echo "civ"
  else
    echo "${shSingleQuote(defaultMode)}"
  fi
}

RESOLVED_MODE="$(resolve_mode)"
BUNDLES_JSON='${bundlesJson}'
TOOL_IDS_JSON='${toolIdsJson}'
TELEMETRY_ENDPOINT='${shSingleQuote(telemetryEndpoint)}'
MANIFEST_REF='${shSingleQuote(ref)}'

python3 - "$INSTALL_ROOT" "$BUNDLES_JSON" <<'PY'
import hashlib, json, os, pathlib, sys, urllib.request

install_root = pathlib.Path(sys.argv[1]).expanduser().resolve()
bundles = json.loads(sys.argv[2])
install_root.mkdir(parents=True, exist_ok=True)

for bundle in bundles:
    dest = install_root / bundle["path"]
    dest.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(bundle["url"]) as resp:
        data = resp.read()
    dest.write_bytes(data)
    sha = (bundle.get("sha256") or "").strip()
    if sha:
        actual = hashlib.sha256(data).hexdigest().lower()
        if actual != sha.lower():
            raise SystemExit(f"Hash mismatch for {bundle['path']}")
PY

if [[ "$NO_TELEMETRY" -eq 0 && "${ARMORY_TELEMETRY:-on}" != "off" && -n "$TELEMETRY_ENDPOINT" ]]; then
  python3 - "$TELEMETRY_ENDPOINT" "$TOOL_IDS_JSON" "$RESOLVED_MODE" "$MANIFEST_REF" <<'PY'
import json, pathlib, sys, uuid, urllib.request
from datetime import datetime, timezone

endpoint, tool_ids_json, mode, manifest_ref = sys.argv[1:5]
home = pathlib.Path.home()
install_id_file = home / ".armory" / "install-id.txt"
install_id_file.parent.mkdir(parents=True, exist_ok=True)
if install_id_file.exists():
    install_id = install_id_file.read_text(encoding="utf-8").strip()
else:
    install_id = str(uuid.uuid4())
    install_id_file.write_text(install_id + "\\n", encoding="utf-8")

payload = {
    "eventName": "install_completed",
    "installId": install_id,
    "sessionId": str(uuid.uuid4()),
    "source": "installer",
    "toolIds": json.loads(tool_ids_json),
    "mode": mode,
    "manifestRef": manifest_ref,
    "timestamp": datetime.now(timezone.utc).isoformat(),
}

req = urllib.request.Request(
    endpoint.rstrip("/") + "/v1/events",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
try:
    urllib.request.urlopen(req, timeout=5).read()
except Exception:
    pass
PY
fi

if [[ "$RESOLVED_MODE" == "civ" ]]; then
  echo "Install complete. Tooling is ready."
  echo "Installed: $(python3 - <<'PY'
import json
print(", ".join(sorted(json.loads('${toolIdsJson}'))))
PY
)"
else
  echo "Loadout equipped. The party is battle-ready."
  echo "Equipped materia: $(python3 - <<'PY'
import json
print(", ".join(sorted(json.loads('${toolIdsJson}'))))
PY
)"
fi
`;
}

function downloadTextFile(fileName, text) {
  const blob = new Blob([text], { type: "text/plain;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = fileName;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

async function emitTelemetry(eventName, toolIds = []) {
  if (state.telemetryOptOut) return;
  const endpoint = state.manifest?.telemetry?.endpoint;
  if (!endpoint) return;

  const payload = {
    eventName,
    installId: crypto.randomUUID(),
    sessionId: crypto.randomUUID(),
    source: "dashboard",
    toolIds,
    mode: state.mode,
    manifestRef: state.manifest.ref,
    timestamp: new Date().toISOString(),
  };

  try {
    await fetch(`${endpoint.replace(/\/$/, "")}/v1/events`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      keepalive: true,
    });
  } catch {
    // non-blocking
  }
}

function startTour() {
  state.tourIndex = 0;
  const steps = tourSteps();
  el.tourOverlay.classList.remove("hidden");
  el.tourOverlay.setAttribute("aria-hidden", "false");

  function renderStep() {
    const step = steps[state.tourIndex];
    el.tourTitle.textContent = step.title;
    el.tourBody.textContent = step.body;
    el.tourNext.textContent = state.tourIndex >= steps.length - 1 ? "Finish" : "Next";
  }

  function closeTour() {
    el.tourOverlay.classList.add("hidden");
    el.tourOverlay.setAttribute("aria-hidden", "true");
    markTourSeen();
    el.tourNext.onclick = null;
    el.tourSkip.onclick = null;
  }

  el.tourNext.onclick = () => {
    if (state.tourIndex >= steps.length - 1) {
      closeTour();
      return;
    }
    state.tourIndex += 1;
    renderStep();
  };

  el.tourSkip.onclick = closeTour;
  renderStep();
}

async function loadManifest() {
  const resp = await fetch(MANIFEST_PATH, { cache: "no-store" });
  if (!resp.ok) throw new Error(`Manifest load failed (${resp.status})`);
  state.manifest = await resp.json();
  state.entries = state.manifest.entries || [];
}

function bindEvents() {
  el.modeSaga.addEventListener("click", () => setMode("saga"));
  el.modeCiv.addEventListener("click", () => setMode("civ"));

  for (const ctrl of [el.searchInput, el.classFilter, el.statusFilter]) {
    ctrl.addEventListener("input", renderCatalog);
    ctrl.addEventListener("change", renderCatalog);
  }

  el.approveCheck.addEventListener("change", () => renderCart());
  el.replayTour.addEventListener("click", startTour);
  el.telemetryOptOut.addEventListener("change", () => {
    state.telemetryOptOut = el.telemetryOptOut.checked;
    try {
      localStorage.setItem("telemetryOptOut", state.telemetryOptOut ? "1" : "0");
    } catch {
      // ignore storage errors
    }
  });

  el.checkoutBtn.addEventListener("click", async () => {
    const loadout = resolveLoadout();
    const script = createInstallerScript(loadout);
    downloadTextFile("armory-loadout-installer.sh", script);
    await emitTelemetry("installer_generated", loadout.map((x) => x.id));
  });
}

async function init() {
  bindEvents();

  try {
    state.telemetryOptOut = localStorage.getItem("telemetryOptOut") === "1";
    el.telemetryOptOut.checked = state.telemetryOptOut;
  } catch {
    state.telemetryOptOut = false;
  }

  await loadManifest();
  setMode(state.mode);
  renderCart();

  if (shouldAutoStartTour()) startTour();
  await emitTelemetry("dashboard_loaded", []);
}

init().catch((err) => {
  console.error(err);
  el.catalogGrid.innerHTML = `<article class=\"card\"><strong>Dashboard failed to load</strong><div>${String(
    err.message || err
  )}</div></article>`;
});
