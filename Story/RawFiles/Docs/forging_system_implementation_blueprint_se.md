## Forging System (SE Required) — Implementation Blueprint

## Scope and hard rules
- **Script Extender is required**.
- **Slot 1 decides base weapon type**: the item placed in the first slot is the “base identity” (template/stats entry) for the forged result.
- **Rarity is decided first** (per `rarity_system.md`).
- Only **rollable modifiers** are merged/rolled. **Innate/base weapon properties** are preserved by choosing the base weapon from slot 1.

## Recommended architecture
- **Crafting recipe (data)**: a single “forge” recipe that triggers your system via the vanilla crafting UI.
- **Story/Osiris hook (control plane)**: detects that your forge recipe was executed and passes GUIDs to Lua.
- **Lua (Script Extender) logic (data plane)**: reads both parent items, computes rarity + inherited rolls, spawns/updates the result item, and consumes parents.

## Core concepts you must keep distinct

### Innate (non-rollable) weapon identity
These come from the weapon’s base stat entry + its inheritance chain in `Weapon.stats` (e.g. `WPN_Staff_Fire` → `_Staffs_Fire` → `_Staffs`).
Typical innate examples:
- Base damage line (e.g. `311–381 Fire`)
- Base `CriticalDamage` (often `150%`)
- Range / durability / requirements
- Granted skills (e.g. Staff of Magus)
- Elemental wand/staff behaviour shown as blue lines (e.g. “Creates an Ice surface…”, “Ignite;Melt”) — these are commonly archetype `ExtraProperties`

These should **not** enter your forgeable pool.

### Rollable modifiers (“blue stat rolls”)
These are implemented as **boosts/affixes** (commonly `_Boost_*`) selected from roll tables.
Typical rollable examples:
- Attribute bonuses (`+Intelligence`, `+Finesse`, etc.)
- Accuracy, Critical Chance, Life Steal, etc.
- “Set X for 1 turn(s). Y% chance…” effects (status-chance lines)

In vanilla data, many “Set status” lines are boosts whose payload is encoded via `ExtraProperties` on the boost definition (e.g. `BLIND,20,1`, `MUTED,10,1`).

## Canonical base-game data sources (editor data)
You will not read these `.stats` files at runtime via Story. Use Script Extender to read item instance data and/or ship precompiled lookup tables derived from these files.

### Roll tables / eligibility (what can roll, and constraints)
- `DefEd/Data/Editor/Mods/Shared/Stats/DeltaModifier/DeltaModifier.stats`
  - Contains weapon roll candidates (`Boost_*`) and constraints such as:
    - `ModifierType = Weapon`
    - `WeaponType` (Knife/Sword/Bow/etc.)
    - `Handedness` (1H vs 2H)

### Boost definitions (what the roll actually does)
- `DefEd/Data/Editor/Mods/Shared/Stats/Stats/Weapon.stats`
  - Contains `_Boost_Weapon_*` definitions.
  - Status-chance boosts live here, e.g. `_Boost_Weapon_Status_Set_Blind` with `ExtraProperties = BLIND,10,1`.

## Implementation blueprint (step-by-step)

## Step 0: Ingredient eligibility (reject rune-modified weapons)
Hard rule: **weapons that have any rune socket effects must not be accepted as forging ingredients**.

Reject an ingredient if **either** is true:
- **Runes are inserted** into any socket (even if the rune only grants “utility” effects).
- The weapon has **any stats modifiers and/or granted skills originating from rune sockets**.

Implementation notes (SE):
- Treat this as an early guard (before rarity and stat processing). If invalid, abort the craft and return items unchanged.
- Prefer a robust check that does not rely on tooltip text. Options:
  - **Socket-content check**: enumerate socketed rune items on the weapon (if any present → reject).
  - **Rune-effect check**: inspect the weapon’s generated stats/properties for rune-origin boosts/skills and reject if found.

## Step 1: Create a deterministic “forge” crafting recipe
Goal: trigger your logic reliably and preserve slot ordering.

Recommended:
- Create a recipe that requires **exactly two weapons** (or a strict weapon-tag filter).
- Recipe output should be a **dummy token item** (e.g. `FORGE_ResultToken`) that Lua deletes/replaces.

