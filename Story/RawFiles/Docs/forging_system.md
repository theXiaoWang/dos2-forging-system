# Forging System

## What this system does

This system provides a sophisticated and hardcore RPG forging experience. 

The mod aims to increase playability and you can expect a big time investment through a fun, deep forging system. It gives players a true sense of growth with their gear as the game progresses; From common to legendary, every item can be upgraded, improved or used as a fuel resource, no more absolute "junk items". This creates a greater sense of achievement and allows players to forge and customize their dream items, which need strategies, calculations, and luck, or just YOLO it.

---
You can only forge same kind of items together, e.g. weapon ↔ weapon (can be same type or cross type), shield ↔ shield, armour ↔ armour etc. You cannot forge two different kinds of items together. Additionally, the two items must be at least the player's level or above to forge (player is level 10, the items must be >= level 10 to forge), and the result is always the player's level. The forge UI allows player to scale the items to the player's level before forging.

When you forge two items, the forged result:

- Always stays the same type of item as the **item you put in the Main Slot** (first slot), both parents will be consumed (e.g. forge a sword (Main Slot) and a staff (Secondary Slot) together, you get a new sword back, but both parents will be consumed).
- Rolls the forged item's **rarity** first (Common, Rare, Epic, etc.) depends on the parents' rarities, which decides how many maximum Stats Modifiers the result can have (e.g. Blue Stats, Extra Properties, Granted Skills).
- Carries over and merges the item's **base values** (the white numbers you see, e.g. damage for weapons, armour for armour pieces), usually favouring the Main Slot ingredient (Note: Only **Same-Type weapon forge WILL** inherit the base damage, **Cross-Type weapon forge WILL NOT** inherit the base damage).
- For same-type weapon, forging can also inherit **weapon boosts** (extra damage types or effects, e.g. fire damage, poison damage, piercing damage, etc.) (e.g. 2H Sword with Air damage + 2H Sword with Fire damage, not 2H Sword with X damage + 2H Axe with Y damage).
- Carries over and merges **blue stats and skills** for both same-type and cross-type weapon forging (e.g. +Strength, +Warfare, granted skills like Shout_Whirlwind).
- Only for weapons, expect **Same-Type weapon forge** yields better chance to inherit Stats Modifiers than **Cross-Type weapon forge** (e.g. 2H Sword + 2H Sword can sometimes **2X the chance** to get a good result than 2H Sword + 2H Axe), but for other item types such as armour, the chance defaults to cross-type.
- Inherits everything else using a simple rule: **matching lines stay** (e.g. both items have +Strength), and **non-matching lines are a chance-based roll** from everything the two items have between them (e.g. one has +Finesse, the other has +Intelligence — you might get one, both, or neither).

In short:
- More overlap between the two items → more stable outcomes and safe progression.
- Less overlap → more randomness, unless you hit the jackpot or just want to YOLO.

<details>
<summary><strong>Contents (click to expand)</strong></summary>

<details>
<summary><strong><a href="#1-forge-preconditions">1. Forge preconditions</a></strong></summary>

