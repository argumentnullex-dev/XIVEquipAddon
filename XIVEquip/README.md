# XIVEquip – “Equip Recommended Gear” for WoW

**XIVEquip** brings the FFXIV-style “Equip Recommended Gear” button to World of Warcraft.

- Click one button → it **plans** the best upgrades in your bags and **equips** them.
- Uses **Pawn** weights when available; falls back to a clear **stat/ilvl** score when not.
- Handles **armor**, **jewelry** (rings/trinkets are unique), and **weapons** (legal combos only).
- Optional: **Auto‑equip on spec change**, then auto‑saves an equipment set named **`Spec.xive`**.

> MIT-style license. Not affiliated with Square Enix or Pawn; big thanks to the Pawn authors ♥.

---

## Features

- **Planner-first flow**
  - `PlanBest` computes the full list of items to equip; `EquipBest` just commits the plan (no re-search during equip).
- **Pawn integration**
  - If Pawn is installed and a scale is active, XIVEquip scores with your **current spec’s** scale.
  - If Pawn isn’t available or returns no value, XIVEquip falls back to a transparent **stat/ilvl** score (with debug so you can see each stat’s contribution).
- **Weapons done right**
  - Legal combos only, scored via your comparer.
  - Examples: Protection Paladin requires **1H + Shield** (Holy may use **Holdable/Frill**); your weights decide winners.
- **Rings & Trinkets**
  - Picks **two distinct** items; never re-uses the same ring or trinket.
- **Auto-equip on spec change (optional)**
  - When you swap specs, XIVEquip equips your best gear for that spec and saves a set **`Spec.xive`** (e.g., `Protection.xive`).
- **Predictable debug**
  - Slot-filtered logs with a “force” bypass; detailed fallback scoring traces when wanted.

---

## Installation

1. Copy the **XIVEquip** folder into `World of Warcraft/_retail_/Interface/AddOns/`.
2. (Optional) Install **Pawn** to use your custom scales for scoring.
3. Launch the game and enable **XIVEquip** in the AddOns list.

---

## Usage

- Open your **Character panel** and click the **XIVEquip** button to plan & equip upgrades.
- To enable **auto-equip on spec change**, open **Game Menu → Options → AddOns → XIVEquip** and tick
  **“Auto‑equip & save set on spec change”.**

### Slash commands

- `/xiveauto` — toggle auto‑equip on spec change
- `/xiveauto test` — run a one‑off auto‑equip (useful for testing)

---

## Settings

Open **Game Menu → Options → AddOns → XIVEquip**:

- **Active comparer** – How items are scored.
  *Default:* **Auto (Pawn → ilvl)** — use Pawn if available; otherwise a safe fallback.
- **Messages** – Toggle login and equip change messages.
- **Debug logging** – Developer‑oriented logs (see debug toggles below).
- **Auto‑equip on spec change** – Auto‑equip & save *Spec.xive* set on spec swap.

---

## Debugging (optional)

Enable logging from the in‑game console:

```lua
/run XIVEquip_Debug = true                 -- master debug on
/run XIVEquip_DebugSlot = 6               -- only log Waist (slot 6); set nil to log all
/run XIVEquip_DebugAutoSpec = true        -- verbose auto-spec logs
```

Passing "force" as the first argument to `Log.Debugf("force", ...)` bypasses the slot filter; the addon uses this for a few global lines already.

---

## File Structure (for devs)

- **Gear_Core.lua** — Public API & helpers
  Item/slot maps, link helpers, `equippedBasics`, `itemGUID`, `getItemLevelFromLink`, `scoreItem` (uses Pawn or fallback), `chooseForSlot`, `appendPlanAndChange`, logging shims.
- **Armor.lua / Jewelry.lua / Weapons.lua** — Slot planners
  Each exports `:PlanBest(cmp, opts, used)` and returns `(changes, pending, plan)`.
- **Gear.lua** — Orchestrator
  Merges planner results and `EquipBest` simply commits the final **plan**. After equip, defers a save of the spec‑named equipment set **`Spec.xive`** (reads spec *after* swap settles).
- **Pawn.lua / Pawn_Comparer.lua** — Pawn adapter
  Robust scale selection (spec index + name matching), scoring helpers, and stat fallback scoring (`GetItemStats` normalization for `_SHORT` tokens and `RESISTANCE0_NAME` base armor).
- **UI.lua** — Options panel & character button.
- **AutoSpecSwitcher.lua** — Listens to spec change events; throttled, combat‑safe; calls `Gear:EquipBest()`.
- **Logger.lua** — Formatted, slot‑filtered debug with a "force" bypass.

---

## FAQ

**Do I need Pawn?**
No, but it’s recommended. Without Pawn, XIVEquip uses a transparent stat/ilvl fallback that you can debug in logs.

**Why did it pick a lower item level?**
Because your **weights** said it’s better (e.g., a haste/vers piece may beat crit/mastery at lower ilvl for your spec). Turn on debug to see the exact score breakdown.

**Why two different rings/trinkets?**
Intended. The planner keeps them unique so you don’t equip the same item twice.

**It saved the set under the wrong spec name.**
We defer the save and re‑read the active spec after swap. If you still see odd timing on your client, increase the delay in `C:_saveSpecSetSoon(0.7)` to `1.0` in `Gear.lua`.

---

## Contributing

- Issues and PRs welcome—please keep changes **surgical** and split by file (Core vs planners vs UI).
- Keep **Gear_Core.lua** backward‑compatible; it is the public API surface.

---

## License

MIT-style. See the file headers or `LICENSE` for details.

**Credits:** Inspired by the FFXIV “Equip Recommended Gear” feature and Pawn © their authors. Thanks to everyone who helped test and iterate.