Why a token output?
- Crafting outputs are otherwise static; you need a dynamic output based on **slot 1**.
- A token makes it obvious which craft results belong to your system.

Critical validation:
- Confirm whether the engine preserves slot ordering for your recipe callback (slot 1 vs slot 2).
  - If ordering is not stable, introduce a workaround (e.g. a “base selector” catalyst item) and treat that as a must-fix risk before implementing stat logic.

## Step 2: Hook recipe completion and capture GUIDs
Goal: detect “forge craft happened” and capture:
- Crafter character GUID
- Slot 1 ingredient item GUID (base)
- Slot 2 ingredient item GUID (feed)
- Crafted output token GUID

Guidance:
- Filter on your specific recipe/result template/tag so you do not affect normal crafting.
- Pass GUIDs into Lua via the Script Extender bridge.

## Step 3: In Lua, determine base weapon identity (slot 1 hard rule)
Inputs:
- `baseItem` = slot 1 ingredient
- `feedItem` = slot 2 ingredient

Output:
- `baseStatsId` and/or `baseTemplateId` used to spawn the forged item.

Rule:
- The forged item’s innate behaviour comes from `baseItem`’s identity.
- The feed item contributes only rollable modifiers and rarity influence.

## Step 4: Decide rarity (your `rarity_system.md`)
Inputs:
- `rarityA`, `rarityB` (from the parent items)

Outputs:
- `rarityOut`
- `maxAllowed` (your rarity cap, if you keep your cap table)

Notes:
- Unique (ID 8) should follow your “Unique dominance” rule.
- Do not mix in rollable stats yet; just compute rarity/cap.

## Step 5: Extract each parent’s rollable modifiers from the item instance
Goal: build the two modifier lists you will feed into the inheritance algorithm.

You need a normalised representation per modifier, such as:
- `key`: stat identity (e.g. `Intelligence`, `Accuracy`, `LifeSteal`, `StatusSet:BLIND`)
- `value`: magnitude payload (e.g. `+4`, `+10%`, or `{chance=10, turns=1}`)
- `source`: the underlying boost/affix identifier(s) so you can reapply cleanly

### How to classify a tooltip line reliably
Do not rely on colour. Use provenance:
- **Innate**: originates from base stat entry/archetype fields (damage/range/skills/archetype `ExtraProperties`).
- **Rollable**: originates from generated boosts/affixes on the item instance.

Practical classifier:
- If the effect is represented by a `_Boost_*` on the item (or in its generated stats container), treat it as rollable.
- If it only exists in the base stat entry inheritance chain, treat it as innate.

### Status-chance lines are rollable (even though they use `ExtraProperties`)
In vanilla, they are boosts whose **boost definition** carries an `ExtraProperties` payload, e.g.:
- `BLIND,10,1`
- `MUTED,10,1` (Silence family)
- `CRIPPLED,10,1`
- etc.

Normalise them into keys like:
- `StatusSet:BLIND` with value `{chance=10, turns=1}`

### Caveat: re-forging previously forged weapons
If a forged weapon is used as an ingredient in a later forge, **the rollable-stat retrieval logic should be the same** as for any other weapon:
- Extract rollable modifiers from the item instance (boosts/affixes).
- Treat innate/base weapon identity as non-rollable (slot 1 still decides the output base identity).

However, ensure you **exclude any forge metadata/markers** you add for bookkeeping (tags, debug boosts, “forged-by-system” flags, etc.):
- These must not be counted as rollable stats.
- They must not enter shared/pool/cap calculations.

## Step 6: Compute forged rollable modifiers (your `inheritance_system.md`)
Inputs:
- `parentA_rollable[]`
- `parentB_rollable[]`
- `rarityOut` → `maxAllowed`

Outputs:
- `forged_rollable[]` (the list you will apply)

Algorithm (as per your doc):
- Split into `sharedStats` by key and `poolStats` for non-shared.
- Merge values for shared stats where values differ (your merge formula).
- Roll how many pool stats to keep (tiered luck shift).
- Apply cap last; if over cap, remove pool-picked entries first.

Important implementation detail:
- Many vanilla rolls are **tier-based boosts** (Small/Medium/Large) rather than continuous numbers.
  - Decide early whether you:
    - keep continuous merging and map to the nearest tier on apply, or
    - merge by tier index (simpler and closer to vanilla).

