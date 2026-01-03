# Forging System

## What this system does

This system provides a sophisticated and hardcore RPG forging experience. 

The mod aims to increase playability and you can expect a big time investment through a fun, deep forging system. It gives players a true sense of growth with their gear as the game progresses; From common to legendary, every item can be upgraded, improved or used as a fuel resource, no more absolute "junk items". This creates a greater sense of achievement and allows players to forge and customize their dream unique items with both strategies and calculations, or with luck, just YOLO it out.

---

When you forge two items, the forged result:

- Always stays the same kind of item as the **first item you put in** (e.g. forge two swords together, you get a sword back).
- Rolls the item's **rarity** first (Common, Rare, Epic, etc.) depends on the parent ingredients, which decides how many Stats Modifiers the result can have (e.g. Blue Stats, Extra Properties, Granted Skills).
- Carries over and merges the item's **base values** (the white numbers you see, e.g. damage for weapons, armour for armour pieces), usually favouring the first ingredient (Note: Only **Same-Type weapon forge WILL** inherit the base damage, **Cross-Type weapon forge WILL NOT** inherit the base damage).
- For weapons of the same type, forging can also inherit **weapon boosts** (extra damage types or effects, e.g. fire damage, poison damage, piercing damage, etc.) (e.g. 2H Sword + 2H Sword, not 2H Sword + 2H Axe).
- Also for weapons, expect **Same-Type** weapon forge yields better chance to inherit Stats Modifiers than **Cross-Type** weapon forge (e.g. 2H Sword + 2H Sword can sometimes 2X the chance to get a good result than 2H Sword + 2H Axe).
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

