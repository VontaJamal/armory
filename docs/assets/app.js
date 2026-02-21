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

function psSingleQuote(value) {
  return String(value).replace(/'/g, "''");
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

  const bundlesJson = psSingleQuote(JSON.stringify(bundles));
  const toolIdsJson = psSingleQuote(JSON.stringify(loadout.map((x) => x.id)));

  return `# Armory one-shot installer
# Generated from manifest ${generatedAt}

param(
  [ValidateSet('saga','civ')]
  [string]$Mode,
  [switch]$Civ,
  [switch]$Saga,
  [switch]$NoTelemetry,
  [string]$InstallRoot = (Join-Path $PWD 'armory-loadout')
)

$ErrorActionPreference = 'Stop'

function Resolve-Mode {
  if ($Civ) { return 'civ' }
  if ($Saga) { return 'saga' }
  if ($Mode) { return $Mode }

  $cfg = Join-Path $env:USERPROFILE '.armory\\config.json'
  if (Test-Path $cfg) {
    try {
      $obj = Get-Content -Path $cfg -Raw | ConvertFrom-Json
      if ($obj.PSObject.Properties.Name -contains 'mode') {
        $raw = [string]$obj.mode
        if ($raw -eq 'civ') { return 'civ' }
        if ($raw -in @('saga','lore','crystal')) { return 'saga' }
      }
      if ($obj.PSObject.Properties.Name -contains 'civilianAliases') {
        if ([bool]$obj.civilianAliases) { return 'civ' }
      }
    } catch {}
  }

  $repoCfg = Join-Path $PWD '.sovereign.json'
  if (Test-Path $repoCfg) {
    try {
      $obj = Get-Content -Path $repoCfg -Raw | ConvertFrom-Json
      if ($obj.PSObject.Properties.Name -contains 'mode') {
        $raw = [string]$obj.mode
        if ($raw -eq 'civ') { return 'civ' }
        if ($raw -in @('saga','lore','crystal')) { return 'saga' }
      }
    } catch {}
  }

  if ($env:ARMORY_MODE -eq 'civ' -or $env:SOVEREIGN_MODE -eq 'civ') { return 'civ' }
  return '${psSingleQuote(defaultMode)}'
}

function File-Sha256([string]$Path) {
  return (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Emit-Telemetry([string]$EventName, [string[]]$ToolIds, [string]$ResolvedMode) {
  if ($NoTelemetry) { return }
  if ($env:ARMORY_TELEMETRY -eq 'off') { return }
  $endpoint = '${psSingleQuote(telemetryEndpoint)}'
  if (-not $endpoint) { return }

  $installIdFile = Join-Path $env:USERPROFILE '.armory\\install-id.txt'
  $installId = if (Test-Path $installIdFile) { Get-Content -Path $installIdFile -Raw } else { [guid]::NewGuid().ToString() }
  if (-not (Test-Path $installIdFile)) {
    New-Item -ItemType Directory -Path (Split-Path $installIdFile -Parent) -Force | Out-Null
    Set-Content -Path $installIdFile -Value $installId -Encoding UTF8
  }

  $payload = @{
    eventName = $EventName
    installId = $installId.Trim()
    sessionId = [guid]::NewGuid().ToString()
    source = 'installer'
    toolIds = $ToolIds
    mode = $ResolvedMode
    manifestRef = '${psSingleQuote(ref)}'
    timestamp = (Get-Date).ToString('o')
  } | ConvertTo-Json -Depth 8

  try {
    Invoke-RestMethod -Uri ($endpoint.TrimEnd('/') + '/v1/events') -Method Post -ContentType 'application/json' -Body $payload | Out-Null
  } catch {}
}

$resolvedMode = Resolve-Mode
$bundles = '${bundlesJson}' | ConvertFrom-Json
$toolIds = '${toolIdsJson}' | ConvertFrom-Json

foreach ($bundle in $bundles) {
  $dest = Join-Path $InstallRoot $bundle.path
  New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force | Out-Null
  Invoke-WebRequest -Uri $bundle.url -OutFile $dest -UseBasicParsing

  if ($bundle.sha256) {
    $actual = File-Sha256 -Path $dest
    if ($actual -ne [string]$bundle.sha256) {
      throw "Hash mismatch for $($bundle.path)"
    }
  }
}

Emit-Telemetry -EventName 'install_completed' -ToolIds $toolIds -ResolvedMode $resolvedMode

if ($resolvedMode -eq 'civ') {
  Write-Host 'Install complete. Tooling is ready.' -ForegroundColor Green
  Write-Host ("Installed: {0}" -f (($toolIds | Sort-Object) -join ', ')) -ForegroundColor Gray
} else {
  Write-Host 'Loadout equipped. The party is battle-ready.' -ForegroundColor Green
  Write-Host ("Equipped materia: {0}" -f (($toolIds | Sort-Object) -join ', ')) -ForegroundColor Gray
}
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
    downloadTextFile("armory-loadout-installer.ps1", script);
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
