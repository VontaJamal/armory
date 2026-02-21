const KEY = "armory_mode";
const MODE_VALUES = new Set(["saga", "civ"]);

export function normalizeMode(raw) {
  if (!raw) return "saga";
  const v = String(raw).trim().toLowerCase();
  if (v === "civ") return "civ";
  if (v === "saga" || v === "lore" || v === "crystal") return "saga";
  return "saga";
}

export function modeFromUrl(search = window.location.search) {
  const params = new URLSearchParams(search);
  const raw = params.get("mode");
  if (!raw) return null;
  const mode = normalizeMode(raw);
  return MODE_VALUES.has(mode) ? mode : null;
}

export function modeFromStorage() {
  try {
    const raw = localStorage.getItem(KEY);
    return raw ? normalizeMode(raw) : null;
  } catch {
    return null;
  }
}

export function persistMode(mode) {
  try {
    localStorage.setItem(KEY, normalizeMode(mode));
  } catch {
    // ignore storage errors
  }
}

export function resolveMode() {
  return modeFromUrl() || modeFromStorage() || "saga";
}