## Step 7: Create the forged item (spawn, then replace token)
Recommended:
- Delete the crafted output token item.
- Spawn a new item that matches slot 1’s base identity:
  - same base template/stats entry
  - appropriate level (commonly base item’s level; or define a level rule)
  - set rarity to `rarityOut`

Why spawn instead of mutating the token?
- It ensures innate/base properties are correct by construction.
- It avoids “leftover” generated stats from the token.

## Step 8: Apply rollable modifiers to the forged item
This is the key SE-only step.

Pick one strategy and keep it consistent.

### Strategy A (recommended): apply by boost ids / affixes
- Clear any existing generated boosts on the forged item.
- Apply the exact boost ids corresponding to your computed `forged_rollable[]`.

Pros:
- Matches vanilla structure.
- Tooltip lines should match expectations.

Cons:
- Requires you to manipulate the item’s generated stats container correctly.

### Strategy B: apply as permanent stat changes
- Apply the computed effects directly (attributes, crit chance, life steal, status-chance procs).

Pros:
- Often simpler.

Cons:
- Can diverge from vanilla serialisation and tooltip formatting.
- Harder to keep parity with roll tables.

Recommendation:
- Start with Strategy A; fall back to B only if the API surface blocks you.

## Step 9: Consume parents and deliver result
Decide explicitly whether you mutate-in-place or replace.

Recommended behaviour:
- Destroy both parents.
- Add forged item to the crafter’s inventory (or drop at feet if inventory is full).

## Step 10: Debugging and observability (must-have)
Add a debug toggle (global variable or mod setting) that logs:
- ingredient GUIDs and base stats/template ids
- extracted rollable list per parent (normalised + source boost ids)
- rarity decision output
- final forged rollable list
- confirmation of spawned item and parent deletion

Also add a “dump item” dev command that prints:
- base stats id/template id
- current applied boosts/affixes
- any dynamic/generated stat entries used to drive the tooltip

## Classification quick reference

### Common tooltip lines and classification
| Tooltip line type | Example | Rollable? | Why |
| --- | --- | --- | --- |
| Base damage line | `311–381 Fire` | No | Base stat entry + level scaling |
| Base crit damage | `150% Critical Damage` | No | Weapon archetype field |
| Attribute bonus | `+4 Intelligence` | Yes | Boost/affix |
| Accuracy / crit chance | `+10% Accuracy` | Yes | Boost/affix |
| Life steal | `+14% Life Steal` | Yes | Boost/affix |
| Status-chance proc | `Set Blinded… 20%…` | Yes | Boost; payload encoded via boost `ExtraProperties` |
| Elemental wand/staff surface behaviour | “Creates Ice surface…” / “Ignite;Melt” | No | Archetype `ExtraProperties` (weapon identity) |
| Granted skill | `Staff of Magus` | No | Archetype `Skills` |
| Rune slot lines | “Empty slot” | Usually no | Typically tracked separately via `RuneSlots`; treat as its own system |

## Example walk-through (slot 1 staff, slot 2 wand)
Slot 1: Fire staff (base identity; keep Ignite/Melt + Staff of Magus)
Slot 2: Water wand (feed; contributes rollable modifiers and rarity influence)

Output:
- Base weapon remains a Fire staff.
- Rarity is calculated from both items.
- Rollable pool is the union of both items’ rollable boosts.
- Staff innate effects remain regardless of roll outcomes.
- Rollable status lines (Blind/Muted/etc.) are candidates if present on either parent.

## Acceptance checklist
- Forge recipe triggers reliably and captures **slot ordering**.
- Output item identity always matches slot 1.
- Innate behaviours (elemental surfaces, granted skills, base damage/range) are preserved automatically.
- Rollable modifiers are:
  - extracted from parents correctly,
  - merged/rolled per your docs,
  - applied so tooltips match expectations.
- Parents are removed; output is delivered.
- Debug mode produces a complete before/after audit for a single forge.

## Known risks (track explicitly)
- Slot ordering may not be stable: validate early.
- Mapping merged continuous values to tiered boosts must be defined.
- Unique items (rarity 8) require special handling per your doc (identity preservation + “fuel” behaviour).


