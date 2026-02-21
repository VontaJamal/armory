const TOUR_KEY = "armory_tour_seen_v1";

const STEPS = [
  {
    title: "Welcome To The Armory",
    body: "This dashboard lets you scout tools, build a loadout, and generate a one-shot installer.",
  },
  {
    title: "Pick Your Voice",
    body: "Use Crystal Saga Mode for themed language, or Civilian Mode for plain language.",
  },
  {
    title: "Scout The Shop",
    body: "Search and filter divisions to find what fits your current repo problem.",
  },
  {
    title: "Approve Then Equip",
    body: "Add tools to cart, review dependencies, check approval, then generate the installer.",
  },
];

export function shouldAutoStartTour() {
  try {
    return localStorage.getItem(TOUR_KEY) !== "1";
  } catch {
    return true;
  }
}

export function markTourSeen() {
  try {
    localStorage.setItem(TOUR_KEY, "1");
  } catch {
    // ignore storage errors
  }
}

export function tourSteps() {
  return STEPS;
}