- [1.1. Ingredient eligibility](#11-ingredient-eligibility)
- [1.2. Forge flow overview](#12-forge-flow-overview)
- [1.3. Deterministic randomness (seed + multiplayer)](#13-deterministic-randomness-seed--multiplayer)
</details>

<details>
<summary><strong><a href="#2-base-values-inheritance">2. Base values Inheritance</a></strong></summary>

- [2.1. What "base values" means (and why levels must be normalised)](#21-base-values-definition)
- [2.2. Output + eligibility rules (including the level gate)](#22-output-rules-leveltyperarity)
- [2.3. Inputs, notation, and tuning](#23-inputs-and-tuning-parameters)
- [2.4. Measuring parents + SE normalisation (ratio-preserving levelling)](#24-baseline-budget-cache-and-parent-measurement)
- [2.5. Merge algorithms (weapons and non-weapons)](#25-merge-algorithm-percentiles-to-output-base-values)
- [2.6. Worked examples (including level normalisation)](#26-worked-examples-base-values)
- [2.7. Implementation checklist (SE; base values)](#27-implementation-checklist-se-base-values)
</details>

<details>
<summary><strong><a href="#3-weapon-boost-inheritance">3. Weapon Boost Inheritance</a></strong></summary>

- [3.1. Weapon boosts (definition)](#31-weapon-boosts-definition)
- [3.2. Inheritance rules](#32-weapon-boost-inheritance-rules)
- [3.3. Worked examples](#33-weapon-boost-worked-examples)
- [3.4. Implementation checklist (SE; weapon boosts)](#34-implementation-checklist-se-weapon-boosts)
</details>

<details>
<summary><strong><a href="#4-stats-modifiers-inheritance">4. Stats Modifier Inheritance</a></strong></summary>

- [4.1. Introduction + design principles](#41-stats-modifiers-definition)
- [4.2. Selection rule (all modifiers)](#42-selection-rule-shared--pool--cap)
- [4.3. Merging rule (Blue Stats + ExtraProperties)](#43-merging-rule-how-numbers-are-merged)
- [4.4. Blue Stats](#44-blue-stats-channel)
  - [4.4.1. Blue Stats (definition)](#441-blue-stats-definition)
  - [4.4.2. Shared vs pool (Blue Stats)](#442-shared-vs-pool-blue-stats)
  - [4.4.3. Worked examples (Blue Stats)](#443-worked-examples-blue-stats)
- [4.5. ExtraProperties](#45-extraproperties-inheritance)
  - [4.5.1. ExtraProperties (definition)](#451-extraproperties-definition)
  - [4.5.2. Shared vs pool tokens](#452-extraproperties-shared-vs-pool)
  - [4.5.3. Selection + internal cap](#453-extraproperties-selection--internal-cap)
  - [4.5.4. Slot competition + trimming](#454-extraproperties-slot-competition--trimming)
  - [4.5.5. Worked examples](#455-worked-examples)
- [4.6. Skills](#46-skills-inheritance)
  - [4.6.1. Granted skills (definition)](#461-granted-skills-definition)
  - [4.6.2. Skill cap by rarity](#462-skill-cap-by-rarity)
  - [4.6.3. Shared vs pool skills](#463-shared-vs-pool-skills)
  - [4.6.4. How skills are gained (gated fill)](#464-how-skills-are-gained-gated-fill)
  - [4.6.5. Scenario tables](#465-scenario-tables)
  - [4.6.6. Worked example (Divine)](#466-worked-example-divine)
</details>

<details>
<summary><strong><a href="#5-rune-slots-inheritance">5. Rune slots inheritance</a></strong></summary>
</details>

<details>
<summary><strong><a href="#6-implementation-reference">6. Implementation reference</a></strong></summary>
</details>

<details>
<summary><strong><a href="#7-unique-forging-temporary">7. Unique forging (temporary)</a></strong></summary>

- [7.1. Unique preconditions (fuel-only)](#71-unique-preconditions-fuel-only)
- [7.2. Output identity + slot priority (Unique dominance)](#72-unique-output-identity-and-slot-priority)
- [7.3. Channel rules (base values + weapon boosts are Unique-locked)](#73-unique-channel-rules-base-and-boosts-locked)
- [7.4. Snapshot model (base template + innate modifiers)](#74-unique-snapshot-model)
- [7.5. Unique max-slot growth (cap expansion via fuel)](#75-unique-max-slot-growth)
- [7.6. Innate modifiers: always kept, merged but never below snapshot](#76-unique-innate-modifiers-floor)
- [7.7. Non-innate modifiers: acquisition + instability rules](#77-unique-non-innate-modifiers)
- [7.8. Extract (rollback) + extracted-item generation](#78-unique-extract-rollback)
- [7.9. Extracted item rarity and “instance-only overcap Divine”](#79-extracted-item-rarity-overcap-divine)
- [7.10. Ascendancy Points (AP): capacity + upgrades](#710-unique-ascendancy-points)
</details>

</details>

---

## 1. Forge preconditions
<a id="1-forge-preconditions"></a>

### 1.1. Ingredient eligibility
<a id="11-ingredient-eligibility"></a>

Items with **socketed runes** must **not** be accepted as forging ingredients.

Reject an ingredient if it has:

- Any **runes inserted** into sockets, and/or
- Any **stats modifiers or granted skills originating from rune sockets**.

Empty rune slots are allowed.

Additionally, reject an ingredient weapon if it is affected by a **temporary weapon-enchant status** (these are not permanent weapon boost entries, and must not be “baked in” via forging), for example:

- `FIRE_BRAND` (Fire Brand)
- `VENOM_COATING` (Venom Coating)
- `VENOM_AURA` (Venom Aura)
- `SIPHON_POISON` (Siphon Poison)
- `ARROWHEAD_*` (Elemental Arrowheads)

Additionally, ingredients must be **unequipped** (in inventory, not currently worn/held). This prevents temporary status-driven effects and tooltip overlays from polluting the values extracted for forging.

**Tooltip pollution guard (required):** even with the checks above, the implementation must not bake in temporary state.

- If an item is under any unknown temporary effect that changes its displayed values, the system must reject it for forging and for normalisation rather than measuring/restoring from polluted tooltip values.

Additionally, enforce **item-type compatibility**:

- **Weapons**: weapon can forge with weapon (cross weapon sub-types allowed, e.g. dagger ↔ axe).
- **Shields**: shield can only forge with shield.
- **Armour**: each armour slot only forges with the same slot (boots ↔ boots, helmet ↔ helmet, gloves ↔ gloves, chest ↔ chest, pants ↔ pants).
- **Jewellery**: ring ↔ ring, amulet ↔ amulet.
 
#### Output type selection

The forged output item is always the same **item type/slot** as the ingredient in the **Main Slot** (first forge slot).

| (Main Slot) Forge slot 1 | (Secondary Slot) Forge slot 2 | Output type | Notes                                                                       |
| :----------------------- | :---------------------------- | :---------- | :-------------------------------------------------------------------------- |
| Boots                    | Boots                         | Boots       | Armour pieces are slot-locked (boots ↔ boots only).                         |
| Dagger                   | One-handed axe                | Dagger      | Cross weapon sub-types are allowed, but the output still follows main slot. |

### 1.2. Forge flow overview
<a id="12-forge-flow-overview"></a>

This document splits forging into independent “channels”, because vanilla item generation works the same way.

Blue stats, ExtraProperties, and skills share a single **overall rollable slots cap** defined in:

- [`rarity_system.md` → Caps](rarity_system.md#22-caps-vnext-default--learned-per-save)

- **Base values** (Base Damage / Armour / Magic Armour / Block Chance): determined by **item type + the white tooltip values**.
- **Blue stats** (Attributes / Stats / Combat and Civil Abilities): rollable stats modifiers (e.g. +1 Finesse, +10% Critical Chance, +1 Warfare, +1 Thievery, etc.).
- **ExtraProperties**: rollable bundle (e.g. “10% chance to set Blinded for 1 turn”, “Poison Immunity”, “Create Ice surface”, etc., counts as **1 slot** if present, regardless of how many internal lines it expands into).
- **Skills**: rollable granted skills (each skill consumes **1 slot**, unless protected by shared/skillbook rules).
- **Rune slots**: a separate channel (only when empty; rune effects are forbidden as ingredients).

High-level forge order:

1. Decide the output's **rarity** using the **[Rarity System](rarity_system.md)**.
2. Enforce eligibility and the **level gate** (forge disabled unless both ingredients are at least the player’s level). If needed, normalise ingredients using the SE ratio-preserving process in **[Section 2.4](#24-baseline-budget-cache-and-parent-measurement)**.
3. Decide the output's **base values** (damage/armour, etc.) using **[Section 2](#2-base-values-inheritance)**.
4. Inherit **weapon boosts** (elemental damage, armour-piercing, vampiric, etc.) using **[Section 3](#3-weapon-boost-inheritance)** (weapons only).
5. Inherit **blue stats** using **[Section 4.4](#44-blue-stats-channel)**.
6. Inherit **ExtraProperties** using **[Section 4.5](#45-extraproperties-inheritance)**.
7. Inherit **skills** using **[Section 4.6](#46-skills-inheritance)**.
8. Inherit **rune slots** using **[Section 5](#5-rune-slots-inheritance)**.

### 1.3. Deterministic randomness (seed + multiplayer)
<a id="13-deterministic-randomness-seed--multiplayer"></a>

All random outcomes in this system (white numbers, blue stats, granted skills) must be driven by a single **forge seed** generated once per forge operation.

- **forgeSeed**: generated once per forge operation, then used to seed a deterministic PRNG.
- **Host-authoritative**: only the host/server rolls. Clients receive the final forged result.
- **Per-channel streams**: derive independent sub-streams from the same `forgeSeed` for base values, stats modifiers, and skills, so one channel’s rolls cannot affect another.

_Below is the technical breakdown for players who want the exact maths._

---

## 2. Base values Inheritance
<a id="2-base-values-inheritance"></a>

This section defines how forging merges **raw numeric power** (the **white tooltip** values). **Implementation reference:** see [Section 2.7](#27-implementation-checklist-se-base-values) for a concise checklist of invariants and edge-case guards required for SE implementation.

### 2.1. Base values (definition)
<a id="21-base-values-definition"></a>

This base-value model is intentionally generic: it works for any item that has meaningful **base values** (raw template numbers, not blue stats / ExtraProperties / granted skills / runes).

- **Weapons**: base damage range.
- **Shields**: base armour, base magic armour, and base blocking.
- **Armour pieces** (helmets/chest/gloves/boots/pants/belts): base armour and/or base magic armour.
- **Jewellery** (rings/amulets): base magic armour.
- **Slots that have no meaningful base values** (e.g. if both base armour and base magic armour are `0`): [Section 2](#2-base-values-inheritance) is a **no-op** for those numeric channels.

Core design goals:

- **Output is always your current level**: `Level_out = Level_player`.
- **Forge is visually straightforward**: in the UI, “high should give high, low should give low” when comparing white tooltip values.
- **Underlevelled items keep their forged quality**: if you level up an underlevelled forged item, it must retain its relative strength vs baseline (e.g. `1.35×` stays `1.35×` after levelling).

The key to making these goals coexist is:

- A **hard level gate** (forge disabled unless ingredients are at least the player’s level), and
- A Script Extender (SE) **ratio-preserving normalisation** process (so levelling is not “vanilla template levelling”).

Balance note:

- When the donor is above the player level, the donor's pull is dampened using `t_eff` so higher-level donors still feel better, but do not explode balance for low-level outputs.

Overview on how the forged item's base values are calculated:

- **Weapons (damage)**: uses a **tooltip-midpoint** model.
  - Let `A = avgDamage(slot1)` and `B = avgDamage(slot2)`, where `avgDamage = (min+max)/2`.
  - Only if both parents are weapons of the **exact same `WeaponType`** (same-type) can the donor influence damage.
  - Cross-type weapon forging does **not** change base damage (slot 1 identity is preserved).
- **Non-weapons (armour/shields/jewellery)**: uses a **tooltip-only** model (per channel):
  - Let `A = Base(slot1)` and `B = Base(slot2)` for that channel (e.g. physical armour, magic armour).
  - Uses **slot 1 dominance** (rarity-based `w`): the donor can pull the result **up or down**.
  - An upgrade can “spike” towards the donor using the same `u^2` shape (higher is harder).

### 2.2. Output rules (level/type/rarity)
<a id="22-output-rules-leveltyperarity"></a>

- **Output level**: always the forger's level, `Level_out = Level_player`.
- **Output type**: always the item in the **main forge slot** (first slot).
- **Output rarity**: decided by the **[Rarity System](rarity_system.md)**.
- **Base values (all items)**: upgrades do **not** overcap. They only push the output **towards the donor** for that channel (and cross-type weapon forging does not change weapon damage).

#### Weapon Damage Type inheritance

The forged weapon's `Damage Type` field is inherited from the **main slot (slot 1)** when same-type weapon forging occurs (`TypeMatch = true`):

- `DamageType_out = DamageType(slot1)`

**Notes:**

- This rule applies only to **same-type weapon forging** (`TypeMatch = true`), where both parents share the same `WeaponType` and base damage can be merged.
- For **cross-type weapon forging** (`TypeMatch = false`), base damage is unchanged and the output type follows slot 1, so the damage type naturally follows from the output item type.
- This rule is most relevant for weapons that can have different damage types within the same `WeaponType`:
  - **Staffs**: can be Physical (base), Fire, Water, Poison, Earth, or Air
  - **Wands**: default to Fire, but can have Fire, Air, Water, or Poison variants
  - **Unique weapons**: can override their base class damage type (e.g., a unique 2H axe with Fire damage)

**Examples:**

- Fire Staff (slot 1) + Water Staff (slot 2) → Forged: Fire Staff (damage type follows slot 1)
- 2H Axe (Physical damage, slot 1) + Fire Staff (slot 2) → Forged: 2H Axe (Physical damage, damage type follows slot 1)

#### Hard level gate (UI rule; required)

Forge is disabled unless both ingredients satisfy:

- `Level_main >= Level_player`
- `Level_donor >= Level_player`

This keeps the UI “fool-proof”:

- players are never asked to mentally convert “a great level 10” into “what it would be at level 15”,
- and underlevelled forged items do not lose their quality when brought up to the player’s level.

If an ingredient is underlevelled, the player must normalise it first (see [Section 2.4](#24-baseline-budget-cache-and-parent-measurement)).

**Rarity note (base values):** `w` (and therefore `t`) is derived from the **two parent rarities**. `Rarity_out` does **not** influence base value inheritance.

### 2.3. Inputs and tuning parameters
<a id="23-inputs-and-tuning-parameters"></a>

This section defines the **inputs**, **notation**, and the **balance knobs** used by the base values merge. The actual algorithms are in [Section 2.5](#25-merge-algorithm-percentiles-to-output-base-values).

#### Inputs (per forge)

- **Output selectors**:
  - `Type_out`: always the item type in the **main forge slot** (slot 1).
  - `Level_out`: always the forger’s level, `Level_out = Level_player`.
  - `Rarity_out`: decided by the **[Rarity System](rarity_system.md)**.
- **Level inputs (for base values and the level gate)**:
  - `Level_player`: level of the forger (drives `Level_out` and the UI level gate).
  - `Level_main`: level of the **main** parent item (slot 1).
  - `Level_donor`: level of the **donor** parent item (slot 2).
- **Numeric channels (what “base values” means)**:
  - **Weapons**: one channel (white damage average).
  - **Shields**: three channels (physical armour, magic armour, and blocking).
  - **Armour pieces**: two channels (physical armour and/or magic armour).
  - **Jewellery**: typically one channel (magic armour).
- **No-op rule**: if an item has no meaningful base value for a channel (e.g. the tooltip value is `0`), do **not** apply the merge to that channel.

#### UI normalisation controls (player-facing; required)

The level gate must be supported by UI tools that use SE normalisation (not vanilla template levelling), So other item leveling mods are not compatible with this forging system:

- **Normalise selected**: normalise the selected item (or the slotted ingredient) up to `Level_player`, preserving its base-power ratio.
- **Normalise all eligible**: scan inventory and normalise all items that:
  - have `Level_item < Level_player`, and
  - are eligible forging ingredients (slot compatibility, unequipped, no socketed runes, no temporary weapon-enchant status).

Both buttons must produce the same result for the same item (single-item normalisation is just a filtered case of the bulk action).

#### Balance knobs (tuning table)

These are the **balance knobs** (tuning defaults), used by the tooltip-only base-value models in [Section 2](#2-base-values-inheritance).
| Parameter | Meaning | Default | Notes |
| :--- | :--- | :---: | :--- |
| `w` | Slot 1 dominance weight | Derived | Computed from the parents’ rarities (rarity dominance rule below). Slot 1 always remains the main parent. Used by non-weapons and by weapons when `WeaponType` matches. |
| `w0` | Base slot 1 dominance | **0.70** | Used when both parents have the same rarity. |
| `β` | Rarity dominance strength | **0.04** | Each rarity step in favour of slot 1 increases `w` by `β` (and decreases donor weight by the same amount). |
| `w_min`, `w_max` | Clamp range for `w` | **0.50..0.90** | Prevents the donor from becoming completely irrelevant, and prevents slot 1 from ever being “overridden”. |
| `upgradeCap` | Maximum upgrade chance | **50%** | Applies only when the donor is better (`B > A`). |
| `k` | Upgrade difficulty exponent ("higher is harder") | **1** | Linear upgrade chance vs relative gain. |
| Upgrade quality roll | `u^2` | – | On upgrade success: pushes towards donor (`Out = Base + (B-Base)×u^2`). |
| Rounding policy | How to convert the final float into the displayed integer | Nearest (half-up) | Optional "player-favour" bias is to always round up. |
| `t_eff` | Level-gap dampener (effective donor pull) | Derived | `t = (1 - w)`. If `Level_donor > Level_player`: `t_eff = t × (Level_player / Level_donor)`, otherwise `t_eff = t`. Dampens donor pull when donor level exceeds player level. |

**Rarity note (base values):** `w` is derived from the **two parent rarities**. `Rarity_out` does **not** influence base value inheritance.

#### Rarity dominance (Non-Unique): dynamic merge weight `w`
<a id="23-rarity-dominance"></a>

To make higher rarity ingredients matter more, `w` is not a constant.

Each rarity name map to a **rarity index**:

- Common = 0, Uncommon = 1, Rare = 2, Epic = 3, Legendary = 4, Divine = 5, Unique = 6

Let:

- `r_main` be the rarity index of the **main** parent (slot 1)
- `r_donor` be the rarity index of the **donor** parent (slot 2)
- `Δr = r_main - r_donor`

Then:

- `w = clamp(w0 + β × Δr, w_min, w_max)`
- donor weight is `(1 - w)`

**Note:**
Weapon damage (same `WeaponType`) uses rarity dominance too. When `WeaponType` matches, weapons use the same donor pull strength: `t = (1 - w)` (computed from parent rarities).
When `WeaponType` does not match, weapon base damage does not change ([Section 2.5](#25-merge-algorithm-percentiles-to-output-base-values)).

#### Weight table (main rarity vs donor rarity)

This table shows what percentage the main item and donor contribute for different rarity combinations, using `w0=0.70`, `β=0.04`, `w_min=0.50`, `w_max=0.90`

Format: `w (donor weight = 1 - w)`

| Main \\ Donor | Common (0)  | Uncommon (1) |  Rare (2)   |  Epic (3)   | Legendary (4) | Divine (5)  |
| :------------ | :---------: | :----------: | :---------: | :---------: | :-----------: | :---------: |
| Common (0)    | 0.70 (0.30) | 0.66 (0.34)  | 0.62 (0.38) | 0.58 (0.42) |  0.54 (0.46)  | 0.50 (0.50) |
| Uncommon (1)  | 0.74 (0.26) | 0.70 (0.30)  | 0.66 (0.34) | 0.62 (0.38) |  0.58 (0.42)  | 0.54 (0.46) |
| Rare (2)      | 0.78 (0.22) | 0.74 (0.26)  | 0.70 (0.30) | 0.66 (0.34) |  0.62 (0.38)  | 0.58 (0.42) |
| Epic (3)      | 0.82 (0.18) | 0.78 (0.22)  | 0.74 (0.26) | 0.70 (0.30) |  0.66 (0.34)  | 0.62 (0.38) |
| Legendary (4) | 0.86 (0.14) | 0.82 (0.18)  | 0.78 (0.22) | 0.74 (0.26) |  0.70 (0.30)  | 0.66 (0.34) |
| Divine (5)    | 0.90 (0.10) | 0.86 (0.14)  | 0.82 (0.18) | 0.78 (0.22) |  0.74 (0.26)  | 0.70 (0.30) |

#### Upgrade quality roll `u`
<a id="23-upgrade-overcap-behaviour"></a>

On an upgrade success, we roll `u ~ U(0,1)` and use `u^2` to push the output towards the donor (higher is harder).

#### Core formulas (shared maths)
<a id="23-core-formulas"></a>

This section defines the shared pieces of maths used by the base-value models:

- **Base pull (`delta`)**: the donor can pull **up or down**:
  - `delta = (B - A)`
- **Rarity dominance (`w`)**: computes slot 1 dominance and donor influence:
  - donor pull strength is `t = (1 - w)`
- **Level-gap dampener (`t_eff`)** (donor above player only):
  - If `Level_donor > Level_player`: `t_eff = t × (Level_player / Level_donor)`
  - Otherwise: `t_eff = t`
- **Upgrade chance (donor better only):**
  - `gain = max(0, delta / max(A, 1))` (relative improvement available; 0 if donor is not better)
  - `P(upgrade) = clamp(upgradeCap × gain^k, 0, upgradeCap)`
- **Upgrade quality (if upgrade succeeds):**
  - roll `u ~ U(0,1)` and use `u^2` to push towards the donor (higher is harder)

---

### 2.4. Parent measurement (tooltip values)
<a id="24-baseline-budget-cache-and-parent-measurement"></a>

This section defines how to:

- measure parents’ base values from real items (white tooltip numbers), and
- normalise underlevelled ingredients to satisfy the level gate without losing forged quality (SE required).

#### Parent measurement

Important constraints (already enforced elsewhere, but repeated here because they matter for correctness):

- **Socketed runes are rejected** as ingredients ([Section 1.1](#11-ingredient-eligibility)), so rune pollution does not enter the system.
- Try to measure from a stable state (not mid-combat / not under temporary buffs), so the tooltip reflects the item’s own base values.
- If the implementation cannot guarantee a stable state for measurement (e.g. unknown temporary effects or tooltip overlays), it must abort measurement/normalisation for that item rather than baking in a temporary state.

Weapons (single channel; uses these directly):

- Read the weapon’s white damage range from the item tooltip: `D_min..D_max`
- Compute the midpoint: `avgDamage = (D_min + D_max) / 2`

Shields (three channels):

- Read `Armour`, `MagicArmour`, and `Blocking` from the item tooltip.
- Treat each channel independently throughout Sections 2.4–2.5.

Armour pieces (two channels):

- Read `Armour` and `MagicArmour` from the item tooltip.
- Treat each channel independently throughout Sections 2.4–2.5.

---

#### SE normalisation (required): ratio-preserving levelling to satisfy the level gate

If you level up ingredients using vanilla item levelling, the engine re-baselines the item’s white numbers to its template at the new level.
That overwrites forged quality (for example, an underlevel forged weapon that is `1.35×` baseline for its own level would fall back to `1.00×`).

Normalisation must preserve “base power” as a ratio relative to an expected baseline for the item identity.

Definitions (per item identity, per level, per channel):

- `E(identity, Level, channel)`: expected baseline white number at that level for that identity/channel (measured or table-driven).
- `Base`: measured white number from the tooltip for that channel.
- `r`: the item’s base-power ratio: `r = Base / max(E(...), 1)`

**Identity key requirement (for `E(identity, Level, channel)`):**

`identity` must be a stable key that uniquely identifies the item’s base-value curve across levels.

- Use a template/stat identity (e.g. the item’s root template / stats entry name), not rarity, not affixes, and not the current tooltip values.
- Do **not** use `WeaponType`/slot alone as `identity` (too broad; different templates in the same family can have different baselines).
- For Unique items, treat the Unique’s template/stat as its `identity` (Unique baselines can be special).

Normalisation algorithm (per channel; conceptually):

1. Measure `Base_in` from the tooltip at `Level_in`.
2. Compute `r = Base_in / max(E(identity, Level_in, channel), 1)`.
3. Level up to the player’s level (e.g. `ItemLevelUpTo(item, Level_player)`).
4. Compute `Base_target = r × E(identity, Level_player, channel)`.
5. Restore `Base_target` using predefined step-ladder delta modifiers.

If `Base_target` cannot be matched exactly, use the closest representable value (then apply the rounding policy).

**Channel guard (required):**

For any channel:

- If `Base_in == 0`, skip normalisation and skip merge for that channel (treat as no-op).
- If `E(identity, Level_in, channel) <= 0` or `E(identity, Level_player, channel) <= 0`, skip normalisation for that channel (do not fabricate ratios from a zero baseline).

#### Step-ladder delta modifiers (required): per item type, per channel

You cannot generate brand-new boosts “at runtime” to add an arbitrary `+X` base value.
To realise `Base_target` precisely (and not be limited to vanilla Small/Medium/Large tiers), ship **predefined step-ladder boosts** and apply a combination of them.

Recommended ladder (sustainable at high levels):

- Use a compact binary / mixed-radix basis, for example:
  - `±1, ±2, ±4, ±8, ±16, ±32, ±64, ±128, ±256, ±512, ±1024`
- Include both positive and negative steps so you can restore both above-baseline and below-baseline items.

Required ladders per item family/channel (examples of what must exist in data):

| Item family | Channels | Ladder families you must define | Notes |
| :--- | :--- | :--- | :--- |
| Weapons | Damage (midpoint model) | `WeaponDamageStep_±{1,2,4,8,...}` | Validate that these steps affect the displayed white damage range consistently for the weapon identity you normalise. |
| Armour pieces (incl belts/boots) | Armour, MagicArmour | `ArmourStep_±{...}`, `MagicArmourStep_±{...}` | Two independent channels. |
| Jewellery (rings/amulets) | MagicArmour (typical) | `JewelleryMagicArmourStep_±{...}` | If a jewellery identity exposes additional base channels, treat them the same way. |
| Shields | Armour, MagicArmour, Blocking | `ShieldArmourStep_±{...}`, `ShieldMagicArmourStep_±{...}`, `ShieldBlockingStep_±{...}` | Blocking is a real numeric channel and must be covered. |

Worked “ladder selection” example (generic):

- Suppose the restored target needs `Delta_target = +37` on a channel.
- With binary steps, one valid composition is: `+32 +4 +1`.

**Idempotency requirement (normalisation):**

Normalising an item to `Level_player` must be idempotent: running it multiple times without changing the item must not change the result.

Implementation guidance (SE):

- Remove/clear previously applied step-ladder boosts for the channel before applying the new combination, or
- Track a single stored `Base_target` (or `r`) and re-derive deltas from that source of truth.

**Weapon ladder validation requirement (SE):**

Before shipping, validate for each supported weapon identity family that:

- Applying `WeaponDamageStep_*` changes the **white tooltip damage range** consistently (both min and max move as expected),
- The change corresponds to the intended midpoint delta (within rounding),
- It does not double-count any `DamageBoost`-style effects that are already reflected in the tooltip (see `_Boost_Weapon_Damage_Bonus` exclusion in [Section 3.1](#31-weapon-boosts-definition)).

### 2.5. Merge algorithms (all items)
<a id="25-merge-algorithm-percentiles-to-output-base-values"></a>

This section contains two separate models:

- **Weapons (damage)**: tooltip-midpoint model (only if the parents have the exact same `WeaponType`; uses `w` for donor pull when eligible, otherwise damage is unchanged).
- **Non-weapons (armour/shields/jewellery)**: tooltip-only model (per channel; always uses `w` for slot 1 dominance / donor pull).

#### Weapon base damage merge (tooltip midpoints)

Let slot 1 be the “main” parent and slot 2 the “donor” parent.

Inputs:

- `A = avgDamage(slot1)` and `B = avgDamage(slot2)` where `avgDamage = (min+max)/2`
- `TypeMatch = (WeaponType_1 == WeaponType_2)`
- `Level_player` (forger level), `Level_donor` (slot 2 item level)

Rules:

- If `TypeMatch=false`: `avg_out = A` (cross-type weapons do not change damage).
- Otherwise (`TypeMatch=true`):
  - Compute `w` from parent rarities ([Section 2.3](#23-inputs-and-tuning-parameters)), so donor pull strength is `t = (1 - w)`
  - Apply the level-gap dampener using the donor item level:
    - If `Level_donor > Level_player`: `t_eff = t × (Level_player / Level_donor)`
    - Otherwise: `t_eff = t`
  - `delta = (B - A)`
  - `avg_base = A + t_eff × delta`
  - `gain = max(0, delta / max(A, 1))`
  - `P(upgrade) = clamp(upgradeCap × gain^k, 0, upgradeCap)`
  - On upgrade failure: `avg_out = avg_base`
  - On upgrade success: roll `u ~ U(0,1)` and compute `avg_out = avg_base + (B - avg_base) × u^2` (higher is harder)

Finally, round to the displayed integer midpoint and let the engine display min/max using the weapon's `Damage Range` rules.



#### Non-weapons (tooltip-only; per channel)

Let slot 1 be the “main” parent and slot 2 the “donor” parent.

Inputs (per channel):

- `A = Base(slot1)` (e.g. physical armour)
- `B = Base(slot2)` (same channel)
- `w` from rarity dominance ([Section 2.3](#23-inputs-and-tuning-parameters)), so donor pull strength is `t = (1 - w)`
- `Level_player` (forger level), `Level_donor` (slot 2 item level)

Rules:

- `delta = (B - A)`
- Apply the level-gap dampener using the donor item level:
  - If `Level_donor > Level_player`: `t_eff = t × (Level_player / Level_donor)`
  - Otherwise: `t_eff = t`
- `Base = A + t_eff × delta`
- `gain = max(0, delta / max(A, 1))`
- `P(upgrade) = clamp(upgradeCap × gain^k, 0, upgradeCap)`
- On upgrade failure: `Out = Base`
- On upgrade success: roll `u ~ U(0,1)` and compute `Out = Base + (B - Base) × u^2`

Apply the same steps independently to each channel (physical armour and magic armour).

### 2.6. Worked examples
<a id="26-worked-examples-base-values"></a>

Examples are organised by category: normalisation (1–2), weapons (3–6), and non-weapons (7–8).

#### Normalisation examples

##### Example 1: Level gate (why it exists)

Player level: `Level_player = 15`.

If a player tries to use a level 10 ingredient, forging is disabled until the item is normalised to at least level 15.

Reason: this makes the process **visually and conceptually straightforward** — the white tooltip numbers are compared on the same level baseline, so “high should give high, low should give low” without the player having to mentally adjust for level differences.

The normalisation is ratio-preserving: if the level 10 item is "very strong for level 10", it should still look "very strong" when brought up to level 15.

##### Example 2: Ratio-preserving normalisation (illustrative)

Assume an identity baseline function `E(...)` yields:

- `E(identity, 10, DamageMid) = 100`
- `E(identity, 15, DamageMid) = 160`

An underlevel forged ingredient at level 10 has tooltip midpoint `Base_in = 135`, so:

- `r = 135 / 100 = 1.35`

Normalise to level 15:

- Restore `Base_target = 1.35 × 160 = 216`

So after normalisation, the item remains `1.35×` baseline at the player's level.

#### Weapon examples (tooltip midpoints)

The weapon examples below use only the white tooltip numbers:
`avgDamage = (min+max)/2`.

Shared settings (weapon-only):
| Name | Value | Meaning |
| :--- | :---: | :--- |
| `w0` | 0.70 | Base slot 1 dominance (same rarity) |
| `β` | 0.04 | Rarity dominance strength |
| `w_min`, `w_max` | 0.50..0.90 | Clamp range for `w` |
| `upgradeCap` | 50% | Maximum upgrade chance |
| `k` | 1 | Upgrade difficulty exponent ("higher is harder") |
| Upgrade quality roll | `u^2` | Pushes towards donor unless you get lucky |

##### Example 3: Same `WeaponType` (Crossbow), donor is better

Both are **Crossbow** ⇒ same-type (`TypeMatch=true`).

Player level: `Level_player = 15`. Both items are at level 15 (satisfy the level gate).

| Item           | `WeaponType` | Tooltip damage | `avgDamage` |
| :------------- | :----------- | :------------: | ----------: |
| Slot 1 (main)  | Crossbow     |   `130–136`    | `A = 133.0` |
| Slot 2 (donor) | Crossbow     |   `150–157`    | `B = 153.5` |

Compute:
| Key value | Result |
| :--- | ---: |
| `delta = (B-A)` | `20.5` |
| `w = clamp(0.70 + 0.04×(0-5), 0.50, 0.90)` | `0.50` |
| `t = (1-w)` | `0.50` |
| Level-gap dampener: `Level_donor = 15`, `Level_player = 15` ⇒ `t_eff = t` | `0.50` |
| `avg_base = A + t_eff×delta` | `133.0 + 0.50×20.5 = 143.25` |
| `gain = max(0, delta/max(A,1))` | `20.5/133.0 = 0.1541` |
| `P(upgrade) = upgradeCap × gain^k` | `50% × 0.1541 = 7.71%` |

| Outcome                    |                                           `avg_out` | Notes                        |
| :------------------------- | --------------------------------------------------: | :--------------------------- |
| No upgrade                 |                                  `avg_out = 143.25` | deterministic baseline       |
| Upgrade example (`u=0.70`) | `avg_out = 143.25 + (153.5-143.25)×0.70^2 = 148.27` | exciting spike towards donor |

##### Example 4: Cross-type weapons do **not** change base damage (Spear + 2H Sword)

Different `WeaponType` ⇒ cross-type (`TypeMatch=false`).

Player level: `Level_player = 15`. Both items are at level 15 (satisfy the level gate).

| Item           | `WeaponType` | Tooltip damage | `avgDamage` |
| :------------- | :----------- | :------------: | ----------: |
| Slot 1 (main)  | Spear        |   `150–157`    | `A = 153.5` |
| Slot 2 (donor) | 2H Sword     |   `170–188`    | `B = 179.0` |

Rule:

- `avg_out = A = 153.5` (no upgrade roll; cross-type weapons do not merge damage)

##### Example 5: Level-gap dampener (Epic Level 15 → Divine Level 16, same `WeaponType` 2H sword)

Player level: `Level_player = 15` ⇒ output is level 15.

Inputs (midpoints):

- Slot 1 (main): `66–73` ⇒ `A = 69.5`
- Slot 2 (donor): `77–84` ⇒ `B = 80.5`

Rarity dominance:

- `r_main = Epic = 3`, `r_donor = Divine = 5` ⇒ `Δr = -2`
- `w = clamp(0.70 + 0.04×(-2), 0.50, 0.90) = 0.62`
- `t = (1-w) = 0.38`

Level-gap dampener (donor above player):

- `Level_donor = 16 > 15` ⇒ `t_eff = t × (15/16) = 0.38 × 0.9375 = 0.35625`

Compute:

- `delta = (B-A) = 11.0`
- `avg_base = A + t_eff×delta = 69.5 + 0.35625×11 = 73.41875`
- `gain = delta/max(A,1) = 11/69.5 = 0.1583`
- `P(upgrade) = clamp(50% × 0.1583, 0, 50%) = 7.92%`

Interpretation:

- No-upgrade baseline midpoint is ~`73.4` (then the engine shows min/max using the weapon's `Damage Range` rules).
- If upgrade succeeds (~`7.9%`), the midpoint is in the range `avg_out ∈ [avg_base, B]`.

##### Example 6: Level-gap dampener (Divine Level 25 → Divine Level 30, same `WeaponType` 2H sword)

Player level: `Level_player = 25` ⇒ output is level 25.

Inputs (midpoints):

- Slot 1 (main): `363–401` ⇒ `A = 382.0`
- Slot 2 (donor): `907–1003` ⇒ `B = 955.0`

Rarity dominance (Divine vs Divine):

- `w = 0.70`, so `t = 0.30`

Level-gap dampener (donor above player):

- `Level_donor = 30 > 25` ⇒ `t_eff = 0.30 × (25/30) = 0.25`

Compute:

- `delta = (B-A) = 573.0`
- `avg_base = 382.0 + 0.25×573.0 = 525.25`
- `gain = 573/382 = 1.50`
- `P(upgrade) = clamp(50% × 1.50, 0, 50%) = 50%` (capped)

Interpretation:

- No-upgrade baseline midpoint is `525.25`.
- If upgrade succeeds (50%), the midpoint is in the range `avg_out ∈ [525.25, 955.0]` and min/max are displayed using the weapon's `Damage Range` rules.

#### Non-weapon examples (tooltip-only)

The non-weapon examples below use only the white tooltip values (per channel).

Shared settings (non-weapons):
| Name | Value | Meaning |
| :--- | :---: | :--- |
| `w0` | 0.70 | Base slot 1 dominance (same rarity) |
| `β` | 0.04 | Rarity dominance strength |
| `w_min`, `w_max` | 0.50..0.90 | Clamp range for `w` |
| `upgradeCap` | 50% | Maximum upgrade chance |
| `k` | 1 | Upgrade difficulty exponent ("higher is harder") |
| Upgrade quality roll | `u^2` | Pushes towards donor unless you get lucky |

##### Example 7: Armour (two channels), same maths per channel (Strength chest + Intelligence chest)

Player level: `Level_player = 20`. Both items are at level 20 (satisfy the level gate).

Slot 1 (Strength chest): `713 Physical Armour`, `140 Magic Armour`  
Slot 2 (Intelligence chest): `140 Physical Armour`, `713 Magic Armour`

Assume the realised output rarity is **Divine** (slot 1 identity is preserved).

Both parents are Divine, so rarity dominance is:

- `w = clamp(0.70 + 0.04×(5-5), 0.50, 0.90) = 0.70`
- donor pull strength is `t = (1-w) = 0.30`
- Level-gap dampener: `Level_donor = 20`, `Level_player = 20` ⇒ `t_eff = t = 0.30`

| Channel  | Slot 1 `A` | Slot 2 `B` | `delta = (B-A)` |        `Base = A + t_eff×delta` | `gain = max(0, delta/max(A,1))` | `P(upgrade)` | No-upgrade output |
| :------- | ---------: | ---------: | --------------: | --------------------------: | ------------------------------: | :----------: | ----------------: |
| Physical |      `713` |      `140` |          `-573` | `713 + 0.30×(-573) = 541.1` |                             `0` |     `0%`     |             `541` |
| Magic    |      `140` |      `713` |           `573` |    `140 + 0.30×573 = 311.9` |               `573/140 = 4.093` | `50%` (cap)  |             `312` |

Interpretation:

- The output remains a Strength chest (slot 1 identity is preserved).
- Per-channel upgrades are possible, and a magic-channel "spike" can pull significantly towards the donor when the donor is much better.

##### Example 8: Shield (three channels), same maths per channel (Tower Shield + Kite Shield)

Player level: `Level_player = 20`. Both items are at level 20 (satisfy the level gate).

Slot 1 (Tower Shield): `713 Physical Armour`, `140 Magic Armour`, `15 Blocking`  
Slot 2 (Kite Shield): `140 Physical Armour`, `713 Magic Armour`, `10 Blocking`

Assume the realised output rarity is **Divine** (slot 1 identity is preserved).

Both parents are Divine, so rarity dominance is:

- `w = clamp(0.70 + 0.04×(5-5), 0.50, 0.90) = 0.70`
- donor pull strength is `t = (1-w) = 0.30`
- Level-gap dampener: `Level_donor = 20`, `Level_player = 20` ⇒ `t_eff = t = 0.30`

| Channel  | Slot 1 `A` | Slot 2 `B` | `delta = (B-A)` |        `Base = A + t_eff×delta` | `gain = max(0, delta/max(A,1))` | `P(upgrade)` | No-upgrade output |
| :------- | ---------: | ---------: | --------------: | --------------------------: | ------------------------------: | :----------: | ----------------: |
| Physical |      `713` |      `140` |          `-573` | `713 + 0.30×(-573) = 541.1` |                             `0` |     `0%`     |             `541` |
| Magic    |      `140` |      `713` |           `573` |    `140 + 0.30×573 = 311.9` |               `573/140 = 4.093` | `50%` (cap)  |             `312` |
| Blocking |       `15` |       `10` |            `-5` |  `15 + 0.30×(-5) = 13.5`    |                             `0` |     `0%`     |              `14` |

Interpretation:

- The output remains a Tower Shield (slot 1 identity is preserved).
- Per-channel upgrades are possible; the blocking channel shows a small downward pull when the donor is worse.
- The magic armour channel can still "spike" towards the donor when the donor is much better.

<details>
<summary><strong>Fully explicit view</strong></summary>

##### Physical Armour Channel

| Name         |            Value            | How it was obtained            |
| :----------- | :-------------------------: | :----------------------------- |
| `A_phys`     |            `713`            | slot 1 physical armour         |
| `B_phys`     |            `140`            | slot 2 physical armour         |
| `w`          |           `0.70`            | same rarity (Divine vs Divine) |
| `t = 1-w`    |           `0.30`            | donor pull strength            |
| `delta`      |     `(140-713) = -573`      | donor is worse                 |
| `Base`       | `713 + 0.30×(-573) = 541.1` | deterministic baseline         |
| `P(upgrade)` |            `0%`             | donor is not better            |

##### Magic Armour Channel

| Name                            |                   Value                    | How it was obtained            |
| :------------------------------ | :----------------------------------------: | :----------------------------- |
| `A_magic`                       |                   `140`                    | slot 1 magic armour            |
| `B_magic`                       |                   `713`                    | slot 2 magic armour            |
| `w`                             |                   `0.70`                   | same rarity (Divine vs Divine) |
| `t = 1-w`                       |                   `0.30`                   | donor pull strength            |
| `delta`                         |             `(713-140) = 573`              | donor improvement              |
| `Base`                          |          `140 + 0.30×573 = 311.9`          | deterministic baseline         |
| `gain`                          |             `573/140 = 4.093`              | relative improvement           |
| `P(upgrade)`                    |     `clamp(50% × 4.093, 0, 50%) = 50%`     | capped                         |
| `Out (no upgrade)`              |            `round(311.9) = 312`            | rounding policy                |
| `Out (upgrade example, u=0.70)` | `311.9 + (713-311.9)×0.70^2 = 508.4 → 508` | exciting spike                 |

</details>

### 2.7. Implementation checklist (SE; base values)
<a id="27-implementation-checklist-se-base-values"></a>

This is a short punch-list for implementing [Section 2](#2-base-values-inheritance) without introducing level/tooltip drift bugs:

- **Eligibility & measurement stability (must hold before any measurement/normalisation):**
  - item is **unequipped** (inventory; not worn/held),
  - no socketed runes (and no rune-origin lines),
  - no temporary weapon-enchant statuses (e.g. `FIRE_BRAND`, `VENOM_COATING`, `ARROWHEAD_*`),
  - if you cannot guarantee a stable tooltip state, **abort** (do not bake in polluted values).
- **Level gate (UI):**
  - forge disabled unless `Level_main >= Level_player` and `Level_donor >= Level_player`.
  - if underlevelled: normalise first using SE ratio-preserving normalisation (not vanilla template levelling alone).
- **Pre-forge Preview:** 
  - before actually forging, you want to show a "pre-forge preview" at `Level_player`, do not use vanilla template levelling alone. Use the SE normalisation process in [Section 2.4](#24-baseline-budget-cache-and-parent-measurement).
- **Baseline identity (`E(identity, Level, channel)`):**
  - `identity` must be a stable template/stat identity (not `WeaponType`/slot alone).
  - Unique items use their own template/stat as identity.
- **Channel guard (normalisation + merge):**
  - if `Base_in == 0`: treat as no-op for that channel.
  - if `E(identity, Level, channel) <= 0`: do not fabricate ratios; skip normalisation for that channel.
- **Normalisation algorithm (per channel):**
  - compute `r = Base_in / max(E(identity, Level_in, channel), 1)`,
  - `ItemLevelUpTo(item, Level_player)`,
  - restore `Base_target = r × E(identity, Level_player, channel)` using step-ladder boosts.
- **Idempotency (required):**
  - normalising the same item twice must produce the same result (clear previous ladder boosts or track a single source-of-truth `r`/`Base_target`).
- **Step-ladders (required):**
  - define per-family/channel ladders (weapons midpoint; armour/magic armour; shield blocking; jewellery magic armour),
  - include both positive and negative steps (e.g. `±1, ±2, ±4, …`) for above/below-baseline restoration.
- **Merge correctness:**
  - weapons: merge only when `WeaponType` matches; otherwise keep slot 1 base damage,
  - non-weapons: merge per channel,
  - always apply donor dampener: `t_eff = t × (Level_player/Level_donor)` when donor above player; otherwise `t_eff = t`.
- **Randomness (deterministic):**
  - base-value upgrade success and `u^2` must be driven by `forgeSeed` (host-authoritative; see [Section 1.3](#13-deterministic-randomness-seed--multiplayer)).
- **Weapon ladder validation (required before release):**
  - confirm `WeaponDamageStep_*` moves **both** min and max consistently and matches intended midpoint delta,
  - confirm it does not double-count `DamageBoost`-style effects already reflected in the tooltip (see `_Boost_Weapon_Damage_Bonus` exclusion in [Section 3.1](#31-weapon-boosts-definition)).
- **Known trade-off (design):**
  - very large level gaps can still produce strong donors even with `t_eff`; the design assumes typical gaps of `+1..+3`.

---

## 3. Weapon Boost Inheritance
<a id="3-weapon-boost-inheritance"></a>

This section defines how **weapon boosts** (elemental damage, armour-piercing, etc.) are inherited when forging **non-unique weapons**. **Implementation reference:** see [Section 3.4](#34-implementation-checklist-se-weapon-boosts) for a concise checklist of invariants and edge-case guards required for SE implementation.

**Note:** Unique weapons with special boost types (Vampiric, MagicArmourRefill, Chill) are treated as special cases and documented separately (see [Section 3.1.1](#311-special-boost-types-unique-weapons)).

**Important:** Temporary weapon-enchant effects from skills/consumables (e.g. Venom Coating, Elemental Arrowheads, Fire Brand, etc.) are implemented as **statuses** that grant a conditional `BonusWeapon` while active, not as permanent weapon `Boosts`. These temporary effects must not be present on forging ingredients (see [Section 1.1](#11-ingredient-eligibility)).

### 3.1. Weapon boosts (definition)
<a id="31-weapon-boosts-definition"></a>

In Divinity: Original Sin 2, weapons can have **additional damage or effects** beyond their base damage. These appear as **weapon boost properties** referenced by the weapon's `Boosts` field.

**How it works in the game:**

- Weapon boosts are **discrete boost entries** that either:
  - Add a **second damage line** (e.g., "32–39 Poison" alongside "311–381 Fire"), or
  - Provide **special effects** (e.g., vampiric healing, magic armour refill).
- Weapon boosts are **not base values** (they don't appear in the white damage range calculation).
- Weapon boosts are **not blue stat modifiers** (they're not part of the rollable modifier system).

**Crafting note (vanilla):**

- Some boosts are applied via **crafting combos** (`BoostType="ItemCombo"`) rather than being rolled during loot generation.
- Example: a poison vial can apply `Boost_Weapon_Crafting_Damage_Poison` → `_Boost_Weapon_Crafting_Damage_Poison` (10% `DamageFromBase`, Poison damage type, plus a small `POISONED` on-hit token).
- If the boost damage type **differs** from the weapon’s base `Damage Type`, it shows as a **second damage line**.
- If the boost damage type **matches** the weapon’s base `Damage Type` (e.g., Poison staff + Poison boost), the result can appear “merged” into the base damage line in the tooltip (it is still implemented as a boost entry).

**Important exclusion:**

- `_Boost_Weapon_Damage_Bonus` (and its tiered variants) uses the `DamageBoost` field, which **modifies base physical damage** directly.
- This boost is **already reflected in the white tooltip damage range** used by [Section 2](#2-base-values-inheritance) for base value inheritance.
- Therefore, `_Boost_Weapon_Damage_Bonus` is **not inherited via this section** ([Section 3](#3-weapon-boost-inheritance)) to avoid double-counting. It is implicitly handled through the base damage merge in [Section 2](#2-base-values-inheritance).

**Tier naming convention:**

- Boost names ending in `_Small` → **Small tier** (if available for that boost kind)
- Boost names ending in `_Medium` → **Medium tier**
- Boost names ending in `_Large` → **Large tier**
- Boost names with **no tier suffix** → **Untiered tier** (a distinct tier, not equivalent to Medium)

**Tier mapping for merging:**

Non-unique weapons:
- **4-tier boosts** (elemental, ArmourPiercing): Small (tier 0) < Untiered (tier 1) < Medium (tier 2) < Large (tier 3)

Unique weapons:
- **3-tier boosts** (Vampiric, MagicArmourRefill): Untiered (tier 0) < Medium (tier 1) < Large (tier 2)
- **1-tier boosts** (Chill): Untiered (tier 0) only

**Boost types in vanilla (non-unique weapons):**

The game defines several boost families for **non-unique weapons**, each with **different tier availability**:

1. **Elemental damage boosts** (4 tiers: Small, Untiered, Medium, Large):
   - Fire, Water, Poison, Air, Earth
   - Available tiers: `_Small` (~5%), untiered (~10%), `_Medium` (~11–15%), `_Large` (~20%)

2. **Armour-piercing damage boost** (4 tiers: Small, Untiered, Medium, Large):
   - Available tiers: `_Small` (5%), untiered (10%), `_Medium` (15%), `_Large` (20%)

<details id="311-special-boost-types-unique-weapons">
<summary><strong>Special boost types (unique weapons)</strong></summary>

### 3.1.1. Special boost types (unique weapons)

The following boost types are **rarely encountered** in normal gameplay, as they primarily appear on **unique/special weapons** rather than random loot:

3. **Vampiric boost** (3 tiers: Untiered, Medium, Large; **no Small tier**):
   - Available tiers: untiered, `_Medium`, `_Large`
   - No `_Small` variant exists in vanilla
   - Typically found on unique weapons

4. **Magic armour refill boost** (3 tiers: Untiered, Medium, Large; **no Small tier**):
   - Available tiers: untiered, `_Medium`, `_Large`
   - No `_Small` variant exists in vanilla
   - Typically found on unique weapons

5. **Chill damage boost** (1 tier only: Untiered):
   - Available tier: untiered only (10% of base damage with guaranteed CHILLED status)
   - No `_Small`, `_Medium`, or `_Large` variants exist in vanilla
   - Typically found on unique weapons

**Note:** These special boost types follow the same inheritance rules as common boost types (see [Section 3.2](#32-weapon-boost-inheritance-rules)), but use different tier systems (3-tier or 1-tier instead of 4-tier).

**Special cases for unique weapon boosts (tier availability):**

These boost kinds have **limited tier availability** in vanilla, but they still follow the same **score-and-select** inheritance rules in [Section 3.2](#32-weapon-boost-inheritance-rules).

When converting a numeric score back into a concrete tier name, clamp to tiers that actually exist for that boost kind:

- **3-tier boosts** (Vampiric, MagicArmourRefill):
  - Valid tiers: Untiered, `_Medium`, `_Large` (**no `_Small`**)
  - If rounding would produce `_Small`, clamp it to **Untiered**
- **1-tier boosts** (Chill):
  - Valid tier: Untiered only
  - Any non-zero rounded tier clamps to **Untiered**
</details>

---

### 3.2. Inheritance rules
<a id="32-weapon-boost-inheritance-rules"></a>

Weapon boost inheritance uses a **score-and-select** model with a small number of **boost slots** (vanilla-aligned).

The system:

- Computes a numeric score for every boost kind seen on either parent (after bias rolls),
- Selects up to `cap` boost kinds (weapon-type cap),
- Converts the selected kind scores into concrete boost tiers (`None`, `_Small`, untiered, `_Medium`, `_Large`), respecting tier availability for special boost kinds.

**Note:** `_Boost_Weapon_Damage_Bonus` is excluded from this system (see [Section 3.1](#31-weapon-boosts-definition) for details).

**Design rationale (based on vanilla game code):**

- In vanilla, weapon boosts are **discrete boost entries** (not continuous stats). Some special/unique weapons may carry multiple boost entries, but most gameplay behaves like a small-slot system (0–2).
- Tiers are **discrete** (Small/Medium/Large are separate boost entries with different `DamageFromBase` percentages or `Value` fields).
- The tier selection in vanilla is driven by **which boost entry gets assigned** (via rarity buckets or crafting combos), not computed from level.
- This design treats boost inheritance as a **discrete property selection** (like Skills or ExtraProperties) rather than numeric merging.

#### Boost slot caps (vanilla-aligned)

Vanilla behaviour implies that different weapon types support different numbers of weapon-boost entries in normal gameplay:

- **Wands**: `MaxBoostSlots = 0` (no weapon boosts)
- **Staffs**: `MaxBoostSlots = 1`
- **All other weapons**: `MaxBoostSlots = 2`

This system follows that model. The forged output is clamped to `MaxBoostSlots[WeaponType_out]`.

#### Step 0: Eligibility + inputs

Weapon boosts are inherited **only** when forging two weapons of the exact same `WeaponType`.

Let `TypeMatch = (WeaponType_1 == WeaponType_2)`. If `TypeMatch=false`, this channel is skipped and the forged weapon has **no weapon boosts**.

Determine `cap = MaxBoostSlots[WeaponType_out]`:

- If `cap = 0` (wands): forged weapon has **no weapon boosts** (deterministic).
- Otherwise (`cap ≥ 1`):
  - Parse each parent’s `Boosts` field into a list (split on `;`, ignore empty entries).
  - Ignore `_Boost_Weapon_Damage_Bonus` (and tiered variants) as described in [Section 3.1](#31-weapon-boosts-definition).
  - Clamp each parent’s list to `cap` entries (deterministic; keep the first `cap` boost entries).

If `cap ≥ 1` and `TypeMatch=true`, the system always attempts boost inheritance using the scoring rules below. (If both parent lists are empty after filtering, the result is no boosts.)

This mirrors vanilla weapon behaviour: weapon boosts behave like a small number of discrete slots, not an unbounded stack.

#### Step 1: Tier-to-score mapping (universal scale)

This section uses a universal numeric scale for scoring:

- `None` = 0
- `_Small` = 1
- **Untiered** (no suffix) = 2
- `_Medium` = 3
- `_Large` = 4

For special boost kinds with missing tiers (see [Section 3.1.1](#311-special-boost-types-unique-weapons)), conversion back to a concrete tier clamps to tiers that exist.

#### Step 2: Score every boost kind (after bias)

For each boost kind `k` present on either parent (Fire/Water/Poison/Air/Earth/ArmourPiercing, and special kinds where relevant):

1. Extract each parent’s tier score for that kind:
   - `s_main(k)` = tier score on the **main slot** parent (0 if absent)
   - `s_sec(k)` = tier score on the **secondary slot** parent (0 if absent)
2. Compute the weighted base score:

`baseScore(k) = 0.6 * s_main(k) + 0.4 * s_sec(k)`

3. Roll bias for every kind:

- Roll `bias(k) ~ U(0, 0.7)`.

4. Final score (after bias):

`score(k) = clamp(baseScore(k) + bias(k), 0, 4)`

#### Step 3: Select boost kinds under the weapon cap (score-and-select)

Select boost kinds using the following process:

1. Build `C1 = { k | score(k) >= 1 }` (candidates that can naturally reach at least `_Small`).
2. Sort `C1` by:
   - Higher `score(k)` first
   - If tied: higher `s_main(k)` first (main-slot dominance)
   - If still tied and both are secondary-only: earlier index in the secondary parent boost list wins (`[0]` first)
3. Pick the first `cap` kinds from `C1`.

#### Step 4: Fallback fill (only when cap is not filled)

If `|picked| < cap` and **all remaining unpicked kinds** have `score(k) < 1`, then fill the remaining slots using a secondary conversion:

For each remaining kind with `0 < score(k) < 1`:

`fillScore(k) = 1 + score(k) / 2`

Then:

- Sort remaining by `fillScore(k)` (same tie-breaks as above)
- Add until `cap` is filled (or no `0 < score(k) < 1` remain)

This ensures that weak leftover boosts (e.g. a secondary-only `_Small` giving `score=0.4`) can still occupy an otherwise empty boost slot as `_Small`, while never producing untiered or higher via the fallback path (`fillScore < 1.5` when `score < 1`).

#### Step 5: Convert selected kind scores back into concrete tiers

Convert each selected kind’s numeric value into a tier score using **round half up**:

- If the kind was selected in **Step 3**: use `score(k)`
- If the kind was selected in **Step 4 (fallback fill)**: use `fillScore(k)`

`tierScore_out = clamp(floor(score + 0.5), 0, 4)`

Then map:

- 0 → None (do not include this kind)
- 1 → `_Small`
- 2 → Untiered
- 3 → `_Medium`
- 4 → `_Large`

For pseudocode implementation reference, see [forging_system_implementation_blueprint_se.md → Weapon boost inheritance pseudocode](forging_system_implementation_blueprint_se.md#weapon-boost-inheritance-pseudocode).

*Note:* If the computed tier name does not exist for that boost kind in vanilla, clamp it to the nearest valid tier for that kind (see [Section 3.1.1](#311-special-boost-types-unique-weapons)).

### 3.3. Worked examples
<a id="33-weapon-boost-worked-examples"></a>

##### Example 1: Shared-kind scoring (cap = 2): Fire + Water

Assume the following bias rolls for illustration:

- `bias(Fire) = +0.30`
- `bias(Water) = +0.10`

Inputs:

- Weapon type: Sword (cap = 2)
- Slot 1 `Boosts` (main): Fire `_Large` + Water `_Medium`
- Slot 2 `Boosts` (secondary): Fire `_Small` + Water (untiered)

```
Parent A (main):  Fire _Large, Water _Medium
Parent B (sec):   Fire _Small, Water (untiered)
---------------------------------------------
Tier scores:
  Fire:  s_main=4, s_sec=1
  Water: s_main=3, s_sec=2

Scores (after bias):
  Fire:  score = 0.6*4 + 0.4*1 + 0.30 = 3.10
  Water: score = 0.6*3 + 0.4*2 + 0.10 = 2.70

Pick top cap=2 kinds with score>=1:
  Fire (3.10), Water (2.70)

Convert (round half up):
  Fire 3.10 -> 3 -> _Medium
  Water 2.70 -> 3 -> _Medium
```

##### Example 2: Mixed kinds (cap = 2): main-slot dominance with score-and-select

Assume the following bias rolls for illustration:

- `bias(Fire) = +0.20`
- `bias(Air) = +0.60`
- `bias(Water) = +0.70`

Inputs:

- Weapon type: Sword (cap = 2)
- Slot 1 `Boosts` (main): Fire `_Large` + Air `_Medium`
- Slot 2 `Boosts` (secondary): Fire `_Small` + Water (untiered)

```
Parent A (main):  Fire _Large, Air _Medium
Parent B (sec):   Fire _Small, Water (untiered)
---------------------------------------------
Tier scores:
  Fire:  s_main=4, s_sec=1
  Air:   s_main=3, s_sec=0
  Water: s_main=0, s_sec=2

Scores (after bias):
  Fire:  score = 0.6*4 + 0.4*1 + 0.20 = 3.00
  Air:   score = 0.6*3 + 0.4*0 + 0.60 = 2.40
  Water: score = 0.6*0 + 0.4*2 + 0.70 = 1.50

Pick top cap=2 kinds with score>=1:
  Fire (3.00), Air (2.40)

Convert (round half up):
  Fire 3.00 -> 3 -> _Medium
  Air  2.40 -> 2 -> (untiered)
```

##### Example 3: Secondary-only leftovers filled as `_Small` (fallback fill)

Assume the following bias rolls for illustration:

- `bias(Fire) = +0.10`
- `bias(ArmourPiercing) = +0.05`
- `bias(Air) = +0.10`

Inputs:

- Weapon type: Sword (cap = 2)
- Slot 1 `Boosts` (main): Fire `_Large`
- Slot 2 `Boosts` (secondary): ArmourPiercing `_Small`; Air `_Small`

```
Parent A (main):  Fire _Large
Parent B (sec):   ArmourPiercing _Small, Air _Small
---------------------------------------------
Tier scores:
  Fire:           s_main=4, s_sec=0
  ArmourPiercing: s_main=0, s_sec=1  (secondary index [0])
  Air:            s_main=0, s_sec=1  (secondary index [1])

Scores (after bias):
  Fire:           score = 0.6*4 + 0.4*0 + 0.10 = 2.50
  ArmourPiercing: score = 0.6*0 + 0.4*1 + 0.05 = 0.45
  Air:            score = 0.6*0 + 0.4*1 + 0.10 = 0.50

Primary pick (score>=1), cap=2:
  Fire (2.50)  -> 1 slot filled, 1 slot free

Fallback fill (all remaining scores < 1):
  fillScore = 1 + score/2
  Air:            1 + 0.50/2 = 1.25
  ArmourPiercing: 1 + 0.45/2 = 1.225

Pick best fillScore (ties resolved by secondary list order):
  Air (1.25) -> rounds to _Small

Result:
  Fire (from normal score) + Air _Small (fallback fill)
```

##### Example 4: Staff cap (cap = 1)

Assume the following bias rolls for illustration:

- `bias(Air) = +0.20`
- `bias(Poison) = +0.60`

Inputs:

- Weapon type: Staff (cap = 1)
- Slot 1 `Boosts` (main): Air `_Large` (staffs can only have 1 boost)
- Slot 2 `Boosts` (secondary): Poison `_Small` (staffs can only have 1 boost)

```
Weapon type: Staff (cap=1)
Parent A (main):  Air _Large
Parent B (sec):   Poison _Small
---------------------------------------------
Tier scores:
  Air:    s_main=4, s_sec=0
  Poison: s_main=0, s_sec=1

Scores (after bias):
  Air:    score = 0.6*4 + 0.4*0 + 0.20 = 2.60
  Poison: score = 0.6*0 + 0.4*1 + 0.60 = 1.00

Pick top cap=1 kind with score>=1:
  Air (2.60)
```

### 3.4. Implementation checklist (SE; weapon boosts)
<a id="34-implementation-checklist-se-weapon-boosts"></a>

- **Eligibility gate (required):**
  - only run when `TypeMatch=true` (exact same `WeaponType`),
  - enforce `cap = MaxBoostSlots[WeaponType_out]` (`0` wand, `1` staff, `2` others),
  - if `cap=0`, output has **no weapon boosts** (deterministic).

- **Parsing + normalisation (required):**
  - parse `Boosts` by `;`, ignore empty tokens,
  - filter out `_Boost_Weapon_Damage_Bonus` (and tiered variants) to avoid double-counting with base damage,
  - clamp each parent's boost list to `cap` entries (deterministic).

- **Kind + tier handling (bug-risk guard):**
  - treat boost kinds as **identity keys** (Fire/Water/Poison/Air/Earth/ArmourPiercing, etc.),
  - if a parent has multiple entries of the same kind within its clamped list, resolve deterministically (recommended: use the **highest tier score** for `s_main/s_sec`, and keep the earliest index for tie-break rules).

- **Tier conversion (required):**
  - map tiers to scores (`None=0`, `_Small=1`, `Untiered=2`, `_Medium=3`, `_Large=4`),
  - on convert-back, **round half up**, then **clamp to valid tiers for that kind** (special kinds may lack `_Small`, etc.).

- **Tooltip/visual edge case (required):**
  - do not infer boosts from tooltip damage lines; always use the `Boosts` entries (some boosts can look "merged" when damage types match).

---

## 4. Stats Modifier Inheritance
<a id="4-stats-modifiers-inheritance"></a>

This section defines how **stats modifiers** are inherited when you forge.

Stats modifiers are split into three dedicated channels, each with its own unshared pool:

- **Blue Stats (BS)**: numeric "blue text" boosts like Strength, crit, resistances, etc.
- **ExtraProperties (EP)**: semicolon-separated tokens like proc chances, statuses, immunities, surfaces, etc. (counts as **1 slot** overall if present)
- **Skills (Sk)**: rollable granted skills like Shout_Whirlwind, Projectile_BouncingShield, Target_Restoration (each counts as **1 slot** overall)

The forged item applies one shared cap across these channels:

- `OverallCap[Rarity_out, ItemType_out]` (default+learned per save, tracked per (rarity, item type) pair; see [`rarity_system.md`](rarity_system.md#221-overall-rollable-slots-cap))

#### Level normalisation note (Stats Modifiers)

The level-normalisation step described in [Section 2](#2-base-values-inheritance) (used to satisfy the level gate and preserve base-value ratios) is a **base-values-only** operation.

- **Blue Stats / ExtraProperties / Skills are not scaled by level normalisation.**
- Normalising an item to `Level_player` is intended to make **white tooltip values** comparable and forge-eligible.
- The forging merge for Stats Modifiers (this Section 4) uses the modifiers exactly as they exist on the item after normalisation.

**Implementation note (SE):**
- If you call `ItemLevelUpTo` during normalisation, ensure you **do not re-roll** or replace stats modifiers as part of that process.
- Other item-levelling mods that re-roll stats modifiers are not compatible with this forging system's guarantees.

### 4.1. Introduction + design principles
<a id="41-stats-modifiers-definition"></a>

Design principles:

- **Shared-kept**: shared modifiers will be kept on the forged item.
- **Pool risk/reward**: non-shared modifiers go into that channel’s pool for rolling to keep on the forged item.
- **Consistent algorithms**: merging and selection are defined once up front; each channel applies them with its own identity keys.

The universal rules are defined next:

- **Selection rule + overall cap trimming** ([Section 4.2](#42-selection-rule-shared--pool--cap))
- **Merging rule** ([Section 4.3](#43-merging-rule-how-numbers-are-merged))

### 4.2. Selection rule (all modifiers)
<a id="42-selection-rule-shared--pool--cap"></a>

This selection rule is **universal** for all three modifier channels:

- **Blue Stats** ([Section 4.4](#44-blue-stats-channel))
- **ExtraProperties** ([Section 4.5](#45-extraproperties-inheritance))
- **Skills** ([Section 4.6](#46-skills-inheritance))

Each channel has its own **unshared pool candidates list** and is selected independently, then everything competes under the single **overall rollable slots cap** (`OverallCap[Rarity_out, ItemType_out]`, default+learned per save, tracked per (rarity, item type) pair).

#### Universal notation (used across all channels)

- **S**: Shared Modifiers (count)
- **P_size**: Pool size (candidate count)
- **P**: Modifiers from pool (kept/picked count)
- **F**: Forged item modifiers for the channel, before overall-cap trimming: `F = S + P`

Channel mapping:

- Blue stats: `S_bs`, `P_bs_size`, `P_bs`, `F_bs`
- ExtraProperties (internal tokens): `S_ep`, `P_ep_size`, `P_ep`, `F_ep`
- Skills: `S_sk`, `P_sk_size`, `P_sk`, `F_sk`

#### Step 1: Separate shared vs pool (per channel)

Compare the two parents **within the same channel**:

- **Shared modifiers**: on both parents by that channel's identity key.
- **Pool candidates**: present on only one parent.

Notes by channel:

- **Blue stats**: identity key is the stats **key** (numbers may merge later).
- **ExtraProperties**: identity key is the canonicalised token key; tokens are stored as separate lines internally.
- **Skills**: identity key is the skill **ID** (e.g. `Shout_Whirlwind`), not the boost name.

#### Step 2: Set the expected baseline (E)

Now work out your starting point for the pool.
You begin at **about one-third of the pool**, rounded down (this is the "expected baseline", E). This makes **non-shared** stats noticeably harder to keep, while **shared** stats remain stable.

Examples:

- Pool size 1 → baseline is 0 (then you 50/50 roll to keep it or lose it)
- Pool size 3 → expect to keep 1
- Pool size 4 → expect to keep 1
- Pool size 7 → expect to keep 2

Formula:

$$
E =
\begin{cases}
0 & \text{if } P_{size} = 0 \text{ or } P_{size} = 1 \\
\lfloor (P_{size} + 1) / 3 \rfloor & \text{otherwise}
\end{cases}
$$

**Cap-proximity dampener (when near overall cap):**

When a channel is already close to the overall cap (`S ≥ OverallCap - 1`), apply a dampener to make reaching the cap less automatic:

- **Cross-type**: With probability `q_cross = 0.45`, reduce the effective baseline: `E_eff = max(0, E - 1)`
- **Same-type**: With probability `q_same = 0.30`, reduce the effective baseline: `E_eff = max(0, E - 1)`
- Otherwise, use `E_eff = E` (no dampener)

This ensures that even with high shared stats, reaching the cap requires some luck, and same-type forging maintains a noticeable advantage over cross-type.

**Note:** The dampener only applies when `S ≥ OverallCap - 1`. For channels that are not near the cap, always use `E_eff = E`.

#### Step 3: Roll the luck adjustment (first roll + chain)

The system samples a **luck adjustment** `A` using a "first roll + chain" model.
This `A` is a **variance** added to the expected baseline **E**, changing how many pool stats you keep.

**What Bad/Neutral/Good rolls mean:**

- The system rolls **Bad/Neutral/Good** to determine a luck adjustment `A`:
  - **Bad roll**: `A = -1` (you keep **1 less** than the baseline `E`)
  - **Neutral roll**: `A = 0` (you keep the **same as** the baseline `E`)
  - **Good roll**: `A = +1` (you keep **1 more** than the baseline `E`)
- The first roll sets `A` to one of these three values: `-1`, `0`, or `+1`
- Chains can then modify `A` further (see below)
- The final pool count is `P = E_eff + A` (clamped between 0 and `P_size`), where `E_eff` is the effective baseline after applying the cap-proximity dampener (if applicable)

There are two types of probabilities used in the modifier inheritance system:
- **Cross-type probabilities**: applies to all items, and cross-type weapon
- **Same-type probabilities**: applies to weapons with the same `WeaponType`

**Default (applies to all items, and cross-type weapon):**

| Pool size | Tier           | First roll chances (Bad / Neutral / Good) | Chain chance (Down / Up; stop probabilities in parentheses) |
| :-------- | :------------- | :---------------------------------------- | :---------------------------------------------------------- |
| **1**     | Tier 1 (Safe)  | `0% / 50% / 50%`                          | None                                                        |
| **2–4**   | Tier 2 (Early) | `14% / 60% / 26%`                         | `0% (stop 100%) / 25% (stop 75%)`                            |
| **5–7**   | Tier 3 (Mid)   | `30% / 52% / 18%`                         | `30% (stop 70%) / 25% (stop 75%)`                           |
| **8+**    | Tier 4 (Risky) | `33% / 55% / 12%`                         | `40% (stop 60%) / 25% (stop 75%)`                           |

**Weapons only (same-type weapon):**

For weapons with the same `WeaponType` (e.g., two 2H swords), same-type probabilities are derived by doubling the "good" branch and renormalising. Chain chances remain the same.

| Pool size | Tier           | Cross-type (Bad / Neutral / Good) | Same-type (Bad / Neutral / Good) | Chain chance (Down / Up; stop probabilities in parentheses) |
| :-------- | :------------- | :-------------------------------- | :------------------------------- | :---------------------------------------------------------- |
| **1**     | Tier 1 (Safe)  | `0% / 50% / 50%`                  | `0% / 33.33% / 66.67%`           | None                                                        |
| **2–4**   | Tier 2 (Early) | `14% / 60% / 26%`                 | `11.11% / 47.62% / 41.27%`       | `0% (stop 100%) / 25% (stop 75%)`                            |
| **5–7**   | Tier 3 (Mid)   | `30% / 52% / 18%`                 | `25.42% / 44.07% / 30.51%`       | `30% (stop 70%) / 25% (stop 75%)`                           |
| **8+**    | Tier 4 (Risky) | `33% / 55% / 12%`                 | `29.46% / 49.11% / 21.43%`       | `40% (stop 60%) / 25% (stop 75%)`                           |

**Note:** Non-weapon items always use cross-type probabilities (but `TypeMatch=true` for eligibility), as type mismatches are not allowed.

Notation used below:

- `d` = down-chain chance (`p_chain_down`)
- `u` = up-chain chance (`p_chain_up`)

#### Weapon-type match modifier (Cross-type vs Same-type)

**Note:** `TypeMatch` is used in multiple systems (weapon boosts, base values, modifier inheritance). This section defines how it affects the modifier inheritance probability model.

Let:

- `TypeMatch = (WeaponType_1 == WeaponType_2)` for weapons
- `TypeMatch = true` for non-weapons (for eligibility purposes only)

The luck adjustment `A` is sampled from a tier-specific distribution:

- **Non-weapons**: Always use **cross-type (default)** distribution (regardless of `TypeMatch=true` for eligibility)
- **Weapons**: Use **same-type** distribution if `TypeMatch=true`, otherwise use **cross-type (default)** distribution

Same-type is derived from the cross-type baseline by **doubling the "good" branch** and renormalising (this doubles every `A > 0` outcome).

Given the cross-type first-roll probabilities for a tier (from the table above):
- `p_bad_cross` = cross-type Bad probability
- `p_neutral_cross` = cross-type Neutral probability
- `p_good_cross` = cross-type Good probability

We define same-type weights:

$$w_{bad}=p_{bad,cross}$$
$$w_{neutral}=p_{neutral,cross}$$
$$w_{good}=2\times p_{good,cross}$$

Then normalise:

$$Z=w_{bad}+w_{neutral}+w_{good}$$
$$p_{bad,same}=w_{bad}/Z,\ \ p_{neutral,same}=w_{neutral}/Z,\ \ p_{good,same}=w_{good}/Z$$

**First roll (choose Bad / Neutral / Good):**

Each tier defines `p_bad`, `p_neutral`, `p_good` (sum to 100%).

The first roll sets the initial value of `A`:

- **Bad roll**: `A = -1`
- **Neutral roll**: `A = 0` (stops here, no chain)
- **Good roll**: `A = +1`

**Chain (push further down/up):**

After the first roll, chains can modify `A` further:

- **If first roll was Bad** (`A = -1`): repeatedly apply a **down-chain** with probability `p_chain_down`:
  - on success: `A -= 1` and try again
  - on failure: stop
- **If first roll was Good** (`A = +1`): repeatedly apply an **up-chain** with probability `p_chain_up`:
  - on success: `A += 1` and try again
  - on failure: stop

Finally apply the clamp via `P = clamp(E_eff + A, 0, P_size)`. Equivalently, `A` is effectively clamped to:

- `A_min = -E_eff` (cannot keep fewer than 0 pool modifiers)
- `A_max = P_size - E_eff` (cannot keep more than all pool modifiers)

Closed form probabilities (after clamping) for any tier:

Let `d = p_chain_down`, `u = p_chain_up`, and let:

- `N_down = E_eff` (max negative magnitude, since `A_min = -E_eff`)
- `N_up = P_size - E_eff` (max positive magnitude, since `A_max = P_size - E_eff`)

**Note:** Use `E_eff` (the effective baseline after cap-proximity dampener) instead of `E` when calculating probabilities.

Then:

- For `n = 1..(N_down-1)`:  
  `P(A = -n) = p_bad × d^(n-1) × (1 - d)`
- `P(A = -N_down) = p_bad × d^(N_down-1)` _(cap bucket; includes all deeper chains; i.e. "hit the cap or go beyond it")_
- `P(A = 0) = p_neutral`
- For `n = 1..(N_up-1)`:  
  `P(A = +n) = p_good × u^(n-1) × (1 - u)`
- `P(A = +N_up) = p_good × u^(N_up-1)` _(cap bucket; includes all deeper chains; i.e. "hit the cap or go beyond it")_

**Cap bucket (why it exists and how tables show it):**

The cap bucket represents cases where `A` would theoretically go beyond `±N_*`, but is clamped. This is particularly relevant because the final forged item is limited by `OverallCap[Rarity_out, ItemType_out]` (see [`rarity_system.md`](rarity_system.md#221-overall-rollable-slots-cap)). Even if `A` could add more pool stats, the final forged item is limited by the cap for that specific (rarity, item type) pair, so higher `A` values that would result in more than the cap total forged stats are impractical.

Some worked-example tables expand the cap bucket into:

- "Stop at the cap" (exactly `A = ±N_*`), and
- "Overflow; clamped" (the chain would go beyond `±N_*`, but `P` is clamped).

**Safety rule (always true):** you can't keep fewer than **0** pool modifiers, and you can't keep more than the **pool size**.

#### Step 4: Build the per-channel result list

For a given channel:

1. Keep all **shared modifiers** (`S`).
2. Add **P** random modifiers from the channel's pool candidates list (uniformly).
3. This yields the channel's planned result count: `F = S + P`.

#### Step 5: Apply the overall modifier cap (cross-channel)
<a id="45-apply-overall-modifier-cap"></a>

The forged item has a single cap `OverallCap[Rarity_out, ItemType_out]` across:

- Blue stats
- ExtraProperties (slot)
- Skills

This section defines how we trim when `F_total > OverallCap`.

**Protection rule:**

- Shared modifiers are protected (not dropped by cap trimming).
- ExtraProperties slot is protected if `S_ep ≥ 1` (shared ExtraProperties exists).
  - Note: `S_ep ≥ 1` protects the ExtraProperties **slot** even if other ExtraProperties tokens are unshared (`P_ep_size > 0`). Non-shared tokens are still rolled under the internal token selection rule (see [Section 4.5.3](#453-extraproperties-selection--internal-cap)).
- Skills preserved by the **skillbook lock** are treated as protected for overall-cap trimming (see [Section 4.6.2.1](#4621-skillbook-lock)).

**Trimming rule (slot-weighted):**

- After protected/shared slots are counted, the remaining slots are allocated by rolling between _pending pool-picked slots_.
- Weight per channel is:
  - Blue stats: `P_bs` (number of pool-picked blue stats)
  - Skills: `P_sk` (number of pool-picked skills, if any)
  - ExtraProperties slot: `1` if the EP slot is pending as a pool slot (i.e. `S_ep = 0` and EP exists), else `0`

If a channel wins a slot:

- **Blue stats**: pick one of the remaining pool-picked blue stats uniformly.
- **Skills**: pick one of the remaining pool-picked skills uniformly.
- **ExtraProperties**: keep the EP slot (then apply [Section 4.5.3](#453-extraproperties-selection--internal-cap) internal token selection).

**Sequential trimming (weights update after each drop):**

If you need to drop more than 1 slot (i.e. `F_total > OverallCap` by 2+), that means we need to trim 2+ times, depending on the number of slots to drop. The weights are recalculated each time because `P_bs`, `P_sk`, and/or the pending EP slot may have changed.

Example (Skill protected; EP pending; trim 2 slots):

```
Output rarity: Divine ⇒ `OverallCap = 5` (default)

Parent A: Divine Warhammer
 - +3 Strength             (shared)
 - +2 Warfare              (shared)
 - +15% Critical Chance    (shared)
 - Shout_Whirlwind         (shared or protected by skillbook lock)
 - +20% Fire Resistance    (pool)

Parent B: Divine Giant Sword
 - +3 Strength             (shared)
 - +2 Warfare              (shared)
 - +15% Critical Chance    (shared)
 - Shout_Whirlwind         (shared or protected by skillbook lock)
 - +20% Poison Resistance  (pool)
 - ExtraProperties: MUTED,10,1 (pool; EP slot pending)

Shared (protected):
 - Blue stats → `S_bs = 3`
 - Skills → `S_sk = 1`
 - ExtraProperties tokens → `S_ep = 0` (not shared; EP slot is pending as a pool slot)

Pool candidates:
 - Blue stats → `P_bs_size = 2` (Fire Res, Poison Res)
 - ExtraProperties tokens → `P_ep_size = 1` (MUTED,10,1)
```

Now suppose the channel rolls produce:

- Blue stats kept from pool: `P_bs = 2` (kept 2 from `P_bs_size = 2`)
- EP slot: pending (`S_ep = 0` and EP exists) ⇒ `EPslot = 1`

Planned total:

- `F_total = S_bs + S_sk + P_bs + EPslot = 3 + 1 + 2 + 1 = 7` ⇒ over cap by 2 ⇒ drop 2 pool slots

Trim 1st slot (weights `Blue:EP = 2:1`):

- Drop a pool blue stat with probability **66.67%** (then `P_bs` becomes 1)
- Drop the EP slot with probability **33.33%** (then `EPslot` becomes 0)

Trim 2nd slot:

- If the 1st drop was **Blue** (**66.67%**): weights are now `Blue:EP = 1:1` ⇒ drop Blue with probability **50.00%**, drop EP with probability **50.00%**
- If the 1st drop was **EP** (**33.33%**): only Blue remains as a pool slot ⇒ the 2nd drop must be Blue (**100.00%**)

Therefore:

- EP survives only if the forge drops Blue twice: `66.67% × 50.00% = 33.33%`
- EP is dropped (at some point) with probability **66.67%**

Imagine you're forging these two **boots** (boots can only forge with boots):

```
Parent A: Ranger's Boots
 - +1 Finesse
 - +0.5m Movement
 - +10% Fire Resistance
 - +1 Sneaking

Parent B: Scout's Boots
 - +1 Finesse
 - +0.5m Movement
 - +2 Initiative
 - +10% Air Resistance
```

Split into lists:

- Shared Blue Stats: `+1 Finesse`, `+0.5m Movement` → `S_bs = 2`
- Pool Blue Stats candidates: `+10% Fire Resistance`, `+1 Sneaking`, `+2 Initiative`, `+10% Air Resistance` → `P_bs_size = 4`

Now calculate how many pool stats you keep:

- Pool size `P_bs_size = 4` → **Tier 2** (pool size 2–4)
- Expected baseline: `E = floor((P_bs_size + 1) / 3) = floor(5 / 3) = 1`
- First roll: Good roll → `A = +1`
- Chain up: Chain succeeds → `A = +2` (final luck adjustment)
- Modifiers from pool (kept): `P_bs = clamp(E_eff + A, 0, P_bs_size) = clamp(1 + 2, 0, 4) = 3` (assuming no dampener applies in this example)
- Planned forged blue modifiers (before overall trimming): `F_bs = S_bs + P_bs = 2 + 3 = 5`

Finally apply the overall rollable-slot cap:

- Assume the rarity system gives the new item **Legendary Boots** → `OverallCap[Legendary, Boots] = 4` (default, or learned if higher)
- Final (blue only, no other channels in this example): `Final = min(F_bs, OverallCap) = min(5, 4) = 4`

So you end up with:

- The 2 shared blue stats (always)
- Plus 2 of the pool blue stats (3 were kept from the pool, but 1 was trimmed by the overall cap)

---

#### 4.2.1. Safe vs YOLO forging
<a id="421-safe-vs-yolo-forging"></a>

These two standalone examples are meant to show the difference between:

- **Safe forging**: many shared stats → stable outcomes (pool stats are just "bonus").
- **YOLO forging**: zero shared stats → pure variance (rare spikes are possible, but unreliable).

#### Safe forging (realistic cap: `OverallCap ≤ 5`, with skills/ExtraProperties competing)

```
Output rarity: Divine ⇒ `OverallCap[Divine, Warhammer] = 5` (default)

Parent A: Divine Warhammer
 - +3 Strength          (shared)
 - +2 Warfare           (shared)
 - +15% Critical Chance (shared)
 - +20% Fire Resistance (pool)
 - Shout_Whirlwind      (pool)

Parent B: Divine Giant Sword
 - +3 Strength          (shared)
 - +2 Warfare           (shared)
 - +15% Critical Chance (shared)
 - +20% Poison Resistance (pool)
 - ExtraProperties: MUTED,10,1  (pool)

─────────────────────────────────────────
Shared Modifiers:
 - Shared Blue Stats: +3 Strength, +2 Warfare, +15% Critical Chance → S_bs = 3
Pool Modifiers:
 - Pool Blue Stats: +20% Fire Resistance, +20% Poison Resistance → P_bs_size = 2
 - Pool Skills: Shout_Whirlwind → P_sk_size = 1
 - Pool ExtraProperties: MUTED,10,1 → P_ep_size = 1
```

Inputs for this example:

- `OverallCap[Divine, Warhammer] = 5` (default, or learned if higher)
- Shared totals (protected): `S_total = S_bs + S_sk + S_ep = 3 + 0 + 0 = 3`

This is the perfect example for **Safe Forging**:

- With **3 shared blue stats**, you have a stable core.
- Because the overall cap is **5**, the result must allocate the remaining **2 slots** between:
  - pool-picked blue stats (`P_bs`)
  - pool-picked skills (`P_sk`)
  - the pending ExtraProperties slot (weight 1 if kept)

Concrete outcome intuition:

- Suppose the channel selections produce:
  - Blue stats: `P_bs = 1` (kept 1 from `P_bs_size = 2`)
  - Skills: `P_sk = 1` (kept 1 from `P_sk_size = 1`)
  - EP slot: pending
  - Then `F_total = S_bs + P_bs + S_sk + P_sk + EPslot = 3 + 1 + 0 + 1 + 1 = 6` ⇒ over cap by 1.
- Using the **slot-weighted** overall trimming rule ([Step 5 of Section 4.2](#45-apply-overall-modifier-cap)):
  - weight(Blue) = `P_bs = 1`, weight(Skills) = `P_sk = 1`, weight(EP) = `1`
  - one of these three pool-picked slots is dropped (each **33.33%** in this case).

#### YOLO forging (realistic cap: `OverallCap ≤ 5`, everything competes)

```
Output rarity: Divine ⇒ `OverallCap[Divine, Warhammer] = 5` (default)

Parent A: Divine Warhammer
 - +3 Strength          (pool)
 - +2 Warfare           (pool)
 - +2 Two-Handed        (pool)
 - +15% Accuracy        (pool)
 - Shout_Whirlwind      (pool)

Parent B: Divine Warhammer
 - +15% Critical Chance (pool)
 - +20% Fire Resistance (pool)
 - +10% Air Resistance  (pool)
 - +1000 Health        (pool)
 - ExtraProperties: MUTED,10,1  (pool)

─────────────────────────────────────────
Shared Modifiers:
 none
Pool Modifiers:
 - Pool Blue Stats: +3 Strength, +2 Warfare, +2 Two-Handed, +15% Accuracy, +15% Critical Chance, +20% Fire Resistance, +10% Air Resistance, +1000 Health → P_bs_size = 8
 - Pool Skills: Shout_Whirlwind → P_sk_size = 1
 - Pool ExtraProperties: MUTED,10,1 → S_ep = 1
```

This is the perfect example for **YOLO forging**:

- With **0 shared stats**, you have **no guarantees**. Everything is a roll from the pool.
- Even if the blue-stats roll "wants" to keep many stats, the final result is hard-limited to **5 total rollable slots**.
- Because skills and ExtraProperties are pool slots here, they can be dropped under the same overall trimming step as pool-picked blue stats.

---

### 4.3. Merging rule (Blue Stats / ExtraProperties)
<a id="43-merging-rule-how-numbers-are-merged"></a>

Sometimes both parents have the **same stats**, but the **numbers** are different:

- `+10% Critical Chance` vs `+14% Critical Chance`
- `+3 Strength` vs `+4 Strength`

In this system, those are still treated as **shared modifiers** (same identity key), but the forged item will roll a **merged value**:

- **Blue Stats**: identity key is the stats key (e.g. `CriticalChance`, `Strength`)
- **ExtraProperties**: identity key is the canonicalised token key (e.g. `BLIND,10,1`, `BLIND,20,1`); if a shared token has numeric parameters, those parameters are merged using the same algorithm below

For ExtraProperties shared/pool selection and internal-cap rules, see [Section 4.5](#45-extraproperties-inheritance) (especially [Section 4.5.2](#452-extraproperties-shared-vs-pool) and [Section 4.5.3](#453-extraproperties-selection--internal-cap)).

#### Special case: Reflection (return damage received as X damage)

Vanilla implements “Return X% of damage received as Y damage” as a `Reflection` stats field (not an ExtraProperties token). Treat `Reflection` as a **Blue Stats** numeric stat with a typed key.

Parsing:

- If the value matches `pct::DamageType:AttackKind` (e.g. `10::Water:melee`), parse it as `(pct, DamageType, AttackKind)`.
- If the value is a bare number `pct` (no `::`), parse it as `(pct, Unknown, Unknown)`.

Identity key:

- `Reflection::<DamageType>::<AttackKind>` (so the bare-number case becomes `Reflection::Unknown::Unknown`)

Merging:

- If both parents have the same identity key, merge the percent value using the same BS numeric merge formula and percent rounding rules in this section (then clamp to a sensible cap, e.g. 100%).
- If the parents have different `(DamageType, AttackKind)`:
  - Decide the output `(DamageType, AttackKind)` using the 60%/40% main/secondary rule below.
  - Then merge the percent value using the same BS numeric merge formula as above and apply it to the chosen output type.

60%/40% main/secondary type resolution:

- Define parent A as “main” and parent B as “secondary” (ingredient order).
- Let the parent percents be `a` (main) and `b` (secondary).
- Compute:
  - `score_main = (a / (a + b)) × 0.60`
  - `score_secondary = (b / (a + b)) × 0.40`
- Choose the type from the higher score; if tied, choose the main type.
- `Unknown` is treated like any other type: it participates in the score comparison and can win.

Slot note:

- These "blue stats" keys are not limited to weapons/shields. Armour/jewellery can roll numeric blue stats too, for example:
  - Movement speed via `_Boost_Armor_Boots_Secondary_MovementSpeed` (applies `Movement=50`, Medium `75`, Large `100`)
  - Initiative via `_Boost_Armor_Belt_Secondary_Initiative` (applies `Initiative=2`, Medium `4`, Large `6`)

#### Definitions

- **Stats key**: the identity of the stats (e.g. `CriticalChance`, `Strength`). This ignores the number.
- **Stats value**: the numeric magnitude (e.g. `10`, `14`, `3`, `4`).

#### Merge formula

Given parent values $a$ and $b$ for the same stats key:

##### 1. Midpoint (baseline):

$$m = (a + b) / 2$$

##### 2. Roll type chances:

| Roll type             | Chance  | Multiplier                       |
| :-------------------- | :-----: | :------------------------------- |
| Tight (less volatile) | **50%** | $r \sim Tri(0.85,\ 1.00,\ 1.15)$ |
| Wide (more volatile)  | **50%** | $r \sim Tri(0.70,\ 1.00,\ 1.30)$ |

##### 3. Clamp the result (allowed min/max range):

To keep the behaviour symmetric for **negative values** (penalties) as well as positives, define the clamp bounds using absolute magnitude around the extremes:

$$lo = \min(a,b) - 0.15\times|\min(a,b)|$$
$$hi = \max(a,b) + 0.15\times|\max(a,b)|$$

##### 4. Final merged value:

$$value = clamp(m \times r,\ lo,\ hi)$$

Then format the number back into a stats line using the stats' rounding rules.

#### Rounding rules

- **Integer stats** (Attributes, skill levels): round to the nearest integer.
- **Percent stats** (Critical Chance, Accuracy, Resistances, "X% chance to set Y"): round to the nearest integer percent.
- **Distance stats** (Movement shown as metres in tooltips): round to the nearest `0.5m`.

Implementation note (SE, free values):

- Vanilla represents some modifiers via tiered boost entries (e.g. Movement/Initiative tiers), but the SE implementation can apply the merged numeric result as a free value (e.g. via permanent boosts). Therefore, the merged value is **not** snapped to a fixed rung ladder.

#### ExtraProperties parameter merging

When merging shared ExtraProperties tokens with numeric parameters (e.g. `BLIND,10,1` vs `BLIND,20,1`), apply the same merge algorithm with this special case:

- **Chance merging**: If either parent has chance ≥ 100%, keep chance to the highest value; If the merged chance is greater than 100%, use 100%.
- **Turns merging**: Apply the merge formula normally.

Apply the merge formula only when both parameters are below their respective caps; otherwise, use the capped value.

#### Worked examples

##### Example A: `+10%` vs `+14%` Critical Chance

- `a=10`, `b=14` → `m=12`
- `lo = 8.5`, `hi = 16.1`
- Tight roll range is `12 × [0.85, 1.15] = [10.2, 13.8]` → roughly **10%–14%** after rounding.
- Wide roll range is `12 × [0.70, 1.30] = [8.4, 15.6]` → **9%–16%** after rounding (low end clamps to 8.5).

##### Example B: `-0.5` vs `-1` Movement (penalty case; 2H mace vs Crossbow)

- Parent A: 2H mace
  - +2 Strength
  - `Movement = -0.5`
- Parent B: Crossbow
  - +5% Accuracy
  - `Movement = -1`
- Shared-by-key stat being merged here: `Movement`
- `a=-0.5`, `b=-1` → `m=-0.75`
- `lo = -1 - 0.15×| -1 | = -1.15`
- `hi = -0.5 + 0.15×| -0.5 | = -0.425`
- Tight roll range: `-0.75 × [0.85, 1.15] = [-0.8625, -0.6375]` → roughly **-1.0 to -0.5** after rounding (to the nearest `0.5m`).
- Wide roll range: `-0.75 × [0.70, 1.30] = [-0.975, -0.525]` → roughly **-1.0 to -0.5** after rounding (to the nearest `0.5m`).

##### Example C: `+3` vs `+4` Strength (small integers can still spike)

- `a=3`, `b=4` → `m=3.5`
- `lo = 2.55`, `hi = 4.6`
- Tight roll range: `3.5 × [0.85, 1.15] = [2.975, 4.025]` → **3–4** after rounding.
- Wide roll range: `3.5 × [0.70, 1.30] = [2.45, 4.55]` → **3–5** after rounding (high end is close to 5, and the clamp allows up to 4.6).

##### Example D: `+1` vs `+7` Strength (large gaps merge towards the middle)

- `a=1`, `b=7` → `m=4`
- `lo = 0.85`, `hi = 8.05`
- Tight roll range: `4 × [0.85, 1.15] = [3.4, 4.6]` → **3–5** after rounding.
- Wide roll range: `4 × [0.70, 1.30] = [2.8, 5.2]` → **3–5** after rounding.

##### Example E: `BLIND,10,1` vs `BLIND,10,3` (ExtraProperties turns merging)

- `a=1`, `b=3` → `m=2.0`
- `lo = min(1,3) × 0.85 = 0.85`
- `hi = max(1,3) × 1.15 = 3.45`
- Tight roll range: `2.0 × [0.85, 1.15] = [1.7, 2.3]` → **2** after rounding.
- Wide roll range: `2.0 × [0.70, 1.30] = [1.4, 2.6]` → **1–3** after rounding (1.4 → 1, 2.6 → 3).

##### Example F: `Reflection` type resolution (Water vs Fire), and the `Unknown` form

Case 1 (typed reflection values):

- Parent A (main): `10::Water:melee`
- Parent B (secondary): `15::Fire:melee`
- Type resolution:
  - `score_main = (10 / 25) × 0.60 = 0.24`
  - `score_secondary = (15 / 25) × 0.40 = 0.24`
  - Tie ⇒ choose main type ⇒ output type is `Water:melee`
- Percent merge (same as other percent blue stats):
  - `a=10`, `b=15` → `m=12.5`
  - `lo = 10 × 0.85 = 8.5`, `hi = 15 × 1.15 = 17.25`
  - Output percent is a rounded value in roughly **9%–17%**, depending on the roll.
- Output form: `Reflection = "<merged%>::Water:melee"`

Case 2 (bare-number “Unknown” form):

- Parent A (main): `10` ⇒ parse as `10::Unknown:Unknown`
- Parent B (secondary): `15::Fire:melee`
- Apply the same type resolution rule. If `Unknown` wins, the output type is `Unknown:Unknown`.

---

### 4.4. Blue Stats (BS)
<a id="44-blue-stats-channel"></a>

This section defines how **Blue Stats** are inherited when you forge.

Blue Stats are treated as its own channel:

- Each Blue Stats line consumes **1** overall rollable slot (shared cap across BS + EP + Sk).
- If a blue stat exists on both parents (shared by stats key), it is guaranteed to be kept, and its numeric value is merged (see [Section 4.3](#43-merging-rule-how-numbers-are-merged)).

#### 4.4.1. Blue Stats (definition)

<a id="441-blue-stats-definition"></a>

Blue Stats are rollable numeric boosts (blue text stats) that appear on items based on their rarity. These include:

- Attributes (Strength, Finesse, Intelligence, etc.)
- Combat abilities (Warfare, Scoundrel, etc.)
- Resistances (Fire, Poison, etc.)
- Other numeric modifiers (Critical Chance, Accuracy, Initiative, Movement, etc.)

**Note:** Blue Stats are treated as discrete modifier lines; they do not automatically "scale up" just because the item level changes during base-value normalisation (see [Section 4](#4-stats-modifiers-inheritance) level normalisation note).

**Clarification (base weapon traits vs rollable Blue Stats):** some item behaviours and penalties are part of the item’s **base template / weapon type**, not rollable modifiers. For example, crossbows have a built-in movement penalty, and daggers can backstab because of weapon type rules. These base traits are **not** treated as Blue Stats and must not enter `sharedBlueStats` / `poolBlueStats`. Only actual rollable modifier lines (stats modifiers) participate in Section 4’s shared/pool logic.

#### 4.4.2. Shared vs pool
<a id="442-shared-vs-pool-blue-stats"></a>

- **Shared Blue Stats (S_bs)**: blue stats lines on **both** parents (guaranteed).
- **Pool Blue Stats size (P_bs_size)**: blue stats lines that are **not shared** (unique to either parent). This is the combined pool candidates list from both parents.

Key values:

- `S_bs`: Shared Blue Stats (count)
- `P_bs_size`: pool size for Blue Stats (candidate count)
- `P_bs`: modifiers from pool (kept/picked count) for Blue Stats
- `F_bs`: forged blue modifiers before overall trimming (`F_bs = S_bs + P_bs`)

#### 4.4.3. Worked examples (Blue Stats)
<a id="443-worked-examples-blue-stats"></a>

**Note:**

- The probability tables below (tiers, `p_bad/p_neutral/p_good`, chain `d/u`) come from the **universal selection rule** in [Section 4.2](#42-selection-rule-shared--pool--cap) and can be applied to any modifier channel that uses that rule. We show them using **Blue Stats** (can be ExtraProperties or Skills) only because it is the most direct/visible channel for worked maths.
- The worked examples below focus on the **blue-stats selection step** (blue stats channel only).
- To keep the tables readable and consistent, we assume:
  - Output rarity is **Divine**, so `OverallCap[Divine, ItemType] = 5` (default, or learned if higher).
  - Other channels (Skills / ExtraProperties) do not occupy slots in these tables.
- Therefore, any outcomes where the blue-stats result would reach or exceed 5 are bucketed into **`5+`** (meaning "≥5, at or above the overall cap").

#### Tier 1 (Pool size = 1, no chains)

##### Example 1

```
Parent A: Traveller's Amulet
 - +1 Aerotheurge (shared)
 - +0.5m Movement (pool)

Parent B: Scout's Amulet
 - +1 Aerotheurge (shared)
─────────────────────────────────────────
Shared Blue Stats:
 - +1 Aerotheurge
Pool Blue Stats:
 - +0.5m Movement
```

Inputs for this example:

- `S_bs = 1` (Shared Blue Stats)
- `P_bs_size = 1` (Pool Blue Stats size)
- `E = 0` (Expected baseline, special case for `P_size = 1`)

Parameters used (Tier 1):

- Cross-type: `p_bad=0%`, `p_neutral=50%`, `p_good=50%`, `d=0.00`, `u=0.00` (no chain)
- Same-type: `p_bad=0%`, `p_neutral=50%`, `p_good=50%`, `d=0.00`, `u=0.00` (no chain)

**Note:** The cap-proximity dampener applies (`S_bs = 4 ≥ OverallCap - 1`), but when `E = 0`, the dampener has no effect because `E_eff = max(0, 0 - 1) = 0` (you cannot reduce 0 further). Therefore, the probabilities shown below are the same whether the dampener triggers or not.

| Luck adjustment<br>(A) | Modifiers from pool<br>(P_bs) | Forged item modifiers<br>(F_bs) | Chance (math)                                                       | Cross-type (default) | Same-type |
| :--------------------: | :-------------------------: | :---------------------------: | :------------------------------------------------------------------ | -------------------: | --------: |
|           0            |              0              |               1               | Cross: `p_neutral = 50%`<br>Same: `p_neutral = 50%`                 |               50.00% |    50.00% |
|           +1           |              1              |               2               | Cross: `p_good = 50%` (no chain)<br>Same: `p_good = 50%` (no chain) |               50.00% |    50.00% |

#### Tier 2 (Pool size = 2–4)

##### Example 1 (Pool size = 3)

```
Parent A: Mage's Helmet
 - +2 Intelligence      (shared)
 - +10% Fire Resistance (pool)
 - +1 Loremaster        (pool)

Parent B: Scholar's Helmet
 - +2 Intelligence      (shared)
 - +10% Water Resistance (pool)
─────────────────────────────────────────
Shared Blue Stats:
 - +2 Intelligence
Pool Blue Stats:
 - +10% Fire Resistance
 - +1 Loremaster
 - +10% Water Resistance
```

Inputs for this example:

- `S_bs = 1` (Shared Blue Stats)
- `P_bs_size = 3` (Pool Blue Stats size)
- `E = floor((P_bs_size + 1) / 3) = floor(4 / 3) = 1` (Expected baseline)

The blue-stats selection step yields between **1** and **4** blue modifiers (**1** shared + **0–3** from the pool).

Parameters used (Tier 2):

- Cross-type: `p_bad=14%`, `p_neutral=60%`, `p_good=26%`, `d=0.00`, `u=0.25`
- Same-type: `p_bad=11.11%`, `p_neutral=47.62%`, `p_good=41.27%`, `d=0.00`, `u=0.25`

| Luck adjustment<br>(A) | Modifiers from pool<br>(P_bs) | Forged item modifiers<br>(F_bs) | Chance (math)                                                                                                | Cross-type (default) | Same-type |
| :--------------------: | :-------------------------: | :---------------------------: | :----------------------------------------------------------------------------------------------------------- | -------------------: | --------: |
|           -1           |              0              |               1               | Cross: `p_bad = 14%` (no down-chain)<br>Same: `p_bad = 11.11%`                                               |               14.00% |    11.11% |
|           0            |              1              |               2               | Cross: `p_neutral = 60%`<br>Same: `p_neutral = 47.62%`                                                       |               60.00% |    47.62% |
|           +1           |              2              |               3               | Cross: `p_good × (1-u) = 26% × (1-0.25) = 19.50%`<br>Same: `p_good × (1-u) = 41.27% × (1-0.25) = 30.95%` |               19.50% |    30.95% |
|           +2           |              3              |               4               | Cross: `p_good × u = 26% × 0.25 = 6.50%` (cap bucket)<br>Same: `p_good × u = 41.27% × 0.25 = 10.32%`     |                6.50% |    10.32% |

##### Example 2 (Pool size = 2, near-cap case with dampener)

```
Parent A: Divine Warhammer
 - +2 Strength          (shared)
 - +1 Two-Handed        (shared)
 - +1 Warfare           (shared)
 - +10% Critical Chance (shared)
 - +10% Fire Resistance (pool)

Parent B: Divine Warhammer
 - +2 Strength          (shared)
 - +1 Two-Handed        (shared)
 - +1 Warfare           (shared)
 - +10% Critical Chance (shared)
 - +12% Poison Resistance (pool)
─────────────────────────────────────────
Shared Blue Stats:
 - +2 Strength
 - +1 Two-Handed
 - +1 Warfare
 - +10% Critical Chance
Pool Blue Stats:
 - +10% Fire Resistance
 - +12% Poison Resistance
```

Inputs for this example:

- `S_bs = 4` (Shared Blue Stats)
- `P_bs_size = 2` (Pool Blue Stats size)
- `E = floor((P_bs_size + 1) / 3) = floor(3 / 3) = 1` (Expected baseline)
- `S_bs = 4 ≥ OverallCap - 1 = 4` → **Cap-proximity dampener applies**

The blue-stats selection step yields between **4** and **6** blue modifiers (**4** shared + **0–2** from the pool).

Parameters used (Tier 2):

- Cross-type: `p_bad=14%`, `p_neutral=60%`, `p_good=26%`, `d=0.00`, `u=0.25`
- Same-type: `p_bad=11.11%`, `p_neutral=47.62%`, `p_good=41.27%`, `d=0.00`, `u=0.25`

**Near-cap summary tables (clear):**

When `S_bs = 4` (cap-1), you are deciding whether you can fill the **last slot** from the pool.

**Tier 1 (Pool size = 1) variant:** `S_bs = 4`, `P_bs_size = 1`, `E = 0` (no chains)

**Note:** The cap-proximity dampener applies (`S_bs = 4 ≥ OverallCap - 1`), but when `E = 0`, the dampener has no effect because `E_eff = max(0, 0 - 1) = 0` (you cannot reduce 0 further). Therefore, the probabilities shown below are the same whether the dampener triggers or not.
| Result bucket | Modifiers from pool<br>(P_bs) | Forged item modifiers<br>(F_bs) | Chance (math) | Cross-type | Same-type |
| :------------ | :-------------------------: | :---------------------------: | :------------ | ---------: | --------: |
| Below cap | 0 | 4 | Cross: `p_neutral = 50%`<br>Same: `p_neutral = 33.33%` | 50.00% | 33.33% |
| `5+` | 1 | 5+ | Cross: `p_good = 50%`<br>Same: `p_good = 66.67%` | 50.00% | 66.67% |

**This Tier 2 (Pool size = 2) case with dampener:** `S_bs = 4`, `P_bs_size = 2`, `E = 1`

Cap-proximity dampener (applies because `S_bs ≥ OverallCap - 1`):

- Cross-type: dampener triggers with probability `q_cross = 0.45`
- Same-type: dampener triggers with probability `q_same = 0.30`

| Result bucket | Modifiers from pool<br>(P_bs) | Forged item modifiers<br>(F_bs) | Chance (math) | Cross-type | Same-type |
| :------------ | :-------------------------: | :---------------------------: | :------------ | ---------: | --------: |
| Below cap | 0 | 4 | Cross: `(1-q_cross)×p_bad + q_cross×(p_bad+p_neutral)`<br>Same: `(1-q_same)×p_bad + q_same×(p_bad+p_neutral)` | 41.00% | 25.40% |
| `5+` | 1+ | 5+ | Cross: `(1-q_cross)×(1-p_bad) + q_cross×p_good`<br>Same: `(1-q_same)×(1-p_bad) + q_same×p_good` | 59.00% | 74.60% |

Notes:

- This table shows the **final** outcome probabilities after accounting for the dampener’s trigger chance.

##### Example 3 (Pool size = 4, weapon-only cross-subtype allowed)

```
Parent A: Knight's Dagger
 - +1 Warfare           (shared)
 - +10% Critical Chance (shared)
 - +1 Finesse           (pool)
 - +2 Initiative        (pool)

Parent B: Soldier's One-Handed Axe
 - +1 Warfare           (shared)
 - +10% Critical Chance (shared)
 - +12% Fire Resistance (pool)
 - 10% chance to set Bleeding (pool)
─────────────────────────────────────────
Shared Blue Stats:
 - +1 Warfare
 - +10% Critical Chance
Pool Blue Stats:
 - +1 Finesse
 - +2 Initiative
 - +12% Fire Resistance
 - 10% chance to set Bleeding
```

Inputs for this example:

- `S_bs = 2` (Shared Blue Stats)
- `P_bs_size = 4` (Pool Blue Stats size)
- `E = floor((P_bs_size + 1) / 3) = floor(5 / 3) = 1` (Expected baseline)

The blue-stats selection step yields between **2** and **6** blue modifiers (**2** shared + **0–4** from the pool).

Parameters used (Tier 2):

- Cross-type: `p_bad=14%`, `p_neutral=60%`, `p_good=26%`, `d=0.00`, `u=0.25`
- Same-type: `p_bad=11.11%`, `p_neutral=47.62%`, `p_good=41.27%`, `d=0.00`, `u=0.25`

| Luck adjustment<br>(A) | Modifiers from pool<br>(P_bs) | Forged item modifiers<br>(F_bs) | Chance (math)                                                                                         | Cross-type (default) | Same-type |
| :--------------------: | :-------------------------: | :---------------------------: | :---------------------------------------------------------------------------------------------------- | -------------------: | --------: |
|           -1           |              0              |               2               | Cross: `p_bad = 14%` (no down-chain)<br>Same: `p_bad = 11.11%`                                        |               14.00% |    11.11% |
|           0            |              1              |               3               | Cross: `p_neutral = 60%`<br>Same: `p_neutral = 47.62%`                                                |               60.00% |    47.62% |
|           +1           |              2              |               4               | Cross: `p_good × (1-u) = 26% × 0.75 = 19.50%`<br>Same: `p_good × (1-u) = 41.27% × 0.75 = 30.95%` |               19.50% |    30.95% |
|          +2+           |             3+              |              5+               | Cross: `p_good × u = 26% × 0.25 = 6.50%`<br>Same: `p_good × u = 41.27% × 0.25 = 10.32%`           |                6.50% |    10.32% |

#### Tier 3 (Pool size = 5–7)

##### Example 1 (Pool size = 5)

```
Parent A: Ranger's Boots
 - +1 Finesse           (shared)
 - +0.5m Movement       (shared)
 - +2 Initiative        (pool)
 - +10% Fire Resistance (pool)
 - +1 Sneaking          (pool)

Parent B: Scout's Boots
 - +1 Finesse           (shared)
 - +0.5m Movement       (shared)
 - +10% Air Resistance  (pool)
 - +10% Earth Resistance (pool)
─────────────────────────────────────────
Shared Blue Stats:
 - +1 Finesse
 - +0.5m Movement
Pool Blue Stats:
 - +2 Initiative
 - +10% Fire Resistance
 - +1 Sneaking
 - +10% Air Resistance
 - +10% Earth Resistance
```

Inputs for this example:

- `S_bs = 2` (Shared Blue Stats)
- `P_bs_size = 5` (Pool Blue Stats size)
- `E = floor((P_bs_size + 1) / 3) = floor(6 / 3) = 2` (Expected baseline)

The blue-stats selection step yields between **2** and **7** blue modifiers (**2** shared + **0–5** from the pool).

Parameters used (Tier 3):

- Cross-type: `p_bad=30%`, `p_neutral=52%`, `p_good=18%`, `d=0.30`, `u=0.25`
- Same-type: `p_bad=25.42%`, `p_neutral=44.07%`, `p_good=30.51%`, `d=0.30`, `u=0.25`

| Luck adjustment<br>(A) | Modifiers from pool<br>(P_bs) | Forged item modifiers<br>(F_bs) | Chance (math)                                                                                     | Cross-type (default) | Same-type |
| :--------------------: | :-------------------------: | :---------------------------: | :------------------------------------------------------------------------------------------------ | -------------------: | --------: |
|           -2           |              0              |               2               | Cross: `p_bad × d = 30% × 0.30 = 9.00%` (cap bucket)<br>Same: `p_bad × d = 25.42% × 0.30 = 7.63%` |                9.00% |     7.63% |
|           -1           |              1              |               3               | Cross: `p_bad × (1-d) = 30% × 0.70 = 21.00%`<br>Same: `p_bad × 0.70 = 25.42% × 0.70 = 17.80%`     |               21.00% |    17.80% |
|           0            |              2              |               4               | Cross: `p_neutral = 52%`<br>Same: `p_neutral = 44.07%`                                            |               52.00% |    44.07% |
|          +1+           |             3+              |              5+               | Cross: `p_good = 18%` (cap bucket; includes A = +1, +2, +3)<br>Same: `p_good = 30.51%` (cap bucket; includes A = +1, +2, +3) |               18.00% |    30.51% |

##### Example 2 (Pool size = 7)

```
Parent A: Enchanted Greatsword
 - +1 Strength          (shared)
 - +1 Warfare           (pool)
 - +10% Critical Chance (pool)
 - +1 Two-Handed        (pool)
 - +15% Accuracy        (pool)

Parent B: Champion's Greatsword
 - +1 Strength          (shared)
 - +12% Fire Resistance (pool)
 - +1 Pyrokinetic       (pool)
 - +1 Aerotheurge       (pool)
─────────────────────────────────────────
Shared Blue Stats:
 - +1 Strength
Pool Blue Stats:
 - +1 Warfare
 - +10% Critical Chance
 - +1 Two-Handed
 - +15% Accuracy
 - +12% Fire Resistance
 - +1 Pyrokinetic
 - +1 Aerotheurge
```

Inputs for this example:

- `S_bs = 1` (Shared Blue Stats)
- `P_bs_size = 7` (Pool Blue Stats size)
- `E = floor((P_bs_size + 1) / 3) = floor(8 / 3) = 2` (Expected baseline)

The blue-stats selection step yields between **1** and **8** blue modifiers (**1** shared + **0–7** from the pool).

Parameters used (Tier 3):

- Cross-type: `p_bad=30%`, `p_neutral=52%`, `p_good=18%`, `d=0.30`, `u=0.25`
- Same-type: `p_bad=25.42%`, `p_neutral=44.07%`, `p_good=30.51%`, `d=0.30`, `u=0.25`

| Luck adjustment<br>(A) | Modifiers from pool<br>(P_bs) | Forged item modifiers<br>(F_bs) | Chance (math)                                                                                     | Cross-type (default) | Same-type |
| :--------------------: | :-------------------------: | :---------------------------: | :------------------------------------------------------------------------------------------------ | -------------------: | --------: |
|           -2           |              0              |               1               | Cross: `p_bad × d = 30% × 0.30 = 9.00%` (cap bucket)<br>Same: `p_bad × d = 25.42% × 0.30 = 7.63%` |                9.00% |     7.63% |
|           -1           |              1              |               2               | Cross: `p_bad × (1-d) = 30% × 0.70 = 21.00%`<br>Same: `p_bad × 0.70 = 25.42% × 0.70 = 17.80%`     |               21.00% |    17.80% |
|           0            |              2              |               3               | Cross: `p_neutral = 52%`<br>Same: `p_neutral = 44.07%`                                            |               52.00% |    44.07% |
|           +1           |              3              |               4               | Cross: `p_good × (1-u) = 18% × 0.75 = 13.50%`<br>Same: `p_good × 0.75 = 30.51% × 0.75 = 22.88%`   |               13.50% |    22.88% |
|          +2+           |             4+              |              5+               | Cross: `p_good × u = 18% × 0.25 = 4.50%`<br>Same: `p_good × u = 30.51% × 0.25 = 7.63%`            |                4.50% |     7.63% |

#### Tier 4 (Pool size = 8+)

##### Example 1 (Pool size = 8)

```
Parent A: Tower Shield
 - +2 Constitution      (pool)
 - +1 Perseverance              (pool)
 - +2 Initiative        (pool)
 - +10% Water Resistance (pool)

Parent B: Kite Shield
 - +10% Fire Resistance (pool)
 - +10% Earth Resistance (pool)
 - +1 Leadership        (pool)
 - +0.5m Movement       (pool)
─────────────────────────────────────────
Shared Blue Stats:
 (none)
Pool Blue Stats:
 - +2 Constitution
 - +1 Perseverance
 - +2 Initiative
 - +10% Water Resistance
 - +10% Fire Resistance
 - +10% Earth Resistance
 - +1 Leadership
 - +0.5m Movement
```

Inputs for this example:

- `S_bs = 0` (Shared Blue Stats)
- `P_bs_size = 8` (Pool Blue Stats size)
- `E = floor((P_bs_size + 1) / 3) = floor(9 / 3) = 3` (Expected baseline)

The blue-stats selection step yields between **0** and **8** blue modifiers (**0** shared + **0–8** from the pool).

  - This is “riskier crafting” in practice: fewer shared stats means more “unknown” stats in the pool.

Parameters used (Tier 4):

- Cross-type: `p_bad=33%`, `p_neutral=55%`, `p_good=12%`, `d=0.40`, `u=0.25`
- Same-type: `p_bad=29.46%`, `p_neutral=49.11%`, `p_good=21.43%`, `d=0.40`, `u=0.25`

| Luck adjustment<br>(A) | Modifiers from pool<br>(P_bs) | Forged item modifiers<br>(F_bs) | Chance (math)                                                                                                        | Cross-type (default) | Same-type |
| :--------------------: | :-------------------------: | :---------------------------: | :------------------------------------------------------------------------------------------------------------------- | -------------------: | --------: |
|           -3           |              0              |               0               | Cross: `p_bad × d^2 = 33% × 0.40^2 = 5.28%` (cap bucket)<br>Same: `p_bad × d^2 = 29.46% × 0.40^2 = 4.71%`            |                5.28% |     4.71% |
|           -2           |              1              |               1               | Cross: `p_bad × d × (1-d) = 33% × 0.40 × 0.60 = 7.92%`<br>Same: `p_bad × 0.40 × 0.60 = 29.46% × 0.40 × 0.60 = 7.07%` |                7.92% |     7.07% |
|           -1           |              2              |               2               | Cross: `p_bad × (1-d) = 33% × 0.60 = 19.80%`<br>Same: `p_bad × 0.60 = 29.46% × 0.60 = 17.68%`                        |               19.80% |    17.68% |
|           0            |              3              |               3               | Cross: `p_neutral = 55%`<br>Same: `p_neutral = 49.11%`                                                               |               55.00% |    49.11% |
|           +1           |              4              |               4               | Cross: `p_good × (1-u) = 12% × 0.75 = 9.00%`<br>Same: `p_good × 0.75 = 21.43% × 0.75 = 16.07%`                       |                9.00% |    16.07% |
|          +2+           |             5+              |              5+               | Cross: `p_good × u = 12% × 0.25 = 3.00%`<br>Same: `p_good × u = 21.43% × 0.25 = 5.36%`                               |                3.00% |     5.36% |

---

### 4.5. ExtraProperties (EP)
<a id="45-extraproperties-inheritance"></a>

This section defines how **ExtraProperties** are inherited when you forge.

ExtraProperties is treated as its own channel:

- ExtraProperties consumes **1** overall rollable slot if present (regardless of how many internal effects/tooltip lines it expands into).
- The **internal content** (tokens) is merged/selected separately, with an internal cap based on the parents.

#### 4.5.1. ExtraProperties (definition)
<a id="451-extraproperties-definition"></a>

ExtraProperties is a semicolon-separated list of effects stored on the item. These include:

- Status chance effects ("X% chance to set Y")
- Status immunities (e.g. "Poison Immunity")
- Surface effects (e.g. "Create Ice surface")
- Other special effects (proc chances, statuses, etc.)

Important: the tooltip may show multiple lines, but for the overall cap, ExtraProperties is counted as **one slot**.

#### 4.5.2. Shared vs pool tokens
<a id="452-extraproperties-shared-vs-pool"></a>

Parse each parent's ExtraProperties string into ordered tokens:

- Split on `;`
- Trim whitespace
- Drop empty tokens (e.g. trailing `;` creates an empty token)
- Normalise into a canonical key for identity comparisons (e.g. strip whitespace, normalise case where safe, and isolate the “effect type” portion).

Then compute:

- **Shared ExtraProperties (S_ep)**: tokens that match by canonical key on both parents (guaranteed to be kept, with parameter merge if applicable).
- **Pool ExtraProperties size (P_ep_size)**: tokens present on only one parent (pool candidates).

Numeric parameter merging note:

- If a shared token has numeric parameters (chance/turns/etc.), merge its numbers using the global merging rule in [Section 4.3](#43-merging-rule-how-numbers-are-merged) (see: [ExtraProperties parameter merging](#extraproperties-parameter-merging)).

Vanilla token families (rule table):

| Token family (vanilla) | Raw examples (non-exhaustive) | Canonical key recommendation | Best-fit design (reuse vs custom) |
| :-- | :-- | :-- | :-- |
| Status-chance-turns | `BLIND,20,2`, `CHILLED,10,1`, `MUTED,10,1`, `COW,100,-1` | Status ID only, e.g. `BLIND` | **Reuse existing EP design**: shared/pool by canonical key ([Section 4.5.2](#452-extraproperties-shared-vs-pool)); numeric merge for shared tokens via [Section 4.3](#43-merging-rule-how-numbers-are-merged) (chance special-case + turns merge). Sentinel turns like `-1` may appear in vanilla; recommended policy: if either parent has `turns = -1`, keep `-1`, else merge normally. Token list clamped by `InternalCap` ([Section 4.5.3](#453-extraproperties-selection--internal-cap)). |
| Status/proc with qualifier / ref arg (4 fields) | `DYING,100,-1,DoT`, `EXPLODE,100,0,Projectile_LivingBomb_Explosion` | `Status::<StatusId>::<Arg4>` (include the 4th field in the key) | **Custom-on-top of EP**: treat as status-like tokens, but only share/merge when both `StatusId` and the 4th arg match. Merge chance/turns using [Section 4.3](#43-merging-rule-how-numbers-are-merged) (including the `-1` sentinel policy above); keep arg4 unchanged. |
| Bare opcodes (no commas) | `Freeze`, `Electrify`, `Contaminate`, `Oilify`, `Ignite;Melt`, `Ignite;` | Full opcode token (trimmed), e.g. `Freeze`, `Ignite` | **Reuse EP design with “opaque tokens”**: canonical key is the full opcode token; shared only on exact match; no numeric merge (no parameters). If multiple opcodes exist, treat each as its own token under `InternalCap`. |
| Surface creation | `CreateSurface,1,,Fire`, `CreateSurface,4,,WaterFrozen,100;`, `CreateSurface,1,-1,BloodCursed,100` | `CreateSurface::<SurfaceType>` (and include radius/extra args in the key only if you want them to block sharing) | **Custom-on-top of EP**: treat as EP tokens, but parse into `(surfaceType, radius, duration?, chance?)` when possible. Recommended: canonical key includes opcode + surface type; merge numeric parameters for shared surface tokens using [Section 4.3](#43-merging-rule-how-numbers-are-merged) per-parameter (percent-like vs integer-like), then clamp to sensible caps. If parsing fails, fall back to opaque-token matching. |
| Targeted surface creation | `TargetCreateSurface,1,,Water`, `TargetCreateSurface,1,-1,BloodCursed, 100;` | `TargetCreateSurface::<SurfaceType>` | Same as `CreateSurface` (custom-on-top of EP). Treat `TargetCreateSurface` and `CreateSurface` as **different** opcodes (different keys) even if surface types match. |
| On-equip directives | `Self:OnEquip:EVADING`, `Self:OnEquip:WINGS`, `Self:OnEquip:DISARMED;Self:OnEquip:HEALING_TEARS`, `SELF:ONEQUIP:SOURCE_MUTED` | `Self:OnEquip::<StatusId>` per directive (normalise case and `ONEQUIP` → `OnEquip`) | **Reuse EP design with a small custom parser**: split on `;`, then treat each `Self:OnEquip:*` directive as one token. Shared only when the same directive appears on both parents. Avoid numeric merge unless the directive itself has numeric args (rare; treat as opaque if present). |
| Conditional / “script-like” directives | `IF(Self&...):...`, `TARGET:IF(...):...`, `SELF:OnHit:IF(...):...` | Entire directive string (opaque) | **Best design: treat as opaque EP tokens**. Do not attempt to canonicalise or merge unless you explicitly support the grammar; only exact-match sharing is safe. (These appear in editor/ability data; treat them as edge-case inputs for forging unless you want full support.) |
| Indirection / references | `_Vitality_ShieldBoost` | Full token string | **Custom policy choice**: either (a) treat as opaque EP token (shared only on exact match), or (b) resolve the reference into its expanded tokens first, then apply the normal EP rules. Option (b) is more faithful but requires a resolver. |

#### 4.5.3. Selection + internal cap (max of parent lines, with same-count bonus)
<a id="453-extraproperties-selection--internal-cap"></a>

Let:

- `A = tokenCount(parentA)`
- `B = tokenCount(parentB)`
- `InternalCap = max(A, B)` (base cap)

**Same-count bonus rule:**

If both parents have the same number of EP tokens (`A == B`) AND the forged item inherits the ExtraProperties slot (either through shared EP `S_ep ≥ 1` or through pool selection), the internal cap gets a **+1 bonus**:

- `InternalCap = A + 1` (allows inheriting all unique tokens from both parents)

**When the bonus applies:**

- Both parents have the same token count (`A == B`)
- The forged item inherits the ExtraProperties slot (protected by `S_ep ≥ 1`, or selected from pool)

For example (same-count bonus):

```
Parent A ExtraProperties (A = 2 tokens):
 - Poison Immunity
 - Set Chilled for 1 turn 15% chance

Parent B ExtraProperties (B = 2 tokens):
 - Poison Immunity
 - Set Silenced for 2 turns 20% chance
─────────────────────────────────────────
Shared tokens: Poison Immunity → `S_ep = 1` (slot inherited and protected)
Pool tokens: Chilled (15%, 1), Silenced (20%, 2) → `P_ep_size = 2`
Because `A == B == 2` and the EP slot is inherited → `InternalCap = A + 1 = 3`

So the forged item can have up to 3 tokens:
- Poison Immunity
- Set Chilled for 1 turn 15% chance
- Set Silenced for 2 turns 20% chance
```

**When the bonus does NOT apply:**

- Parents have different token counts (`A != B`) → use `InternalCap = max(A, B)`
- The forged item does not inherit the ExtraProperties slot

For example (different-count, no bonus):

```
Parent A ExtraProperties (A = 3 tokens):
 - Poison Immunity
 - Set Chilled for 1 turn 15% chance
 - Set Silenced for 2 turns 20% chance

Parent B ExtraProperties (B = 2 tokens):
 - Fire Immunity
 - Creates a 4m Ice surface when targeting terrain
─────────────────────────────────────────
Shared tokens: Poison Immunity, Chilled (15%, 1) → `S_ep = 2` (slot inherited and protected)
Pool tokens: Silenced (20%, 2) → `P_ep_size = 1`
Because `A != B` (3 vs 2) → `InternalCap = max(A, B) = 3` (no `+1` bonus)

So the forged item can have up to 3 tokens (can be any combination of the tokens):
- Poison Immunity
- Set Silenced for 2 turns 20% chance
- Creates a 4m Ice surface when targeting terrain
```

Build the output token list:

1. Keep all shared tokens (merge parameters if the same token differs in numbers, using the same "merge then clamp" philosophy as blue stats).
2. Determine `InternalCap`:
   - If `A == B` and EP slot is inherited: `InternalCap = A + 1`
   - Otherwise: `InternalCap = max(A, B)`
3. Roll additional tokens from the pool using the selection rule in [Section 4.2](#42-selection-rule-shared--pool--cap):
   - `P_size = P_ep_size`, `P = P_ep`
4. Clamp the final token list to `InternalCap`.

#### 4.5.4. Slot competition + trimming
<a id="454-extraproperties-slot-competition--trimming"></a>

ExtraProperties occupies one **slot** in the overall rollable cap.

Rule:

- If `S_ep ≥ 1`, the ExtraProperties slot is **guaranteed** to be present (it consumes 1 slot and is protected from overall-cap trimming).
- Otherwise, the ExtraProperties slot is a **pool slot**. If the forge result is over the overall cap, this slot competes under the universal overall-cap trimming rule in [Step 5 of Section 4.2](#45-apply-overall-modifier-cap) (slot-weighted).
  - Note: It is valid for `S_ep ≥ 1` and `P_ep_size > 0` at the same time. In that case, the slot is protected, but non-shared tokens are still rolled internally (see [Section 4.5.3](#453-extraproperties-selection--internal-cap)).

#### 4.5.5. Worked examples
<a id="455-worked-examples"></a>

**Example 1: EP slot protected (`S_ep ≥ 1`), but internal tokens still roll**

This shows the “shared EP but not fully shared” case: the slot is protected from overall-cap trimming, but unshared tokens are still subject to `InternalCap` and pool selection.

```
Output rarity: Divine ⇒ `OverallCap = 5` (default)

Parent A (Divine boots)
 Blue stats:
  - +1 Finesse          (shared)
  - +0.5m Movement      (shared)
  - +1 Sneaking         (pool)
 ExtraProperties (A = 2 tokens):
  - Poison Immunity     (shared)
  - Set Chilled for 1 turn 15% chance (pool)

Parent B (Divine boots)
 Blue stats:
  - +1 Finesse          (shared)
  - +0.5m Movement      (shared)
  - +2 Initiative       (pool)
  - +10% Air Resistance (pool)
 ExtraProperties (B = 2 tokens):
  - Poison Immunity     (shared)
  - Set Silenced for 2 turns 20% chance (pool)
─────────────────────────────────────────
Shared (protected):
 - Blue stats → `S_bs = 2`
 - ExtraProperties tokens → `S_ep = 1` (EP slot is inherited and protected)

Pool candidates:
 - Blue stats → `P_bs_size = 3` (Sneaking, Initiative, Air Res)
 - ExtraProperties tokens → `P_ep_size = 2` (Chilled, Silenced)
─────────────────────────────────────────
Suppose the channel rolls produce:
 - Blue stats kept from pool: `P_bs = 3`
 - EP slot: protected (because `S_ep ≥ 1`) ⇒ `EPslot = 1` (always present)

Planned total (before overall-cap trimming):
 - `F_total = S_bs + P_bs + EPslot = 2 + 3 + 1 = 6` ⇒ over cap by 1 ⇒ drop 1 pool blue stat

EP internal cap (Section 4.5.3):
 - `A == B == 2` and EP slot is inherited ⇒ `InternalCap = A + 1 = 3`
 - Token list starts with shared Poison Immunity (`S_ep = 1`), then roll up to `P_ep` tokens from the EP pool and clamp to `InternalCap`.
```

**Example 2: EP slot pending (`S_ep = 0`) and can be dropped by overall-cap trimming**

This shows the “unshared EP” case: the EP slot itself competes with other pool-picked slots. If the slot is dropped, internal tokens are discarded (the item has no ExtraProperties).

```
Output rarity: Divine ⇒ `OverallCap = 5` (default)

Parent A (Divine boots)
 Blue stats:
  - +1 Finesse          (shared)
  - +0.5m Movement      (shared)
  - +1 Sneaking         (pool)
 ExtraProperties (A = 1 token):
  - Poison Immunity     (pool)

Parent B (Divine boots)
 Blue stats:
  - +1 Finesse          (shared)
  - +0.5m Movement      (shared)
  - +2 Initiative       (pool)
 ExtraProperties (B = 1 token):
  - Fire Immunity       (pool)
─────────────────────────────────────────
Shared (protected):
 - Blue stats → `S_bs = 2`
 - ExtraProperties tokens → `S_ep = 0` (no shared EP)

Pool candidates:
 - Blue stats → `P_bs_size = 2` (Sneaking, Initiative)
 - ExtraProperties tokens → `P_ep_size = 2` (Poison Immunity, Fire Immunity)
─────────────────────────────────────────
Suppose the channel rolls produce:
 - Blue stats kept from pool: `P_bs = 2`
 - EP exists and `S_ep = 0` ⇒ EP slot is pending as a pool slot ⇒ `EPslot = 1`

Planned total (before overall-cap trimming):
 - `F_total = S_bs + P_bs + EPslot = 2 + 2 + 1 = 5` (at cap) ⇒ no trimming

If instead the result was over cap by 1 (e.g. there was 1 extra pool-picked slot from another channel), then the trim roll would be slot-weighted:
 - Weights are `Blue:EP = P_bs:1 = 2:1`
 - Drop a pool blue stat with probability **66.67%**
 - Drop the EP slot with probability **33.33%** (and then EP internal selection does not happen at all)
```

**Example 3: Shared EP token with numeric parameters (parameter merging)**

This shows how a shared ExtraProperties token merges numeric parameters before the token list is clamped by `InternalCap`. The merging algorithm is defined in [Section 4.3](#43-merging-rule-how-numbers-are-merged) (see: [ExtraProperties parameter merging](#extraproperties-parameter-merging)).

```
Parent A ExtraProperties (A = 2 tokens):
 - Set Blinded for 3 turns 10% chance  (BLIND,10,3)
 - Poison Immunity

Parent B ExtraProperties (B = 2 tokens):
 - Set Blinded for 1 turn 15% chance   (BLIND,15,1)
 - Fire Immunity
─────────────────────────────────────────
Shared tokens:
 - BLIND → `S_ep = 1` (shared by canonical key; numeric parameters are merged)

Pool tokens:
 - Poison Immunity, Fire Immunity → `P_ep_size = 2`
─────────────────────────────────────────
InternalCap (Section 4.5.3):
 - `A == B == 2` and the EP slot is inherited ⇒ `InternalCap = A + 1 = 3`

Merged BLIND parameters (Section 4.3):
 - Chance: merge `10%` and `15%` (then clamp to 100% if needed)
 - Turns: merge `3` and `1`
 - Final BLIND token is one merged token (still counts as 1 token toward `InternalCap`)

 Possible Blinded status outcomes:
 - The merged BLIND token can be any `BLIND,chance,turns` where:
   - `chance ∈ {9..16}` (percent, rounded)
   - `turns ∈ {1, 2, 3}`
```

---

### 4.6. Skills (Sk)
<a id="46-skills-inheritance"></a>

This section defines how **granted skills** are inherited when you forge.

- Granted skills are a separate channel from normal **blue stats**.
- Each rollable granted skill consumes **1** overall rollable slot (shared cap with blue stats + ExtraProperties).
- Skills are rollable; unless preserved by the **skillbook lock** or shared between both parents, they can be lost when applying the overall cap (equal drop chance among pool slots).
- Skills also have a per-save learned **skill count cap** (`SkillCap[r]`) defined in [`rarity_system.md`](rarity_system.md#222-skill-cap-vnext).

Here are what you can expect:

- You can sometimes carry a skill across, or gain one from the ingredient pool, but you will always be limited by the rarity’s **skill cap** (default is 1 for all non-Unique rarities).
- Even if a skill is gained by the skill rules, it can still be dropped later if the final item is over the **overall rollable-slot cap** and the skill is not protected (no skillbook lock; not shared).

#### 4.6.1. Granted skills (definition)
<a id="461-granted-skills-definition"></a>

- **Granted skill (rollable)**: any rollable boost/stats line that grants entries via a `Skills` field in its boost definition.
  - Weapon example: `_Boost_Weapon_Skill_Whirlwind` → `Shout_Whirlwind`
  - Shield example: `_Boost_Shield_Skill_BouncingShield` → `Projectile_BouncingShield`
  - Armour/jewellery example: `_Boost_Armor_Gloves_Skill_Restoration` → `Target_Restoration` (defined in `Armor.stats`)
- **Not a granted skill (base)**: a `Skills` entry baked into the base weapon stats entry (not a rolled boost), e.g. staff base skills like `Projectile_StaffOfMagus` (**base-only; never enters `poolSkills`**).

#### Vanilla scope note

- Only treat **`BoostType="Legendary"`** skill boosts as “vanilla rarity-roll skills”.
- Ignore **`BoostType="ItemCombo"`** skill boosts for vanilla-aligned behaviour.

#### Vanilla hygiene note (non-Unique focus)

This section is designed around **non-Unique, rollable granted skills**. Vanilla data also contains `Skills` fields on internal/NPC templates that should not be treated as rollable granted skills:

- Ignore placeholder skills like `Target_NULLSKILL` (treat as “no skill”).
- If a stats entry explicitly clears skills (e.g. `clear_inherited_value="true"` with an empty value), treat it as “no skill”.
- When parsing any `Skills` list, split on `;`, trim whitespace, and drop empty entries.
- If a non-Unique item instance ever has **more than 1** rollable granted skill, process them normally as multiple skill entries: they go into `sharedSkills` / `poolSkills`, each consumes **1** overall rollable slot, and they compete under the overall cap like other pool-picked slots (unless protected by shared/skillbook rules).

#### Item-type constraints (hard rule for skill inheritance)

- **Weapon can only forge with weapon**, and **shield can only forge with shield**, etc.
- Therefore:
  - A **weapon** must only ever roll/inherit **weapon skill boosts**.
  - A **shield** must only ever roll/inherit **shield skill boosts**.
  - A **chest** must only ever roll/inherit **chest skill boosts**.
  - A **jewellery** must only ever roll/inherit **jewellery skill boosts**.
- If you ever encounter “mixed” skills in runtime data, treat that as invalid input (or ignore the mismatched skill boosts).

#### 4.6.2. Skill cap by rarity
<a id="462-skill-cap-by-rarity"></a>

This is the maximum number of **rollable granted skills** on the forged item.

This cap is **default + learned per save**:

- Default values are listed below.
- The save can learn higher values if the player ever obtains an item of that rarity with more rollable granted skills.
- See: [`rarity_system.md` → Skill count cap](rarity_system.md#222-skill-cap-vnext)

| Rarity index | Name      | Granted skill cap |
| :----------- | :-------- | :---------------: |
| **0**        | Common    |       **1**       |
| **1**        | Uncommon  |       **1**       |
| **2**        | Rare      |       **1**       |
| **3**        | Epic      |       **1**       |
| **4**        | Legendary |       **1**       |
| **5**        | Divine    |       **1**       |

_Unique is ignored for now (do not consider it in balancing)._

#### 4.6.2.1. Skillbook lock (preserve by exact skill ID)
<a id="4621-skillbook-lock"></a>

If the player inserts a skillbook into the dedicated forge UI slot, the forge must validate it against the parent item's granted skill(s):

- Match by **exact skill ID** (e.g. `Target_ShockingTouch`, `Shout_Whirlwind`), not by display name.
- If the skillbook does not match any skill granted by the main-slot item (parent A), block forging with:
  - “No matched skills found on the item!”

If both parents have matching skillbooks:

- The main-slot item’s (parent A) skill is the guaranteed inherited one.

#### 4.6.3. Shared vs pool skills
<a id="463-shared-vs-pool-skills"></a>

Split granted skills into two lists:

- **Shared Skills (S_sk)**: granted skills present on **both** parents (kept unless we must trim due to cap overflow).
- **Pool Skills size (P_sk_size)**: granted skills present on **only one** parent (pool candidates).

#### Skill identity (dedupe key)

Use the **skill ID** as the identity key (e.g. `Shout_Whirlwind`, `Projectile_BouncingShield`), not the boost name.

#### 4.6.4. How skills are gained (gated fill)
<a id="464-how-skills-are-gained-gated-fill"></a>

Skills are **more precious than stats**, so the skill channel does **not** use the stat-style "keep half the pool" baseline.

Instead, skills use a **cap + gated fill** model:

- **Shared skills are protected** (kept first).
- You only try to gain skills for **free skill slots** (up to the rarity skill cap).
- The chance to gain a skill **increases with pool size** (`P_remaining`).

#### Key values (skills)

- **S_sk**: number of shared rollable skills (present on both parents).
- **P_sk_size**: number of pool rollable skills (present on only one parent).
- **SkillCap**: from [Section 4.6.2](#462-skill-cap-by-rarity).
- **FreeSlots**: `max(0, SkillCap - min(S_sk, SkillCap))`

#### Gain chance model (rarity + pool size)

We define a per-attempt gain chance:

`p_attempt_cross = base_cross(rarity) * m(P_remaining)`

Weapon-type match modifier:

- If `TypeMatch=true` (exact same WeaponType for weapons; always true for non-weapons), then `p_attempt = clamp(2 × p_attempt_cross, 0, 100%)`.
- Otherwise, `p_attempt = p_attempt_cross`.

Where `base_cross(rarity)` (cross-type default) is:

- `base_cross(Common) = 12%` _(tuning default)_
- `base_cross(Uncommon) = 14%` _(tuning default)_
- `base_cross(Rare) = 16%` _(tuning default)_
- `base_cross(Epic) = 18%` _(tuning default)_
- `base_cross(Legendary) = 18%` _(tuning default)_
- `base_cross(Divine) = 20%` _(tuning default)_

And the pool-size multiplier is:

| `P_remaining` | `m(P_remaining)` |
| :-----------: | :--------------: |
|       1       |       1.0        |
|       2       |       1.4        |

Because each parent item can contribute at most **1** rollable granted skill, we always have:

- `P_remaining ∈ {0,1,2}`

So the actual per-attempt gain chances are:

| Output rarity | `P_remaining` | Cross-type `p_attempt` (default) | Same-type `p_attempt` (2×, capped) |
| :------------ | :-----------: | :------------------------------: | :--------------------------------: |
| Common        |       1       |              12.0%               |               24.0%                |
| Common        |       2       |              16.8%               |               33.6%                |
| Uncommon      |       1       |              14.0%               |               28.0%                |
| Uncommon      |       2       |              19.6%               |               39.2%                |
| Rare          |       1       |              16.0%               |               32.0%                |
| Rare          |       2       |              22.4%               |               44.8%                |
| Epic          |       1       |              18.0%               |               36.0%                |
| Epic          |       2       |              25.2%               |               50.4%                |
| Legendary     |       1       |              18.0%               |               36.0%                |
| Legendary     |       2       |              25.2%               |               50.4%                |
| Divine        |       1       |              20.0%               |               40.0%                |
| Divine        |       2       |              28.0%               |               56.0%                |

Procedure summary (host-authoritative; driven by `forgeSeed`):

1. Build `sharedSkills` (deduped) and `poolSkills` (deduped).
2. Keep shared first: `finalSkills = sharedSkills` (trim down to `SkillCap` only if shared exceeds cap).
3. Compute `freeSlots = SkillCap - len(finalSkills)`.
4. Fill free slots with gated gain rolls:
   - For each free slot (at most `freeSlots` attempts):
     - Let `P_remaining = len(poolSkills)`
     - Roll a random number; success chance is `p_attempt` (above).
     - If success: pick 1 random skill from `poolSkills`, add to `finalSkills`, remove it from `poolSkills`, and decrement `freeSlots`.
     - If failure: do nothing for that slot (skills are precious; you do not retry the same slot).

#### 4.6.5. Scenario tables
<a id="465-scenario-tables"></a>

These tables show the probability of ending with **0 / 1** rollable granted skills under this skill model (default `SkillCap = 1`).

Notes:

- These tables focus on **skill count outcomes** from the “gated fill” rules above.
- Weapon pools only contain weapon skills; shield pools only contain shield skills.

#### Scenario A: `S_sk = 0`, `P_sk_size ≥ 1` (no shared skill; at most one can be gained)

With default `SkillCap = 1`, there is only **one** free slot. Therefore:

- `P(final 1 skill) = p_attempt`
- `P(final 0 skills) = 1 - p_attempt`

Use the `p_attempt` table in [Section 4.6.4](#464-how-skills-are-gained-gated-fill) for the actual values.

#### Scenario B: `S_sk ≥ 1` (shared skill exists)

With default `SkillCap = 1`, any shared skill consumes the entire skill cap:

- Final is always **1 skill** (the shared one), unless later dropped by the **overall rollable-slot cap** (if not protected by the skillbook lock/shared rule).

#### 4.6.6. Worked example (Divine)
<a id="466-worked-example-divine"></a>

This is a **weapon** example (weapon-only skill boosts).

Assume the rarity system produces a **Divine** forged item:

- **SkillCap[Divine]**: **1** _(default)_

Parent A granted skills:

- `Shout_Whirlwind`

Parent B granted skills:

- `Projectile_SkyShot`

Split into lists (deduped by skill ID):

- Shared skills `S_sk = 0`: (none)
- Pool skills `P_sk_size = 2`: `Shout_Whirlwind`, `Projectile_SkyShot`

Compute free slots:

- `SkillCap = 1`
- `len(sharedKept) = 0`
- `freeSlots = 1`

Attempt to fill free slots:

- `P_remaining = 2`
- Divine gain chance (same-type): `p_attempt = clamp(2 × (base_cross(Divine) * m(2)), 0, 100%) = 2 × (20% × 1.4) = 56.0%`
- If the roll succeeds, pick 1 from the pool, e.g. `Projectile_SkyShot`

Final skills before cap:

 - If gain succeeded: one of `{Shout_Whirlwind, Projectile_SkyShot}`
 - If gain failed: (none)

Apply `SkillCap = 1`:

- If you gained a skill: you are at cap.

Result:

- The forged item can roll up to `OverallCap[Divine, ItemType]` **overall rollable slots** (blue stats + ExtraProperties + skills), where `OverallCap` is default+learned per save, tracked per (rarity, item type) pair.
- It will have at most `SkillCap[Divine]` rollable granted skills (default+learned per save).

---

## 5. Rune slots inheritance
<a id="5-rune-slots-inheritance"></a>

This section defines how many **empty rune slots** the forged item ends up with.

Here are what you can expect:

- Rune effects are never part of forging (rune-boosted items are rejected as ingredients). This section is only about **empty slots**.
- In implementation, use the **actual empty slot count** on the item instance at runtime (`RuneSlots`), not a hard-coded `0/1` assumption.

Vanilla-style constraint (important for balance):

- For **non-Unique** items, treat rune slots as a small **integer slot count** (`0..x`) read from the item instance. (In vanilla, `x` is small and item/rarity-dependent.)
- (Unique can be a special case later; do not assume that behaviour here.)

### Default rule (non-Unique)

Let the parents’ empty slot counts be:

- `A = RuneSlots(slot1)`
- `B = RuneSlots(slot2)`

Define:

- `m = min(A, B)` (shared slots; always kept)
- `d = max(A, B) - m` (extra slots available only on the higher-slot parent)

Then:

- `RuneSlots_out = m + X`, where `X` is the number of extra slots that carry over.
- For **cross-type (default)**: each of the `d` extra slots carries over with **50%** chance.
- For **same-type** (`TypeMatch=true`): each of the `d` extra slots carries over with **100%** chance (2×, capped).

This is the same mechanism as the `0/1` example — it simply applies per-slot when an item can have `x > 1` empty rune slots at runtime.

$$RuneSlots_{out} \in \{m, m+1, \dots, m+d\}$$

Examples (non-Unique):

| Parent A slots | Parent B slots | Forged slots (cross-type default)                  | Forged slots (same-type, 2× capped) |
| :------------: | :------------: | :------------------------------------------------- | :---------------------------------- |
|       0        |       0        | 0                                                  | 0                                   |
|       1        |       1        | 1                                                  | 1                                   |
|       0        |       1        | 0 or 1 (50%)                                       | 1                                   |
|       1        |       0        | 0 or 1 (50%)                                       | 1                                   |
|       1        |       3        | `1 + Binomial(2, 50%)` → 1 / 2 / 3                 | 3                                   |
|       2        |       3        | `2 + Binomial(1, 50%)` → 2 / 3                     | 3                                   |

---

## 6. Implementation reference
<a id="6-implementation-reference"></a>

This section is a developer reference for implementing the rules in this document.

[forging_system_implementation_blueprint_se.md → Appendix: Pseudocode reference](forging_system_implementation_blueprint_se.md#appendix-pseudocode-reference)

---

## 7. Unique forging (temporary)
<a id="7-unique-forging-temporary"></a>

This section defines a temporary, all-in-one rule set for **Unique** items. The intention is to split these rules into dedicated “Unique” parts under Sections 1–6 later.

**Scope note:** Unless stated otherwise, all **non-Unique** forging rules in this document still apply. Unique forging adds an additional “fuel-only” override and Unique-specific behaviour for stats modifiers.

### 7.1. Unique preconditions (fuel-only)
<a id="71-unique-preconditions-fuel-only"></a>

Unique forging follows all non-Unique ingredient eligibility rules, including:

- No socketed runes (and no rune-origin stats/skills), and
- Unequipped items only, and
- Type compatibility rules (weapon↔weapon, armour slot↔same slot, ring↔ring, etc.).

Additional Unique-only rules:

- **Unique cannot forge with Unique:** if both forge slots contain Unique items, forging is blocked.
- **Unique can only be fuelled by non-Unique:** the “fuel” ingredient must not be Unique.
- **Level gate bypass (Unique fuelling only):** when exactly one ingredient is Unique, the forge does not enforce the hard level gate for that operation. Output level is still the player’s level (`Level_out = Level_player`).

### 7.2. Output identity + slot priority (Unique dominance)
<a id="72-unique-output-identity-and-slot-priority"></a>

If exactly one ingredient is Unique, the forge uses **Unique dominance** (also described as “fuel-only”):

- The output item is always the **same Unique item identity** (100%).
- Slot priority does not matter for deciding the output. In implementation terms, treat the Unique ingredient as the “main/base” item and the non-Unique ingredient as the “fuel” item, regardless of which UI slot they occupy.

UI note:

- The forge UI remains the same as non-Unique forging.
- If both slots are Unique, the UI must prevent forging (and show a clear error).

### 7.3. Channel rules (base values + weapon boosts are Unique-locked)
<a id="73-unique-channel-rules-base-and-boosts-locked"></a>

When using Unique dominance (Unique + non-Unique fuel):

- **Base values are Unique-locked:** the Unique’s base values are not merged with, or influenced by, the fuel. (The output’s base values are those of the Unique at `Level_out`.)
- **Weapon boosts are Unique-locked:** the Unique’s weapon boosts are not merged with, or influenced by, the fuel.
- **Stats Modifiers are fuel-influenced:** Blue Stats, ExtraProperties, and Skills can change according to the Unique-specific rules below (still constrained by caps, trimming, and per-channel rules).

### 7.4. Snapshot model (base template + innate modifiers)
<a id="74-unique-snapshot-model"></a>

When a Unique item is first acquired by the player, it becomes a “base” item:

- Store a snapshot of the Unique’s **original template identity** (“born template”).
- Store a snapshot of the Unique’s original Stats Modifiers as **innate modifiers**:
  - Blue Stats (BS)
  - ExtraProperties (EP)
  - Granted Skills (Sk)

This snapshot is the reference point for all future Unique fuelling and for extraction/rollback.

### 7.5. Unique max-slot growth (cap expansion via fuel)
<a id="75-unique-max-slot-growth"></a>

Unique dominance introduces a per-instance cap for how many rollable modifier slots the Unique is allowed to carry.

On each Unique+fuel forge:

- Update the Unique’s per-instance maximum:
  - `UniqueMaxSlots = max(UniqueMaxSlots, slots(fuelItem))`
- Slot counting uses the same definition as the global cap system:
  - `slots(item) = blueStatLineCount + rollableSkillCount + (hasExtraProperties ? 1 : 0)`

Design intent:

- A Unique must expand its `UniqueMaxSlots` before it can meaningfully take on non-innate modifiers.
- `UniqueMaxSlots` is **per Unique instance** and does not change any global `OverallCap[r, t]` values in [`rarity_system.md`](rarity_system.md#221-overall-rollable-slots-cap).

### 7.6. Innate modifiers: always kept, merged but never below snapshot
<a id="76-unique-innate-modifiers-floor"></a>

Innate modifiers are protected and always kept on the Unique during Unique+fuel forging.

Rules:

- **Innate retention:** every innate modifier from the snapshot must be present on the forged Unique.
- **Innate modifiers are “always shared” (with a floor):** treat innate modifiers as if they always participate in the “shared merge” step:
  - If the fuel has the same modifier by identity key, merge **Unique current** vs **fuel** using the existing merge rules (Blue Stats and numeric EP parameter merging per [Section 4.3](#43-merging-rule-how-numbers-are-merged)).
  - If the fuel does **not** have that modifier, merge **Unique current** vs the **snapshot value** for that innate modifier.
  - After merging, clamp the result so it is **never below the snapshot value** for that innate modifier.

Example (floor behaviour):

- Unique dagger snapshot: `+3 Finesse` (innate)
- Fuel A: `+5 Finesse` ⇒ shared merge can raise the value (e.g. to `+4` or `+5`)
- Fuel B: `+1 Finesse` ⇒ shared merge may reduce the value, but it must not go below `+3` (snapshot floor). It can still end at `+4` if the current state was above the floor.
- Fuel C: no Finesse modifier ⇒ treat as if the fuel had `+3 Finesse` (snapshot) for merging, so the value can drift down towards `+3`, but never below it.

Worked intuition example (Band of Braccus):

- Snapshot (innate): `+2 Intelligence`, `+2 Constitution`
- Current (after prior fuels): `+4 Intelligence`, `+4 Constitution`
- Fuel ring: `+5 Intelligence` (no Constitution)
  - Intelligence merges as shared: midpoint `m = (4 + 5) / 2 = 4.5` (then roll/clamp per [Section 4.3](#43-merging-rule-how-numbers-are-merged))
  - Constitution merges against snapshot: midpoint `m = (4 + 2) / 2 = 3` (then roll/clamp), and is floored at `+2`

### 7.7. Non-innate modifiers: acquisition + instability rules
<a id="77-unique-non-innate-modifiers"></a>

Any modifier on the Unique that is not part of the snapshot is a **non-innate modifier**.

Rules:

- **Capacity gate:** non-innate modifiers can only be kept up to the Unique’s current `UniqueMaxSlots` (see [Section 7.5](#75-unique-max-slot-growth)).
- **Instability:** non-innate modifiers are not fully stable. When fuelling with items that do not share those modifiers, they can be lost through the usual pool selection and overall-cap trimming behaviour described in [Section 4.2](#42-selection-rule-shared--pool--cap) and [Section 4.2 Step 5](#45-apply-overall-modifier-cap).
- **Protection priority:** innate modifiers are protected first; trimming/slot competition should drop non-innate modifiers before it ever removes an innate modifier.

### 7.8. Extract (rollback) + extracted-item generation
<a id="78-unique-extract-rollback"></a>

Unique forging includes an Extract action so the player can “roll back” a Unique to its snapshot and optionally receive a separate item containing the net gains.

Definitions:

- `SnapshotMods`: the innate modifiers stored at acquisition (BS/EP/Sk).
- `CurrentMods`: the Unique’s current modifiers (BS/EP/Sk).
- `ExportMods`: the modifiers that will be placed onto the extracted item.

ExportMods rule:

- Compare `CurrentMods` to `SnapshotMods` by identity key (Blue Stats key, canonicalised EP token key, or exact skill ID).
- For each modifier key:
  - If the modifier exists in `CurrentMods` but not in `SnapshotMods`: export it at its **current value**.
  - If the modifier exists in both and the current value is **strictly better** than the snapshot value: export it at its **current value** .
  - Otherwise (equal to snapshot, or worse): do not export it.

Extract procedure (player-facing):

1. Compute `ExportMods` from the Unique by comparing `CurrentMods` to `SnapshotMods` using the rule above.
2. Optionally generate an extracted item at `Level_player` of the same item type/slot as the Unique (ring→ring, staff→staff, boots→boots, etc.) whose rollable modifiers are `ExportMods`.
3. Restore the Unique back to its snapshot state (born template identity + innate modifiers).
4. Reset `UniqueMaxSlots` back to the snapshot baseline (the Unique does not retain expanded capacity after extraction).

Worked example (Unique mace):

- Snapshot (innate):
  - `+4 Strength`
  - `+3 Memory`
  - `CHILLED,10,2` (10% chance to set Chilled for 2 turns)
  - `BLEEDING,15,1` (15% chance to set Bleeding for 1 turn)
- Current (after fuelling):
  - `+4 Strength` (unchanged)
  - `+5 Memory` (improved)
  - `CHILLED,10,3` (improved turns)
  - `BLEEDING,15,1` (unchanged)
  - Granted skill: `Rain` (new)

Then `ExportMods` is:

- `+5 Memory`
- `CHILLED,10,3`
- Granted skill: `Rain`

### 7.9. Extracted item rarity and “instance-only overcap Divine”
<a id="79-extracted-item-rarity-overcap-divine"></a>

The extracted item’s rarity is determined in two steps:

- A **slot-count floor** (guaranteed minimum rarity by rollable slot count), and
- A **level-based bonus roll** (so late-game extractions can still roll high rarity even with low slot counts).

Final rule:

- `Rarity_extracted = max(Rarity_floor(slots), Rarity_bonus(Level_player))`

#### Slot-count floor (guaranteed minimum rarity)

- `0` slots → Common
- `1` slot → Uncommon
- `2` slots → Rare
- `3` slots → Epic
- `4` slots → Legendary
- `5+` slots → Divine

#### Level-based bonus roll (can raise rarity; generous)

This roll exists to preserve a “vanilla-like” progression feel at high level: even if the extracted item only contains a small number of modifiers, the late-game economy can still surface Legendary/Divine items.

Roll `Rarity_bonus(Level_player)` host-authoritatively (deterministic; driven by `forgeSeed`).

- Level `1–3`:
  - Common **50%**
  - Uncommon **50%**
- Level `4–8`:
  - Uncommon **30%**
  - Rare **40%**
  - Epic **30%**
- Level `9–12`:
  - Rare **30%**
  - Epic **40%**
  - Legendary **30%**
- Level `12–15`:
  - Rare **30%**
  - Epic **40%**
  - Legendary **30%**
- Level `16-18`:
  - Legendary **50%**
  - Divine **50%**
- Level `19+`:
  - Divine **100%**

Special case: “instance-only overcap Divine”

- An extracted item can be Divine with more than 5 rollable slots (e.g. 7).
- This is an **instance-only** exception: it does not increase learned caps and does not change the global default Divine cap.
- Forging behaviour with overcap items:
  - If an overcap item forges with a normal (non-overcap) item whose applicable cap is lower, the result is still trimmed to the normal cap.
  - Overcap slots are only preserved when forging with another compatible overcap item (so the forge can legitimately keep those extra slots without trimming).

### 7.10. Ascendancy Points (AP): capacity + upgrades
<a id="710-unique-ascendancy-points"></a>

Unique items can earn **Ascendancy Points (AP)**, which are an allocatable **capacity** (respeccable outside combat) used to apply upgrades to the Unique’s modifiers.

#### AP capacity (`AP_max`)

Compute the Unique’s maximum Ascendancy Points from its current rollable slot count:

- `AP_max = floor(slots(Unique) / 5)`

Where `slots(item)` uses the same definition as the cap system:

- `slots(item) = blueStatLineCount + rollableSkillCount + (hasExtraProperties ? 1 : 0)`

Re-evaluate `AP_max`:

- After each Unique forge operation (after the final modifier set is decided, including overall-cap trimming), and
- After Extract rollback (because slot count can change).

#### Allocation + respec rules

- `AP_spent` is the number of **currently active upgraded modifiers** on the Unique.
- The player can respec outside combat at any time, reassigning upgrades to different modifiers and/or changing upgrade types.
- Each modifier can have **at most 1 active upgrade**.
- Multiple upgrades can be active at the same time, as long as `AP_spent ≤ AP_max`.

#### What happens when `AP_max` drops

If the Unique loses modifier slots (e.g. due to forging outcomes, trimming, or Extract rollback), `AP_max` can drop. If `AP_spent > AP_max`, upgrades are removed until within capacity:

- Remove upgrades **newest-first** (most recently applied upgrade is removed first) until `AP_spent ≤ AP_max`.
- The upgrade-removal order must be deterministic (store an incrementing `upgradeIndex` on the Unique and sort descending).

If a removed upgrade was a Replace-on-innate (see below), the suppressed innate modifier returns automatically.

#### Upgrade application timing (avoid ordering bugs)

To avoid interactions with pooling/trimming, apply Ascendancy upgrades **after**:

- the forge has determined the final modifiers list for the Unique (including overall-cap trimming), and
- `AP_max` has been recomputed.

This ensures upgrades never affect slot count and do not change trimming outcomes.

---

### Upgrade actions (cost: 1 AP each)

Each upgrade below costs **1 AP** and targets exactly one modifier (BS line, EP token, or a granted skill entry).

##### 1) Amplify (+30% effect)

Amplify increases the effect of one chosen modifier by **+30%**:

- **Blue Stats (BS)**: multiply the numeric value by `1.30` and then apply the stat’s normal rounding rules ([Section 4.3](#43-merging-rule-how-numbers-are-merged)).
- **ExtraProperties (EP; numeric parameters)**: for tokens with numeric parameters (chance/turns/etc.), multiply supported numeric parameters by `1.30`, then:
  - clamp chance to `≤ 100%`,
  - preserve `turns = -1` sentinel values unchanged (infinite/always) where they appear in vanilla-style tokens.

Notes:

- Amplify does not create new modifiers; it only scales an existing one.
- If the upgrade is removed (respec or `AP_max` drop), the modifier returns to its non-amplified value.

##### 2) Replace (swap a modifier using the current fuel)

Replace lets the player choose a modifier on the Unique and replace it with a modifier from the **current fuel** item used in that forge.

Hard rules:

- The replacement must be sourced from the current fuel item (no “banked library” of choices).
- Replace does not change the total slot count; it is a swap within the same slot budget.
- The replacement never becomes innate, and the snapshot is never modified.

Replacement identity safety (avoid duplicates):

- Do not allow Replace to create two modifiers with the same identity key on the Unique.
  - (Allowed exception: replacing a modifier with the same identity key but a different value is permitted, because the target is removed.)

Replace-on-innate: **suppress + overlay** (anti-abuse; bug-proof):

- Snapshot is immutable: the original innate set never changes.
- If the player targets an **innate** modifier key for Replace:
  - The innate modifier is **suppressed** while the Replace upgrade is active.
  - The chosen replacement modifier from the fuel is added as an **overlay** (non-innate).
  - The replacement is **never promoted to innate**.
- If the Replace upgrade is removed/disabled (respec, `AP_max` drop, or Extract rollback):
  - the overlay is removed, and the suppressed innate modifier **returns**,
  - the returning innate uses the Unique’s normal innate rules (including snapshot floors and “always shared” behaviour in [Section 7.6](#76-unique-innate-modifiers-floor)).

This prevents “washing off” innate modifiers permanently while still allowing full customisation while the upgrade is active.

##### 3) Reversal (flip to the opposite; 2×)

Reversal is a powerful conversion upgrade for a narrow, explicitly supported set of modifiers.

Numeric reversal (Blue Stats; allowlist):

- Only allow reversal for numeric stats where “opposite” makes sense (e.g. Attributes like Strength; action-point recovery; movement/initiative-style stats), and only when the stat is present as a rollable modifier line.
- Reversal flips the sign and doubles the magnitude:
  - `x → -2x`
  - Example: `-1 Strength` becomes `+2 Strength`; `+1 Strength` becomes `-2 Strength`.

Status reversal (ExtraProperties; allowlist):

- Only allow reversal for explicitly paired tokens, for example:
  - `CURSED` ↔ `BLESSED`
- If the token carries numeric parameters (chance/turns), apply the 2× rule to supported parameters and then apply normal caps (chance ≤ 100%, etc.).

Implementation note: do not attempt to reverse arbitrary tokens. Use a hard allowlist to avoid nonsensical or broken results.

##### 4) Arcana (skill clone; per-combat single use)

Arcana upgrades one granted skill modifier on the Unique:

- If the Unique grants a skill, Arcana creates a **single-use clone** of that exact skill:
  - does not consume a memory slot,
  - has AP and SP costs reduced by **1** each (floored at 0),
  - can be used **once per combat**; after use it becomes unavailable (greyed out) until the next combat begins.

If the upgrade is removed (respec or `AP_max` drop), the clone is no longer available.