- [2.1. Base values (definition)](#21-base-values-definition)
- [2.2. Output rules (level/type/rarity)](#22-output-rules-leveltyperarity)
- [2.3. Inputs and tuning parameters](#23-inputs-and-tuning-parameters)
- [2.4. Parent measurement (tooltip values)](#24-baseline-budget-cache-and-parent-measurement)
- [2.5. Core formulas (gain + upgrade + rarity dominance)](#25-normalisation-raw-to-percentile)
- [2.6. Merge algorithms (weapons and non-weapons)](#26-merge-algorithm-percentiles-to-output-base-values)
- [2.7. Worked examples](#27-worked-examples-base-values)
</details>

<details>
<summary><strong><a href="#3-weapon-boost-inheritance">3. Weapon Boost Inheritance</a></strong></summary>

- [3.1. Weapon boosts (definition)](#31-weapon-boosts-definition)
- [3.2. Inheritance rules](#32-weapon-boost-inheritance-rules)
- [3.3. Worked examples](#33-weapon-boost-worked-examples)
</details>

<details>
<summary><strong><a href="#4-stats-modifiers-inheritance">4. Stats Modifier Inheritance</a></strong></summary>

- [4.1. Introduction + design principles](#41-stats-modifiers-definition)
- [4.2. Selection rule (all modifiers)](#42-selection-rule-shared--pool--cap)
- [4.3. Merging rule (Blue Stats + ExtraProperties)](#43-merging-rule-how-numbers-are-merged)
- [4.4. Blue Stats](#44-blue-stats-channel)
  - [4.4.1. Blue Stats (definition)](#341-blue-stats-definition)
  - [4.4.2. Shared vs pool (Blue Stats)](#32-the-two-stats-lists)
  - [4.4.3. Worked examples (Blue Stats)](#36-worked-examples-stats-modifiers)
- [4.5. ExtraProperties](#45-extraproperties-inheritance)
  - [4.5.1. ExtraProperties (definition)](#41-extraproperties-definition)
  - [4.5.2. Shared vs pool tokens](#42-extraproperties-shared-vs-pool)
  - [4.5.3. Selection + internal cap](#43-extraproperties-selection--internal-cap)
  - [4.5.4. Slot competition + trimming](#44-extraproperties-slot-competition--trimming)
  - [4.5.5. Worked examples](#455-worked-examples)
- [4.6. Skills](#46-skills-inheritance)
  - [4.6.1. Granted skills (definition)](#41-granted-skills-definition)
  - [4.6.2. Skill cap by rarity](#42-skill-cap-by-rarity)
  - [4.6.3. Shared vs pool skills](#43-shared-vs-pool-skills)
  - [4.6.4. How skills are gained (gated fill)](#44-how-skills-are-gained-gated-fill)
  - [4.6.5. Overflow + replace (type-modified)](#45-overflow--replace-5)
  - [4.6.6. Scenario tables](#46-scenario-tables)
  - [4.6.7. Worked example (Divine)](#47-worked-example-divine)
</details>

<details>
<summary><strong><a href="#5-rune-slots-inheritance">5. Rune slots inheritance</a></strong></summary>
</details>

<details>
<summary><strong><a href="#6-implementation-reference">6. Implementation reference</a></strong></summary>
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

- **Base values** (base damage / armour / magic armour): determined by **item type + the white tooltip values**.
- **Blue stats** (stats modifiers): rollable modifiers (e.g. attributes, crit).
- **ExtraProperties**: rollable bundle (e.g. “chance to set status”, “Poison Immunity”, “Create Ice surface”, etc., counts as **1 slot** if present, regardless of how many internal lines it expands into).
- **Skills**: rollable granted skills (each skill consumes **1 slot**, unless protected by shared/skillbook rules).
- **Rune slots**: a separate channel (only when empty; rune effects are forbidden as ingredients).

High-level forge order:

1. Decide the output's **rarity** using the **[Rarity System](rarity_system.md)**.
2. Decide the output's **base values** (damage/armour) using **[Section 2](#2-base-values-inheritance)**.
3. Inherit **weapon boosts** (elemental damage, armour-piercing, vampiric, etc.) using **[Section 3](#3-weapon-boost-inheritance)** (weapons only).
4. Inherit **blue stats** using **[Section 4.4](#44-blue-stats-channel)**.
5. Inherit **ExtraProperties** using **[Section 4.5](#45-extraproperties-inheritance)**.
6. Inherit **skills** using **[Section 4.6](#46-skills-inheritance)**.
7. Inherit **rune slots** using **[Section 5](#5-rune-slots-inheritance)**.

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

This section defines how to merge **raw numeric power** (weapon damage, armour/magic armour from shields, other armour pieces, jewellery):

- Always outputs an item at the **player’s current level**.
- The computation itself uses only the parents’ **white tooltip values**.

Forging can improve the **white numbers** (base damage / base armour / base magic armour), but the base-value merge itself is constrained by:

- The output **item category/slot** (slot-locked eligibility and main-slot identity),
- Slot 1 dominance (rarity-based `w` for non-weapons, and for same-`WeaponType` weapons)
- The donor’s own tooltip values (the “spike” pushes **towards** the donor).

With the right strategy, forging is a way to **upgrade your favourite item over time**: good ingredients push it upwards more reliably, and with some luck you can sometimes get a **big jump**, or very rarely can gain an **exceptional result**.

Here are what you can expect:

- **If slot 1 is already very strong** (already close to the donor values you can realistically find), most forges will be **small changes** — maybe a point or two up or down, or staying about the same. This is normal: the model moves you **towards** the donor.
- **If slot 1 is weak and the donors are strong**, you’ll see **clear improvements** more often, with very rare **exceptional results** that can feel like a real jackpot.

### 2.1. Base values (definition)

<a id="21-base-values-definition"></a>
This base-value model is intentionally generic: it works for any item that has meaningful **base values** (raw template numbers, not stats modifiers/granted skills/runes).

- **Weapons**: base damage range.
- **Shields**: base armour, base magic armour, and base blocking.
- **Armour pieces** (helmets/chest/gloves/boots/pants): base armour and/or base magic armour.
- **Jewellery** (rings/amulets): base magic armour.
- **Slots that have no meaningful base values** (e.g. if both base armour and base magic armour are `0`): [Section 2](#2-base-values-inheritance) is a **no-op** for those numeric channels.

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

- **Output level**: always the forger’s level, `Level_out = Level_player`.
- **Output type**: always the item in the **main forge slot** (first slot).
- **Output rarity**: decided by the **[Rarity System](rarity_system.md)**.
- **Base values (all items)**: upgrades do **not** overcap. They only push the output **towards the donor** for that channel (and cross-type weapon forging does not change weapon damage).

### 2.3. Inputs and tuning parameters

<a id="23-inputs-and-tuning-parameters"></a>
<a id="23-parameters-tuning-knobs"></a>

This section defines the **inputs**, **notation**, and the **balance knobs** used by the base values merge. The actual algorithms are in [Section 2.6](#26-merge-algorithm-percentiles-to-output-base-values).

#### Inputs (per forge)

- **Output selectors**:
  - `Type_out`: always the item type in the **main forge slot** (slot 1).
  - `Level_out`: always the forger’s level, `Level_out = Level_player`.
  - `Rarity_out`: decided by the **[Rarity System](rarity_system.md)**.
- **Numeric channels (what “base values” means)**:
  - **Weapons**: one channel (white damage average).
  - **Shields**: three channels (physical armour, magic armour, and blocking).
  - **Armour pieces**: two channels (physical armour and magic armour).
  - **Jewellery**: typically one channel (magic armour).
- **No-op rule**: if an item has no meaningful base value for a channel (e.g. the tooltip value is `0`), do **not** apply the merge to that channel.

#### Balance knobs (tuning table)

These are the **balance knobs** (tuning defaults). The symbol dictionary used by the algorithm is in [Section 2.5](#25-normalisation-raw-to-percentile).
These are used by the tooltip-only base-value models in [Section 2](#2-base-values-inheritance).
| Parameter | Meaning | Default | Notes |
| :--- | :--- | :---: | :--- |
| `w` | Slot 1 dominance weight | Derived | Computed from the parents’ rarities (rarity dominance rule below). Slot 1 always remains the main parent. Used by non-weapons and by weapons when `WeaponType` matches. |
| `w0` | Base slot 1 dominance | **0.70** | Used when both parents have the same rarity. |
| `β` | Rarity dominance strength | **0.04** | Each rarity step in favour of slot 1 increases `w` by `β` (and decreases donor weight by the same amount). |
| `w_min`, `w_max` | Clamp range for `w` | **0.50..0.90** | Prevents the donor from becoming completely irrelevant, and prevents slot 1 from ever being “overridden”. |
| `upgradeCap` | Maximum upgrade chance | **50%** | Applies only when the donor is better (`B > A`). |
| `k` | Upgrade difficulty exponent (“higher is harder”) | **1** | Linear upgrade chance vs relative gain. |
| Upgrade quality roll | `u^2` | – | On upgrade success: pushes towards donor (`Out = Base + (B-Base)×u^2`). |
| Rounding policy | How to convert the final float into the displayed integer | Nearest (half-up) | Optional “player-favour” bias is to always round up. |

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
When `WeaponType` does not match, weapon base damage does not change ([Section 2.6](#26-merge-algorithm-percentiles-to-output-base-values)).

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

---

### 2.4. Parent measurement (tooltip values)

<a id="24-baseline-budget-cache-and-parent-measurement"></a>
<a id="24-measuring-base-values-no-runeboost-pollution"></a>

This section defines how to measure the parents’ base values from real items (white tooltip numbers).
Base values are derived directly from these measured tooltip values.

#### Parent measurement

Important constraints (already enforced elsewhere, but repeated here because they matter for correctness):

- **Socketed runes are rejected** as ingredients ([Section 1.1](#11-ingredient-eligibility)), so rune pollution does not enter the system.
- Try to measure from a stable state (not mid-combat / not under temporary buffs), so the tooltip reflects the item’s own base values.

Weapons (single channel; uses these directly):

- Read the weapon’s white damage range from the item tooltip: `D_min..D_max`
- Compute the midpoint: `avgDamage = (D_min + D_max) / 2`

Shields (three channels):

- Read `Armour`, `MagicArmour`, and `Blocking` from the item tooltip.
- Treat each channel independently throughout Sections 2.5–2.6.

Armour pieces (two channels):

- Read `Armour` and `MagicArmour` from the item tooltip.
- Treat each channel independently throughout Sections 2.5–2.6.

---

### 2.5. Core formulas (gain + upgrade + rarity dominance)

<a id="25-normalisation-raw-to-percentile"></a>
This section defines the shared pieces of maths used by the base-value models:

- **Base pull (`delta`)**: the donor can pull **up or down**:
  - `delta = (B - A)`
- **Rarity dominance (`w`)**: computes slot 1 dominance and donor influence:
  - donor pull strength is `t = (1 - w)`
- **Upgrade chance (donor better only):**
  - `gain = max(0, delta / max(A, 1))` (relative improvement available; 0 if donor is not better)
  - `P(upgrade) = clamp(upgradeCap × gain^k, 0, upgradeCap)`
- **Upgrade quality (if upgrade succeeds):**
  - roll `u ~ U(0,1)` and use `u^2` to push towards the donor (higher is harder)

---

### 2.6. Merge algorithms (weapons and non-weapons)

<a id="26-merge-algorithm-percentiles-to-output-base-values"></a>
<a id="26-cross-type-merging-w--conversionloss"></a>

This section contains two separate models:

- **Weapons (damage)**: tooltip-midpoint model (only if the parents have the exact same `WeaponType`; uses `w` for donor pull when eligible, otherwise damage is unchanged).
- **Non-weapons (armour/shields/jewellery)**: tooltip-only model (per channel; always uses `w` for slot 1 dominance / donor pull).

#### Weapon base damage merge (tooltip midpoints)

Let slot 1 be the “main” parent and slot 2 the “donor” parent.

Inputs:

- `A = avgDamage(slot1)` and `B = avgDamage(slot2)` where `avgDamage = (min+max)/2`
- `TypeMatch = (WeaponType_1 == WeaponType_2)`

Rules:

- If `TypeMatch=false`: `avg_out = A` (cross-type weapons do not change damage).
- Otherwise (`TypeMatch=true`):
  - Compute `w` from parent rarities ([Section 2.3](#23-inputs-and-tuning-parameters)), so donor pull strength is `t = (1 - w)`
  - `delta = (B - A)`
  - `avg_base = A + t × delta`
  - `gain = max(0, delta / max(A, 1))`
  - `P(upgrade) = clamp(upgradeCap × gain^k, 0, upgradeCap)`
  - On upgrade failure: `avg_out = avg_base`
  - On upgrade success: roll `u ~ U(0,1)` and compute `avg_out = avg_base + (B - avg_base) × u^2` (higher is harder)

Finally, round to the displayed integer midpoint and let the engine display min/max using the weapon's `Damage Range` rules.

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
- Fire Wand (slot 1) + Air Wand (slot 2) → Forged: Fire Wand (damage type follows slot 1)
- 2H Axe (Physical damage, slot 1) + Fire Staff (slot 2) → Forged: 2H Axe (Physical damage, damage type follows slot 1)

This maintains slot 1 identity consistency with the base damage merge and output type selection rules.

#### Non-weapons (tooltip-only; per channel)

Let slot 1 be the “main” parent and slot 2 the “donor” parent.

Inputs (per channel):

- `A = Base(slot1)` (e.g. physical armour)
- `B = Base(slot2)` (same channel)
- `w` from rarity dominance ([Section 2.3](#23-inputs-and-tuning-parameters)), so donor pull strength is `t = (1 - w)`

Rules:

- `delta = (B - A)`
- `Base = A + t × delta`
- `gain = max(0, delta / max(A, 1))`
- `P(upgrade) = clamp(upgradeCap × gain^k, 0, upgradeCap)`
- On upgrade failure: `Out = Base`
- On upgrade success: roll `u ~ U(0,1)` and compute `Out = Base + (B - Base) × u^2`

Apply the same steps independently to each channel (physical armour and magic armour).

### 2.7. Worked examples

<a id="27-worked-examples-base-values"></a>

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
| `k` | 1 | Upgrade difficulty exponent (“higher is harder”) |
| Upgrade quality roll | `u^2` | Pushes towards donor unless you get lucky |

##### Example 1: Same `WeaponType` (Crossbow), donor is better

Both are **Crossbow** ⇒ same-type (`TypeMatch=true`).

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
| `avg_base = A + t×delta` | `133.0 + 0.50×20.5 = 143.25` |
| `gain = max(0, delta/max(A,1))` | `20.5/133.0 = 0.1541` |
| `P(upgrade) = upgradeCap × gain^k` | `50% × 0.1541 = 7.71%` |

| Outcome                    |                                           `avg_out` | Notes                        |
| :------------------------- | --------------------------------------------------: | :--------------------------- |
| No upgrade                 |                                  `avg_out = 143.25` | deterministic baseline       |
| Upgrade example (`u=0.70`) | `avg_out = 143.25 + (153.5-143.25)×0.70^2 = 148.27` | exciting spike towards donor |

##### Example 2: Cross-type weapons do **not** change base damage (Spear + 2H Sword)

Different `WeaponType` ⇒ cross-type (`TypeMatch=false`).

| Item           | `WeaponType` | Tooltip damage | `avgDamage` |
| :------------- | :----------- | :------------: | ----------: |
| Slot 1 (main)  | Spear        |   `150–157`    | `A = 153.5` |
| Slot 2 (donor) | 2H Sword     |   `170–188`    | `B = 179.0` |

Rule:

- `avg_out = A = 153.5` (no upgrade roll)

#### Non-weapon examples (tooltip-only)

The non-weapon examples below use only the white tooltip values (per channel).

Shared settings (non-weapons):
| Name | Value | Meaning |
| :--- | :---: | :--- |
| `w0` | 0.70 | Base slot 1 dominance (same rarity) |
| `β` | 0.04 | Rarity dominance strength |
| `w_min`, `w_max` | 0.50..0.90 | Clamp range for `w` |
| `upgradeCap` | 50% | Maximum upgrade chance |
| `k` | 1 | Upgrade difficulty exponent (“higher is harder”) |
| Upgrade quality roll | `u^2` | Pushes towards donor unless you get lucky |

##### Example 4: Armour (two channels), same maths per channel (Strength chest + Intelligence chest)

Slot 1 (Strength chest): `713 Physical Armour`, `140 Magic Armour`  
Slot 2 (Intelligence chest): `140 Physical Armour`, `713 Magic Armour`

Assume the realised output rarity is **Divine** (slot 1 identity is preserved).

Both parents are Divine, so rarity dominance is:

- `w = clamp(0.70 + 0.04×(5-5), 0.50, 0.90) = 0.70`
- donor pull strength is `t = (1-w) = 0.30`

| Channel  | Slot 1 `A` | Slot 2 `B` | `delta = (B-A)` |        `Base = A + t×delta` | `gain = max(0, delta/max(A,1))` | `P(upgrade)` | No-upgrade output |
| :------- | ---------: | ---------: | --------------: | --------------------------: | ------------------------------: | :----------: | ----------------: |
| Physical |      `713` |      `140` |          `-573` | `713 + 0.30×(-573) = 541.1` |                             `0` |     `0%`     |             `541` |
| Magic    |      `140` |      `713` |           `573` |    `140 + 0.30×573 = 311.9` |               `573/140 = 4.093` | `50%` (cap)  |             `312` |

Interpretation:

- The output remains a Strength chest (slot 1 identity is preserved).
- Per-channel upgrades are possible, and a magic-channel "spike" can pull significantly towards the donor when the donor is much better.

##### Example 5: Shield (three channels), same maths per channel (Tower Shield + Kite Shield)

Slot 1 (Tower Shield): `713 Physical Armour`, `140 Magic Armour`, `15 Blocking`  
Slot 2 (Kite Shield): `140 Physical Armour`, `713 Magic Armour`, `10 Blocking`

Assume the realised output rarity is **Divine** (slot 1 identity is preserved).

Both parents are Divine, so rarity dominance is:

- `w = clamp(0.70 + 0.04×(5-5), 0.50, 0.90) = 0.70`
- donor pull strength is `t = (1-w) = 0.30`

| Channel  | Slot 1 `A` | Slot 2 `B` | `delta = (B-A)` |        `Base = A + t×delta` | `gain = max(0, delta/max(A,1))` | `P(upgrade)` | No-upgrade output |
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

---

## 3. Weapon Boost Inheritance

<a id="3-weapon-boost-inheritance"></a>

This section defines how **weapon boosts** (elemental damage, armour-piercing, etc.) are inherited when forging **non-unique weapons**.

**Note:** This documentation focuses on **non-unique items**. Unique weapons with special boost types (Vampiric, MagicArmourRefill, Chill) are treated as special cases and documented separately (see [Section 3.1.1](#311-special-boost-types-unique-weapons)).

**Important:** Temporary weapon-enchant effects from skills/consumables (e.g. Venom Coating, Elemental Arrowheads, Fire Brand, etc.) are implemented as **statuses** that grant a conditional `BonusWeapon` while active, not as permanent weapon `Boosts`. These temporary effects must not be present on forging ingredients (see [Section 1.1](#11-ingredient-eligibility)).

### 3.1. Weapon boosts (definition)

<a id="31-weapon-boosts-definition"></a>

In Divinity: Original Sin 2, weapons can have **additional damage or effects** beyond their base damage. These appear as **weapon boost properties** referenced by the weapon's `Boosts` field.

**How it works in the game:**

- Weapon boosts are **not base values** (they don't appear in the white damage range calculation).
- Weapon boosts are **not blue stat modifiers** (they're not part of the rollable modifier system).
- Instead, weapon boosts are **discrete boost entries** that either:
  - Add a **second damage line** (e.g., "32–39 Poison" alongside "311–381 Fire"), or
  - Provide **special effects** (e.g., vampiric healing, magic armour refill).

**Crafting note (vanilla):**

- Some boosts are applied via **crafting combos** (`BoostType="ItemCombo"`) rather than being rolled during loot generation.
- Example: a poison vial can apply `Boost_Weapon_Crafting_Damage_Poison` → `_Boost_Weapon_Crafting_Damage_Poison` (10% `DamageFromBase`, Poison damage type, plus a small `POISONED` on-hit token).
- If the boost damage type **differs** from the weapon’s base `Damage Type`, it shows as a **second damage line**.
- If the boost damage type **matches** the weapon’s base `Damage Type` (e.g., Poison staff + Poison boost), the result can appear “merged” into the base damage line in the tooltip (it is still implemented as a boost entry).

**Important exclusion:**

- `_Boost_Weapon_Damage_Bonus` (and its tiered variants) uses the `DamageBoost` field, which **modifies base physical damage** directly.
- This boost is **already reflected in the white tooltip damage range** used by [Section 2](#2-base-values-inheritance) for base value inheritance.
- Therefore, `_Boost_Weapon_Damage_Bonus` is **not inherited via this section** ([Section 3](#3-weapon-boost-inheritance)) to avoid double-counting. It is implicitly handled through the base damage merge in [Section 2](#2-base-values-inheritance).

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

**Note:** `_Boost_Weapon_Damage_Bonus` (and its tiered variants) is **excluded** from this inheritance system. It uses the `DamageBoost` field, which modifies base physical damage and is already reflected in the white tooltip damage range. It is handled implicitly through the base damage merge in [Section 2](#2-base-values-inheritance).

**Tier naming convention:**

- Boost names ending in `_Small` → **Small tier** (if available for that boost kind)
- Boost names ending in `_Medium` → **Medium tier**
- Boost names ending in `_Large` → **Large tier**
- Boost names with **no tier suffix** → **Untiered tier** (a distinct tier, not equivalent to Medium)

**Tier mapping for merging:**

Each boost kind has its own tier system with different tier availability:

Non-unique weapons:
- **4-tier boosts** (elemental, ArmourPiercing): Small (tier 0) < Untiered (tier 1) < Medium (tier 2) < Large (tier 3)

Unique weapons:
- **3-tier boosts** (Vampiric, MagicArmourRefill): Untiered (tier 0) < Medium (tier 1) < Large (tier 2)
- **1-tier boosts** (Chill): Untiered (tier 0) only

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

- Roll `bias(k) ~ U(0, 0.7)` (seeded).

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

- `bias(Water) = +0.70`
- `bias(Air) = +0.20`
- `bias(Poison) = +0.60`

Inputs:

- Weapon type: Staff (cap = 1)
- Slot 1 `Boosts` (main): Air `_Large` + Water `_Medium`
- Slot 2 `Boosts` (secondary): Poison `_Small` + Water (untiered)

```
Weapon type: Staff (cap=1)
Parent A (main):  Air _Large, Water _Medium
Parent B (sec):   Poison _Small, Water (untiered)
---------------------------------------------
Tier scores:
  Water:  s_main=3, s_sec=2
  Air:    s_main=4, s_sec=0
  Poison: s_main=0, s_sec=1

Scores (after bias):
  Water:  score = 0.6*3 + 0.4*2 + 0.70 = 3.30
  Air:    score = 0.6*4 + 0.4*0 + 0.20 = 2.60
  Poison: score = 0.6*0 + 0.4*1 + 0.60 = 1.00

Pick top cap=1 kind with score>=1:
  Water (3.30)
```

---

## 4. Stats Modifier Inheritance

<a id="4-stats-modifiers-inheritance"></a>
<a id="3-stats-modifiers-inheritance"></a>

This section defines how **stats modifiers** are inherited when you forge.

Stats modifiers are split into three dedicated channels, each with its own unshared pool:

- **Blue Stats**: numeric "blue text" boosts like Strength, crit, resistances, etc.
- **ExtraProperties**: semicolon-separated tokens like proc chances, statuses, immunities, surfaces (counts as **1 slot** overall if present)
- **Skills**: rollable granted skills like Shout_Whirlwind, Projectile_BouncingShield, Target_Restoration (each counts as **1 slot** overall)

The forged item applies one shared cap across these channels:

- `OverallCap[Rarity_out, ItemType_out]` (default+learned per save, tracked per (rarity, item type) pair; see [`rarity_system.md`](rarity_system.md#221-overall-rollable-slots-cap))

### 4.1. Introduction + design principles

<a id="41-stats-modifiers-definition"></a>
<a id="31-stats-modifiers-definition"></a>

Design principles:

- **Shared-first**: shared modifiers are stable and predictable.
- **Pool risk/reward**: non-shared modifiers go into that channel’s pool and are harder to keep.
- **Consistent algorithms**: merging and selection are defined once up front; each channel applies them with its own identity keys.

The universal rules are defined next:

- **Selection rule + overall cap trimming** ([Section 4.2](#42-selection-rule-shared--pool--cap))
- **Merging rule** ([Section 4.3](#43-merging-rule-how-numbers-are-merged))

### 4.2. Selection rule (all modifiers)

<a id="42-selection-rule-shared--pool--cap"></a>
<a id="34-selection-rule-shared--pool--cap"></a>

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

- Blue stats: `Sb`, `Pb_size`, `Pb`, `Fb`
- ExtraProperties (internal tokens): `Sp`, `Pp_size`, `Pp`, `Fp_tokens`
- Skills: `Ss`, `Ps_size`, `Ps`, `Fs`

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

**Default (cross-type, applies to all items):**

| Pool size | Tier           | First roll chances (Bad / Neutral / Good) | Chain chance (Down / Up; stop probabilities in parentheses) |
| :-------- | :------------- | :---------------------------------------- | :---------------------------------------------------------- |
| **1**     | Tier 1 (Safe)  | `0% / 50% / 50%`                          | None                                                        |
| **2–4**   | Tier 2 (Early) | `14% / 60% / 26%`                         | `0% (stop 100%) / 25% (stop 75%)`                            |
| **5–7**   | Tier 3 (Mid)   | `30% / 52% / 18%`                         | `30% (stop 70%) / 25% (stop 75%)`                           |
| **8+**    | Tier 4 (Risky) | `33% / 55% / 12%`                         | `40% (stop 60%) / 25% (stop 75%)`                           |

**Weapons only (same-type comparison):**

For weapons with the same `WeaponType` (e.g., two swords), same-type probabilities are derived by doubling the "good" branch and renormalising. Chain chances remain the same.

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

For **weapons**, we treat **exact same `WeaponType`** as "same-type". For other item categories, type mismatches are not allowed by eligibility rules, so they always behave like "same-type".

Let:

- `TypeMatch = (WeaponType_1 == WeaponType_2)` for weapons
- `TypeMatch = true` for non-weapons

The luck adjustment `A` is sampled from a tier-specific distribution:

- **Cross-type (default)** distribution if `TypeMatch=false`
- **Same-type** distribution if `TypeMatch=true`

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
- ExtraProperties slot is protected if `Sp ≥ 1` (shared ExtraProperties exists).

**Trimming rule (slot-weighted):**

- After protected/shared slots are counted, the remaining slots are allocated by rolling between _pending pool-picked slots_.
- Weight per channel is:
  - Blue stats: `Pb` (number of pool-picked blue stats)
  - Skills: `Ps` (number of pool-picked skills, if any)
  - ExtraProperties slot: `1` if the EP slot is pending as a pool slot (i.e. `Sp = 0` and EP exists), else `0`

If a channel wins a slot:

- **Blue stats**: pick one of the remaining pool-picked blue stats uniformly.
- **Skills**: pick one of the remaining pool-picked skills uniformly.
- **ExtraProperties**: keep the EP slot (then apply [Section 4.5.3](#43-extraproperties-selection--internal-cap) internal token selection).

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

- Shared Blue Stats: `+1 Finesse`, `+0.5m Movement` → `Sb = 2`
- Pool Blue Stats candidates: `+10% Fire Resistance`, `+1 Sneaking`, `+2 Initiative`, `+10% Air Resistance` → `Pb_size = 4`

Now calculate how many pool stats you keep:

- Pool size `Pb_size = 4` → **Tier 2** (pool size 2–4)
- Expected baseline: `E = floor((Pb_size + 1) / 3) = floor(5 / 3) = 1`
- First roll: Good roll → `A = +1`
- Chain up: Chain succeeds → `A = +2` (final luck adjustment)
- Modifiers from pool (kept): `Pb = clamp(E_eff + A, 0, Pb_size) = clamp(1 + 2, 0, 4) = 3` (assuming no dampener applies in this example)
- Planned forged blue modifiers (before overall trimming): `Fb = Sb + Pb = 2 + 3 = 5`

Finally apply the overall rollable-slot cap:

- Assume the rarity system gives the new item **Legendary Boots** → `OverallCap[Legendary, Boots] = 4` (default, or learned if higher)
- Final (blue only, no other channels in this example): `Final = min(Fb, OverallCap) = min(5, 4) = 4`

So you end up with:

- The 2 shared blue stats (always)
- Plus 2 of the pool blue stats (3 were kept from the pool, but 1 was trimmed by the overall cap)

---

#### 3.2.1. Safe vs YOLO forging

<a id="35-safe-vs-yolo-forging"></a>

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

Parent B: Divine Warhammer
 - +3 Strength          (shared)
 - +2 Warfare           (shared)
 - +15% Critical Chance (shared)
 - +20% Poison Resistance (pool)
 - ExtraProperties: MUTED,10,1  (pool)

─────────────────────────────────────────
Shared Modifiers:
 - Shared Blue Stats: +3 Strength, +2 Warfare, +15% Critical Chance → Sb = 3
Pool Modifiers:
 - Pool Blue Stats: +20% Fire Resistance, +20% Poison Resistance → Pb_size = 2
 - Pool Skills: Shout_Whirlwind → Ps_size = 1
 - Pool ExtraProperties: MUTED,10,1 → Sp = 1
```

Inputs for this example:

- `OverallCap[Divine, Warhammer] = 5` (default, or learned if higher)
- Shared totals (protected): `S_total = Sb + Ss + Sp = 3 + 0 + 0 = 3`

This is the perfect example for **Safe Forging**:

- With **3 shared blue stats**, you have a stable core.
- Because the overall cap is **5**, the result must allocate the remaining **2 slots** between:
  - pool-picked blue stats (`Pb`)
  - pool-picked skills (`Ps`)
  - the pending ExtraProperties slot (weight 1 if kept)

Concrete outcome intuition:

- Suppose the channel selections produce:
  - Blue stats: `Pb = 1` (kept 1 from `Pb_size = 2`)
  - Skills: `Ps = 1` (kept 1 from `Ps_size = 1`)
  - EP slot: pending
  - Then `F_total = Sb + Pb + Ss + Ps + EPslot = 3 + 1 + 0 + 1 + 1 = 6` ⇒ over cap by 1.
- Using the **slot-weighted** overall trimming rule ([Step 5 of Section 4.2](#45-apply-overall-modifier-cap)):
  - weight(Blue) = `Pb = 1`, weight(Skills) = `Ps = 1`, weight(EP) = `1`
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
 - Pool Blue Stats: +3 Strength, +2 Warfare, +2 Two-Handed, +15% Accuracy, +15% Critical Chance, +20% Fire Resistance, +10% Air Resistance, +1000 Health → Pb_size = 8
 - Pool Skills: Shout_Whirlwind → Ps_size = 1
 - Pool ExtraProperties: MUTED,10,1 → Sp = 1
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

$$lo = \min(a,b)\times 0.85$$
$$hi = \max(a,b)\times 1.15$$

##### 4. Final merged value:

$$value = clamp(m \times r,\ lo,\ hi)$$

Then format the number back into a stats line using the stats' rounding rules.

#### Rounding rules

- **Integer stats** (Attributes, skill levels): round to the nearest integer.
- **Percent stats** (Critical Chance, Accuracy, Resistances, "X% chance to set Y"): round to the nearest integer percent.

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

---

### 4.4. Blue Stats

<a id="44-blue-stats-channel"></a>
<a id="34-blue-stats-channel"></a>

#### 4.4.1. Blue Stats (definition)

<a id="341-blue-stats-definition"></a>

Blue Stats are rollable numeric boosts (blue text stats) that appear on items based on their rarity. These include:

- Attributes (Strength, Finesse, Intelligence, etc.)
- Combat abilities (Warfare, Scoundrel, etc.)
- Resistances (Fire, Poison, etc.)
- Other numeric modifiers (Critical Chance, Accuracy, Initiative, Movement, etc.)

#### 4.4.2. Shared vs pool (Blue Stats)

<a id="32-the-two-stats-lists"></a>

- **Shared Blue Stats (Sb)**: blue stats lines on **both** parents (guaranteed).
- **Pool Blue Stats size (Pb_size)**: blue stats lines that are **not shared** (unique to either parent). This is the combined pool candidates list from both parents.

Key values:

- `Sb`: Shared Blue Stats (count)
- `Pb_size`: pool size for Blue Stats (candidate count)
- `Pb`: modifiers from pool (kept/picked count) for Blue Stats
- `Fb`: forged blue modifiers before overall trimming (`Fb = Sb + Pb`)

#### 4.4.3. Worked examples (Blue Stats)

<a id="36-worked-examples-stats-modifiers"></a>

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

- `Sb = 1` (Shared Blue Stats)
- `Pb_size = 1` (Pool Blue Stats size)
- `E = 0` (Expected baseline, special case for `P_size = 1`)

Parameters used (Tier 1):

- Cross-type: `p_bad=0%`, `p_neutral=50%`, `p_good=50%`, `d=0.00`, `u=0.00` (no chain)
- Same-type: `p_bad=0%`, `p_neutral=50%`, `p_good=50%`, `d=0.00`, `u=0.00` (no chain)

| Luck adjustment<br>(A) | Modifiers from pool<br>(Pb) | Forged item modifiers<br>(Fb) | Chance (math)                                                       | Cross-type (default) | Same-type |
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

- `Sb = 1` (Shared Blue Stats)
- `Pb_size = 3` (Pool Blue Stats size)
- `E = floor((Pb_size + 1) / 3) = floor(4 / 3) = 1` (Expected baseline)

The blue-stats selection step yields between **1** and **4** blue modifiers (**1** shared + **0–3** from the pool).

Parameters used (Tier 2):

- Cross-type: `p_bad=14%`, `p_neutral=60%`, `p_good=26%`, `d=0.00`, `u=0.25`
- Same-type: `p_bad=11.11%`, `p_neutral=47.62%`, `p_good=41.27%`, `d=0.00`, `u=0.25`

| Luck adjustment<br>(A) | Modifiers from pool<br>(Pb) | Forged item modifiers<br>(Fb) | Chance (math)                                                                                                | Cross-type (default) | Same-type |
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

- `Sb = 4` (Shared Blue Stats)
- `Pb_size = 2` (Pool Blue Stats size)
- `E = floor((Pb_size + 1) / 3) = floor(3 / 3) = 1` (Expected baseline)
- `Sb = 4 ≥ OverallCap - 1 = 4` → **Cap-proximity dampener applies**

The blue-stats selection step yields between **4** and **6** blue modifiers (**4** shared + **0–2** from the pool).

Parameters used (Tier 2):

- Cross-type: `p_bad=14%`, `p_neutral=60%`, `p_good=26%`, `d=0.00`, `u=0.25`
- Same-type: `p_bad=11.11%`, `p_neutral=47.62%`, `p_good=41.27%`, `d=0.00`, `u=0.25`

**Near-cap summary tables (clear):**

When `Sb = 4` (cap-1), you are deciding whether you can fill the **last slot** from the pool.

**Tier 1 (Pool size = 1) variant:** `Sb = 4`, `Pb_size = 1`, `E = 0` (no chains)

| Result bucket | Modifiers from pool<br>(Pb) | Forged item modifiers<br>(Fb) | Chance (math) | Cross-type | Same-type |
| :------------ | :-------------------------: | :---------------------------: | :------------ | ---------: | --------: |
| Below cap | 0 | 4 | Cross: `p_neutral = 50%`<br>Same: `p_neutral = 33.33%` | 50.00% | 33.33% |
| `5+` | 1 | 5+ | Cross: `p_good = 50%`<br>Same: `p_good = 66.67%` | 50.00% | 66.67% |

**This Tier 2 (Pool size = 2) case with dampener:** `Sb = 4`, `Pb_size = 2`, `E = 1`

Cap-proximity dampener (applies because `Sb ≥ OverallCap - 1`):

- Cross-type: dampener triggers with probability `q_cross = 0.45`
- Same-type: dampener triggers with probability `q_same = 0.30`

| Result bucket | Modifiers from pool<br>(Pb) | Forged item modifiers<br>(Fb) | Chance (math) | Cross-type | Same-type |
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

- `Sb = 2` (Shared Blue Stats)
- `Pb_size = 4` (Pool Blue Stats size)
- `E = floor((Pb_size + 1) / 3) = floor(5 / 3) = 1` (Expected baseline)

The blue-stats selection step yields between **2** and **6** blue modifiers (**2** shared + **0–4** from the pool).

Parameters used (Tier 2):

- Cross-type: `p_bad=14%`, `p_neutral=60%`, `p_good=26%`, `d=0.00`, `u=0.25`
- Same-type: `p_bad=11.11%`, `p_neutral=47.62%`, `p_good=41.27%`, `d=0.00`, `u=0.25`

| Luck adjustment<br>(A) | Modifiers from pool<br>(Pb) | Forged item modifiers<br>(Fb) | Chance (math)                                                                                         | Cross-type (default) | Same-type |
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

- `Sb = 2` (Shared Blue Stats)
- `Pb_size = 5` (Pool Blue Stats size)
- `E = floor((Pb_size + 1) / 3) = floor(6 / 3) = 2` (Expected baseline)

The blue-stats selection step yields between **2** and **7** blue modifiers (**2** shared + **0–5** from the pool).

Parameters used (Tier 3):

- Cross-type: `p_bad=30%`, `p_neutral=52%`, `p_good=18%`, `d=0.30`, `u=0.25`
- Same-type: `p_bad=25.42%`, `p_neutral=44.07%`, `p_good=30.51%`, `d=0.30`, `u=0.25`

| Luck adjustment<br>(A) | Modifiers from pool<br>(Pb) | Forged item modifiers<br>(Fb) | Chance (math)                                                                                     | Cross-type (default) | Same-type |
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

- `Sb = 1` (Shared Blue Stats)
- `Pb_size = 7` (Pool Blue Stats size)
- `E = floor((Pb_size + 1) / 3) = floor(8 / 3) = 2` (Expected baseline)

The blue-stats selection step yields between **1** and **8** blue modifiers (**1** shared + **0–7** from the pool).

Parameters used (Tier 3):

- Cross-type: `p_bad=30%`, `p_neutral=52%`, `p_good=18%`, `d=0.30`, `u=0.25`
- Same-type: `p_bad=25.42%`, `p_neutral=44.07%`, `p_good=30.51%`, `d=0.30`, `u=0.25`

| Luck adjustment<br>(A) | Modifiers from pool<br>(Pb) | Forged item modifiers<br>(Fb) | Chance (math)                                                                                     | Cross-type (default) | Same-type |
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

- `Sb = 0` (Shared Blue Stats)
- `Pb_size = 8` (Pool Blue Stats size)
- `E = floor((Pb_size + 1) / 3) = floor(9 / 3) = 3` (Expected baseline)

The blue-stats selection step yields between **0** and **8** blue modifiers (**0** shared + **0–8** from the pool).

  - This is “riskier crafting” in practice: fewer shared stats means more “unknown” stats in the pool.

Parameters used (Tier 4):

- Cross-type: `p_bad=33%`, `p_neutral=55%`, `p_good=12%`, `d=0.40`, `u=0.25`
- Same-type: `p_bad=29.46%`, `p_neutral=49.11%`, `p_good=21.43%`, `d=0.40`, `u=0.25`

| Luck adjustment<br>(A) | Modifiers from pool<br>(Pb) | Forged item modifiers<br>(Fb) | Chance (math)                                                                                                        | Cross-type (default) | Same-type |
| :--------------------: | :-------------------------: | :---------------------------: | :------------------------------------------------------------------------------------------------------------------- | -------------------: | --------: |
|           -3           |              0              |               0               | Cross: `p_bad × d^2 = 33% × 0.40^2 = 5.28%` (cap bucket)<br>Same: `p_bad × d^2 = 29.46% × 0.40^2 = 4.71%`            |                5.28% |     4.71% |
|           -2           |              1              |               1               | Cross: `p_bad × d × (1-d) = 33% × 0.40 × 0.60 = 7.92%`<br>Same: `p_bad × 0.40 × 0.60 = 29.46% × 0.40 × 0.60 = 7.07%` |                7.92% |     7.07% |
|           -1           |              2              |               2               | Cross: `p_bad × (1-d) = 33% × 0.60 = 19.80%`<br>Same: `p_bad × 0.60 = 29.46% × 0.60 = 17.68%`                        |               19.80% |    17.68% |
|           0            |              3              |               3               | Cross: `p_neutral = 55%`<br>Same: `p_neutral = 49.11%`                                                               |               55.00% |    49.11% |
|           +1           |              4              |               4               | Cross: `p_good × (1-u) = 12% × 0.75 = 9.00%`<br>Same: `p_good × 0.75 = 21.43% × 0.75 = 16.07%`                       |                9.00% |    16.07% |
|          +2+           |             5+              |              5+               | Cross: `p_good × u = 12% × 0.25 = 3.00%`<br>Same: `p_good × u = 21.43% × 0.25 = 5.36%`                               |                3.00% |     5.36% |

---

### 4.5. ExtraProperties

<a id="45-extraproperties-inheritance"></a>
<a id="45-extraproperties-channel"></a>
<a id="35-extraproperties-channel"></a>
<a id="4-extraproperties-inheritance"></a>

This section defines how **ExtraProperties** are inherited when you forge.

ExtraProperties is treated as its own channel:

- ExtraProperties consumes **1** overall rollable slot if present (regardless of how many internal effects/tooltip lines it expands into).
- The **internal content** (tokens) is merged/selected separately, with an internal cap based on the parents.

#### 4.5.1. ExtraProperties (definition)

<a id="41-extraproperties-definition"></a>

ExtraProperties is a semicolon-separated list of effects stored on the item. These include:

- Status chance effects ("X% chance to set Y")
- Status immunities (e.g. "Poison Immunity")
- Surface effects (e.g. "Create Ice surface")
- Other special effects (proc chances, statuses, etc.)

Important: the tooltip may show multiple lines, but for the overall cap, ExtraProperties is counted as **one slot**.

#### 4.5.2. Shared vs pool tokens

<a id="42-extraproperties-shared-vs-pool"></a>

Parse each parent’s ExtraProperties string into ordered tokens:

- Split on `;`
- Trim whitespace
- Normalise into a canonical key for identity comparisons (e.g. strip whitespace, normalise case where safe, and isolate the “effect type” portion).

Then compute:

- **Shared ExtraProperties (Sp)**: tokens that match by canonical key on both parents (guaranteed to be kept, with parameter merge if applicable).
- **Pool ExtraProperties size (Pp_size)**: tokens present on only one parent (pool candidates).

#### 4.5.3. Selection + internal cap (max of parent lines, with same-count bonus)

<a id="43-extraproperties-selection--internal-cap"></a>

Let:

- `A = tokenCount(parentA)`
- `B = tokenCount(parentB)`
- `InternalCap = max(A, B)` (base cap)

**Same-count bonus rule:**

If both parents have the same number of EP tokens (`A == B`) AND the forged item inherits the ExtraProperties slot (either through shared EP `Sp ≥ 1` or through pool selection), the internal cap gets a **+1 bonus**:

- `InternalCap = A + 1` (allows inheriting all unique tokens from both parents)

**When the bonus applies:**

- Both parents have the same token count (`A == B`)
- The forged item inherits the ExtraProperties slot (protected by `Sp ≥ 1`, or selected from pool)

**When the bonus does NOT apply:**

- Parents have different token counts (`A != B`) → use `InternalCap = max(A, B)`
- The forged item does not inherit the ExtraProperties slot

Build the output token list:

1. Keep all shared tokens (merge parameters if the same token differs in numbers, using the same "merge then clamp" philosophy as blue stats).
2. Determine `InternalCap`:
   - If `A == B` and EP slot is inherited: `InternalCap = A + 1`
   - Otherwise: `InternalCap = max(A, B)`
3. Roll additional tokens from the pool using the selection rule in [Section 4.2](#42-selection-rule-shared--pool--cap):
   - `P_size = Pp_size`, `P = Pp`
4. Clamp the final token list to `InternalCap`.

#### 4.5.4. Slot competition + trimming

<a id="44-extraproperties-slot-competition--trimming"></a>

ExtraProperties occupies one **slot** in the overall rollable cap.

Rule:

- If `Sp ≥ 1`, the ExtraProperties slot is **guaranteed** to be present (it consumes 1 slot and is protected from overall-cap trimming).
- Otherwise, the ExtraProperties slot is a **pool slot**. If the forge result is over the overall cap, this slot competes under the universal overall-cap trimming rule in [Step 5 of Section 4.2](#45-apply-overall-modifier-cap) (slot-weighted).

#### 4.5.5. Worked examples

<a id="455-worked-examples"></a>

**Example 1: Same count with bonus**

```
Parent A: "Poison Immunity; Set Silence for 2 turns 10% chance" (2 tokens)
Parent B: "Poison Immunity; Set Warm Always" (2 tokens)
─────────────────────────────────────────
Shared: "Poison Immunity" → `Sp = 1` (1 token, EP slot protected)
Pool: "Set Silence for 2 turns 10% chance", "Set Warm Always" → `Pp_size = 2`
─────────────────────────────────────────
InternalCap determination:
- `A == B == 2` (same count)
- EP slot is inherited (protected by `Sp ≥ 1`)
- `InternalCap = 2 + 1 = 3` (bonus applies)
─────────────────────────────────────────
Result: All 3 tokens possible:
- "Poison Immunity" (shared, guaranteed)
- "Set Silence for 2 turns 10% chance" (from pool, if selected)
- "Set Warm Always" (from pool, if selected)
```

**Example 2: Different counts (no bonus)**

```
Parent A: "Poison Immunity; Set Silence for 2 turns 10% chance" (2 tokens)
Parent B: "Set Warm Always" (1 token)
─────────────────────────────────────────
Shared: (none) → `Sp = 0`
Pool: "Poison Immunity", "Set Silence for 2 turns 10% chance", "Set Warm Always" → `Pp_size = 3`
InternalCap: Since `A != B`, use `max(2, 1) = 2` (no bonus)
─────────────────────────────────────────
Result: Capped at 2 tokens maximum
```

---

### 4.6. Skills

<a id="46-skills-inheritance"></a>
<a id="46-skills-channel"></a>
<a id="36-skills-channel"></a>
<a id="4-skills-inheritance"></a>
This section defines how **granted skills** are inherited when you forge.

- Granted skills are a separate channel from normal **blue stats**.
- Each rollable granted skill consumes **1** overall rollable slot (shared cap with blue stats + ExtraProperties).
- Skills are rollable; unless preserved by the **skillbook lock** or shared between both parents, they can be lost when applying the overall cap (equal drop chance among pool slots).
- Skills also have a per-save learned **skill count cap** (`SkillCap[r]`) defined in [`rarity_system.md`](rarity_system.md#222-skill-cap-vnext).

Here are what you can expect:

- You can sometimes carry a skill across, or gain one from the ingredient pool, but you will always be limited by the rarity’s **skill cap** (default is 1 for all non-Unique rarities).
- Even if a skill is gained by the skill rules, it can still be dropped later if the final item is over the **overall rollable-slot cap** and the skill is not protected (no skillbook lock; not shared).

#### 4.6.1. Granted skills (definition)

<a id="41-granted-skills-definition"></a>

- **Granted skill (rollable)**: any rollable boost/stats line that grants entries via a `Skills` field in its boost definition.
  - Weapon example: `_Boost_Weapon_Skill_Whirlwind` → `Shout_Whirlwind`
  - Shield example: `_Boost_Shield_Skill_BouncingShield` → `Projectile_BouncingShield`
  - Armour/jewellery example: `_Boost_Armor_Gloves_Skill_Restoration` → `Target_Restoration` (defined in `Armor.stats`)
- **Not a granted skill (base)**: a `Skills` entry baked into the base weapon stats entry (not a rolled boost), e.g. staff base skills like `Projectile_StaffOfMagus` (**base-only; never enters `poolSkills`**).

#### Vanilla scope note

- Only treat **`BoostType="Legendary"`** skill boosts as “vanilla rarity-roll skills”.
- Ignore **`BoostType="ItemCombo"`** skill boosts for vanilla-aligned behaviour.

#### Item-type constraints (hard rule for skill inheritance)

- **Weapon can only forge with weapon**, and **shield can only forge with shield**, etc.
- Therefore:
  - A **weapon** must only ever roll/inherit **weapon skill boosts**.
  - A **shield** must only ever roll/inherit **shield skill boosts**.
  - A **chest** must only ever roll/inherit **chest skill boosts**.
  - A **jewellery** must only ever roll/inherit **jewellery skill boosts**.
- If you ever encounter “mixed” skills in runtime data, treat that as invalid input (or ignore the mismatched skill boosts).

#### 4.6.2. Skill cap by rarity

<a id="42-skill-cap-by-rarity"></a>

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

<a id="421-skillbook-lock"></a>

If the player inserts a skillbook into the dedicated forge UI slot, the forge must validate it against the parent item’s granted skill(s):

- Match by **exact skill ID** (e.g. `Target_ShockingTouch`, `Shout_Whirlwind`), not by display name.
- If the skillbook does not match any skill granted by the main-slot item (parent A), block forging with:
  - “No matched skills found on the item!”

If both parents have matching skillbooks:

- The main-slot item’s (parent A) skill is the guaranteed inherited one.

#### 4.6.3. Shared vs pool skills

<a id="43-shared-vs-pool-skills"></a>

Split granted skills into two lists:

- **Shared Skills (Ss)**: granted skills present on **both** parents (kept unless we must trim due to cap overflow).
- **Pool Skills size (Ps_size)**: granted skills present on **only one** parent (pool candidates).

#### Skill identity (dedupe key)

Use the **skill ID** as the identity key (e.g. `Shout_Whirlwind`, `Projectile_BouncingShield`), not the boost name.

#### 4.6.4. How skills are gained (gated fill)

<a id="44-how-skills-are-gained-gated-fill"></a>

Skills are **more precious than stats**, so the skill channel does **not** use the stat-style “keep half the pool” baseline.

Instead, skills use a **cap + gated fill** model:

- **Shared skills are protected** (kept first).
- You only try to gain skills for **free skill slots** (up to the rarity skill cap).
- The chance to gain a skill **increases with pool size** (`P_remaining`).

#### Key values (skills)

- **Ss**: number of shared rollable skills (present on both parents).
- **Ps_size**: number of pool rollable skills (present on only one parent).
- **SkillCap**: from [Section 4.6.2](#42-skill-cap-by-rarity).
- **FreeSlots**: `max(0, SkillCap - min(Ss, SkillCap))`

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

#### 4.6.5. Overflow + replace (type-modified)

<a id="45-overflow--replace-5"></a>

All randomness in this subsection is **host-authoritative** and driven by `forgeSeed` (see [Section 1.3](#13-deterministic-randomness-seed--multiplayer)).

1. Build `sharedSkills` (deduped) and `poolSkills` (deduped).
2. Keep shared first:
   - `finalSkills = sharedSkills` (trim down to `SkillCap` only if shared exceeds cap).
3. Compute `freeSlots = SkillCap - len(finalSkills)`.
4. Fill free slots with gated gain rolls:
   - For each free slot (at most `freeSlots` attempts):
     - Let `P_remaining = len(poolSkills)`
     - Roll a random number; success chance is `p_attempt` ([Section 4.6.4](#44-how-skills-are-gained-gated-fill)).
     - If success: pick 1 random skill from `poolSkills`, add to `finalSkills`, remove it from `poolSkills`, and decrement `freeSlots`.
     - If failure: do nothing for that slot (skills are precious; you do not retry the same slot).
5. Optional “replace” roll (type-modified):
   - Cross-type (default): **10%**
   - Same-type (`TypeMatch=true`): **5%**
   - If `poolSkills` is not empty and `finalSkills` is not empty:
     - With `replaceChance`, replace 1 random skill in `finalSkills` with 1 random skill from remaining `poolSkills`.

#### Example (realistic default cap = 1)

Assume the forged output rarity is **Divine**, so `SkillCap[Divine] = 1` (default).

Parent skills:

- Parent A: `{Shout_Whirlwind}`
- Parent B: `{Projectile_SkyShot}`

With the optional replace roll, one possible final skills outcome is:

- `{Shout_Whirlwind}` _(gain succeeded and selected this skill; cap is 1)_

Interpretation:

- With default `SkillCap = 1`, only one skill can ever be kept.
- If the gain roll succeeds ([Section 4.6.4](#44-how-skills-are-gained-gated-fill)), one of the pool skills is selected.
- If the gain roll succeeds and there is still another pool skill remaining, the optional replace roll can swap which single skill you end up with.

#### 4.6.6. Scenario tables

<a id="46-scenario-tables"></a>

These tables show the probability of ending with **0 / 1** rollable granted skills under this skill model (default `SkillCap = 1`).

Notes:

- These tables focus on **skill count outcomes** from the “gated fill” rules above.
- They **ignore the optional replace roll** (10% cross-type / 5% same-type), because replace mainly changes _which_ skill you have, not the cap itself.
- Weapon pools only contain weapon skills; shield pools only contain shield skills.

#### Scenario A: `Ss = 0`, `Ps_size ≥ 1` (no shared skill; at most one can be gained)

With default `SkillCap = 1`, there is only **one** free slot. Therefore:

- `P(final 1 skill) = p_attempt`
- `P(final 0 skills) = 1 - p_attempt`

Use the `p_attempt` table in [Section 4.6.4](#44-how-skills-are-gained-gated-fill) for the actual values.

#### Scenario B: `Ss ≥ 1` (shared skill exists)

With default `SkillCap = 1`, any shared skill consumes the entire skill cap:

- Final is always **1 skill** (the shared one), unless later dropped by the **overall rollable-slot cap** (if not protected by the skillbook lock/shared rule).

#### 4.6.7. Worked example (Divine)

<a id="47-worked-example-divine"></a>

This is a **weapon** example (weapon-only skill boosts).

Assume the rarity system produces a **Divine** forged item:

- **SkillCap[Divine]**: **1** _(default)_

Parent A granted skills:

- `Shout_Whirlwind`

Parent B granted skills:

- `Projectile_SkyShot`

Split into lists (deduped by skill ID):

- Shared skills `Ss = 0`: (none)
- Pool skills `Ps_size = 2`: `Shout_Whirlwind`, `Projectile_SkyShot`

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
- If you gained a skill and one pool skill remains, the optional replace roll ([Section 4.6.5](#45-overflow--replace-5)) can still swap which single skill you end up with.

Result:

- The forged item can roll up to `OverallCap[Divine, ItemType]` **overall rollable slots** (blue stats + ExtraProperties + skills), where `OverallCap` is default+learned per save, tracked per (rarity, item type) pair.
- It will have at most `SkillCap[Divine]` rollable granted skills (default+learned per save).

---

## 5. Rune slots inheritance

<a id="5-rune-slots-inheritance"></a>
<a id="4-rune-slots-inheritance"></a>

This section defines how many **empty rune slots** the forged item ends up with.

Here are what you can expect:

- Rune effects are never part of forging (rune-boosted items are rejected as ingredients). This section is only about **empty slots**.
- For non-Unique items, you either end up with **0 or 1** rune slot, and it depends on whether the parents had a slot.

Vanilla-style constraint (important for balance):

- For **non-Unique** items, treat rune slots as **binary**: you can have **0 or 1** rune slot total.
- (Unique can be a special case later; do not assume that behaviour here.)

### Default rule (non-Unique)

If **both** parents have `RuneSlots = 1`, then the forged item gets `RuneSlots_out = 1`.

If **exactly one** parent has `RuneSlots = 1`, then the forged item gets `RuneSlots_out = 1` with a **small** chance, otherwise `0`:

- Cross-type (default): **50%**
- Same-type (`TypeMatch=true`): **100%** (2×, capped)

$$RuneSlots_{out} \in \{0,1\}$$

Examples (non-Unique):

| Parent A slots | Parent B slots | Forged slots (cross-type default) | Forged slots (same-type, 2× capped) |
| :------------: | :------------: | :-------------------------------- | :---------------------------------- |
|       0        |       0        | 0                                 | 0                                   |
|       1        |       1        | 1                                 | 1                                   |
|       0        |       1        | 1 or 0 (50%)                      | 1 (100%)                            |
|       1        |       0        | 1 or 0 (50%)                      | 1 (100%)                            |

---

## 6. Implementation reference

<a id="6-implementation-reference"></a>
<a id="5-implementation-reference"></a>

This section is a developer reference for implementing the rules in this document.

[forging_system_implementation_blueprint_se.md → Appendix: Pseudocode reference](forging_system_implementation_blueprint_se.md#appendix-pseudocode-reference)
