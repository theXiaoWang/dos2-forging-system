# Inheritance System

## What this system does

This system aims to deliver a more RPG-like forging experience, one that can be calculated, but with enough RNG to allow for that YOLO.

When you forge two items, this system decides **which and how stats are inherited** by the new forged item.
- It also inherits the item's **base values**: weapon **base damage** (tooltip-midpoint based, same `WeaponType` only) and armour/shield/jewellery **base values** (tooltip-only, channel-by-channel).
- If both items share the same stats line, you're more likely to **keep the overlapping stats**.
- If both items share the same stats **but the numbers differ** (e.g. `+10%` vs `+14%` Critical Chance), it still counts as **shared stats**, but the forged item will **merge the numbers** into a new value.
- If a stats line is **not shared**, it goes into the **pool**, and keeping it is **more RNG**.
- If both items are very different, it’s **riskier but can be more rewarding**.
- Depending on your forging strategy, you could get a **steady, average** 
result, or a **unpredictable, volatile** result which can get **lucky** or 
**unlucky** streaks.

In short: 
- **More matching lines = more predictable forging**, and **vice versa** 
- **Closer stats values = merged numbers more consistent**.

---
## vNext restructuring note (read this first)

These docs are being restructured to match the new vNext balancing model:

- A hidden **default + learned (per-save) cap** system driven by what the player has actually acquired in vanilla gameplay.
- A single **overall rollable slots cap** shared across:
  - Blue stats
  - ExtraProperties (counts as **1 slot** if present)
  - Skills (each rollable skill counts as **1 slot**)
- Skills remain rollable, but can be **preserved** by:
  - A matching **skillbook lock** in the forge UI (exact skill ID match), and/or
  - Being **shared** between both parents.
- ExtraProperties is treated as a standalone channel and can be **guaranteed** if there are shared ExtraProperties tokens.

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
<summary><strong><a href="#3-stats-modifiers-inheritance">3. Stats Modifier Inheritance</a></strong></summary>

- [3.1. Introduction + design principles](#31-stats-modifiers-definition)
- [3.2. Selection rule (all modifiers)](#34-selection-rule-shared--pool--cap)
- [3.3. Merging rule (Blue Stats + ExtraProperties)](#33-merging-rule-how-numbers-are-merged)
- [3.4. Blue Stats](#34-blue-stats-channel)
  - [3.4.1. Blue Stats (definition)](#341-blue-stats-definition)
  - [3.4.2. Shared vs pool (Blue Stats)](#32-the-two-stats-lists)
  - [3.4.3. Worked examples (Blue Stats)](#36-worked-examples-stats-modifiers)
- [3.5. ExtraProperties](#35-extraproperties-channel)
  - [3.5.1. ExtraProperties (definition)](#41-extraproperties-definition)
  - [3.5.2. Shared vs pool tokens](#42-extraproperties-shared-vs-pool)
  - [3.5.3. Selection + internal cap](#43-extraproperties-selection--internal-cap)
  - [3.5.4. Slot competition + trimming](#44-extraproperties-slot-competition--trimming)
- [3.6. Skills](#36-skills-channel)
  - [3.6.1. Granted skills (definition)](#41-granted-skills-definition)
  - [3.6.2. Skill cap by rarity](#42-skill-cap-by-rarity)
  - [3.6.3. Shared vs pool skills](#43-shared-vs-pool-skills)
  - [3.6.4. How skills are gained (gated fill)](#44-how-skills-are-gained-gated-fill)
  - [3.6.5. Overflow + replace (type-modified)](#45-overflow--replace-5)
  - [3.6.6. Scenario tables](#46-scenario-tables)
  - [3.6.7. Worked example (Divine)](#47-worked-example-divine)
</details>

<details>
<summary><strong><a href="#4-rune-slots-inheritance">4. Rune slots inheritance</a></strong></summary>
</details>

<details>
<summary><strong><a href="#5-implementation-reference">5. Implementation reference</a></strong></summary>
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

Additionally, enforce **item-type compatibility**:
- **Weapons**: weapon can forge with weapon (cross weapon sub-types allowed, e.g. dagger ↔ axe).
- **Shields**: shield can only forge with shield.
- **Armour**: each armour slot only forges with the same slot (boots ↔ boots, helmet ↔ helmet, gloves ↔ gloves, chest ↔ chest, pants ↔ pants).
- **Jewellery**: ring ↔ ring, amulet ↔ amulet.
 
#### Output type selection
The forged output item is always the same **item type/slot** as the ingredient in the **Main Slot** (first forge slot).

| (Main Slot) Forge slot 1 | (Secondary Slot) Forge slot 2 | Output type | Notes |
| :--- | :--- | :--- | :--- |
| Boots | Boots | Boots | Armour pieces are slot-locked (boots ↔ boots only). |
| Dagger | One-handed axe | Dagger | Cross weapon sub-types are allowed, but the output still follows main slot. |

### 1.2. Forge flow overview
<a id="12-forge-flow-overview"></a>
This document splits forging into independent “channels”, because vanilla item generation works the same way.

vNext note: blue stats, ExtraProperties, and skills now share a single **overall rollable slots cap** defined in:
- [`rarity_system.md` → Caps (vNext)](rarity_system.md#22-caps-vnext-default--learned-per-save)

- **Base values** (base damage / armour / magic armour): determined by **item type + the white tooltip values**.
- **Blue stats** (stats modifiers): rollable modifiers (e.g. attributes, crit, “chance to set status”).
- **ExtraProperties**: rollable bundle (counts as **1 slot** if present, regardless of how many internal lines it expands into).
- **Skills**: rollable granted skills (each skill consumes **1 slot**, unless protected by shared/skillbook rules).
- **Rune slots**: a separate channel (only when empty; rune effects are forbidden as ingredients).

High-level forge order:
1. Decide the output’s **rarity** using the **[Rarity System](rarity_system.md)**.
2. Decide the output's **base values** (damage/armour) using **[Section 2](#2-base-values-inheritance)**.
3. Inherit **blue stats** using **[Section 3](#3-stats-modifiers-inheritance)**.
4. Inherit **ExtraProperties** using **[Section 3.5](#4-extraproperties-inheritance)**.
5. Inherit **skills** using **[Section 3.6](#4-skills-inheritance)**.
6. Inherit **rune slots** using **[Section 4](#4-rune-slots-inheritance)**.

### 1.3. Deterministic randomness (seed + multiplayer)
<a id="13-deterministic-randomness-seed--multiplayer"></a>
All random outcomes in this system (white numbers, blue stats, granted skills) must be driven by a single **forge seed** generated once per forge operation.

- **forgeSeed**: generated once per forge operation, then used to seed a deterministic PRNG.
- **Host-authoritative**: only the host/server rolls. Clients receive the final forged result.
- **Per-channel streams**: derive independent sub-streams from the same `forgeSeed` for base values, stats modifiers, and skills, so one channel’s rolls cannot affect another.

*Below is the technical breakdown for players who want the exact maths.*

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
- **Shields**: base armour and base magic armour.
- **Armour pieces** (helmets/chest/gloves/boots/pants): base armour and/or base magic armour.
- **Jewellery** (rings/amulets): base magic armour.
- **Slots that have no meaningful base values** (e.g. if both base armour and base magic armour are `0`): Section 2 is a **no-op** for those numeric channels.

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
  - **Shields / armour pieces**: two channels (physical armour and magic armour).
  - **Jewellery**: typically one channel (magic armour).
- **No-op rule**: if an item has no meaningful base value for a channel (e.g. the tooltip value is `0`), do **not** apply the merge to that channel.

#### Balance knobs (tuning table)
These are the **balance knobs** (tuning defaults). The symbol dictionary used by the algorithm is in **Section 2.5**: [Notation legend](#25-notation-legend-shared).
These are used by the tooltip-only base-value models in Section 2.
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

| Main \\ Donor | Common (0) | Uncommon (1) | Rare (2) | Epic (3) | Legendary (4) | Divine (5) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| Common (0) | 0.70 (0.30) | 0.66 (0.34) | 0.62 (0.38) | 0.58 (0.42) | 0.54 (0.46) | 0.50 (0.50) |
| Uncommon (1) | 0.74 (0.26) | 0.70 (0.30) | 0.66 (0.34) | 0.62 (0.38) | 0.58 (0.42) | 0.54 (0.46) |
| Rare (2) | 0.78 (0.22) | 0.74 (0.26) | 0.70 (0.30) | 0.66 (0.34) | 0.62 (0.38) | 0.58 (0.42) |
| Epic (3) | 0.82 (0.18) | 0.78 (0.22) | 0.74 (0.26) | 0.70 (0.30) | 0.66 (0.34) | 0.62 (0.38) |
| Legendary (4) | 0.86 (0.14) | 0.82 (0.18) | 0.78 (0.22) | 0.74 (0.26) | 0.70 (0.30) | 0.66 (0.34) |
| Divine (5) | 0.90 (0.10) | 0.86 (0.14) | 0.82 (0.18) | 0.78 (0.22) | 0.74 (0.26) | 0.70 (0.30) |

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

Shields / armour pieces (two channels):
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
  - Compute `w` from parent rarities (Section 2.3), so donor pull strength is `t = (1 - w)`
  - `delta = (B - A)`
  - `avg_base = A + t × delta`
  - `gain = max(0, delta / max(A, 1))`
  - `P(upgrade) = clamp(upgradeCap × gain^k, 0, upgradeCap)`
  - On upgrade failure: `avg_out = avg_base`
  - On upgrade success: roll `u ~ U(0,1)` and compute `avg_out = avg_base + (B - avg_base) × u^2` (higher is harder)

Finally, round to the displayed integer midpoint and let the engine display min/max using the weapon’s `Damage Range` rules.

#### Non-weapons (tooltip-only; per channel)
Let slot 1 be the “main” parent and slot 2 the “donor” parent.

Inputs (per channel):
- `A = Base(slot1)` (e.g. physical armour)
- `B = Base(slot2)` (same channel)
- `w` from rarity dominance (Section 2.3), so donor pull strength is `t = (1 - w)`

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

| Item | `WeaponType` | Tooltip damage | `avgDamage` |
| :--- | :--- | :---: | ---: |
| Slot 1 (main) | Crossbow | `130–136` | `A = 133.0` |
| Slot 2 (donor) | Crossbow | `150–157` | `B = 153.5` |

Compute:
| Key value | Result |
| :--- | ---: |
| `delta = (B-A)` | `20.5` |
| `w = clamp(0.70 + 0.04×(0-5), 0.50, 0.90)` | `0.50` |
| `t = (1-w)` | `0.50` |
| `avg_base = A + t×delta` | `133.0 + 0.50×20.5 = 143.25` |
| `gain = max(0, delta/max(A,1))` | `20.5/133.0 = 0.1541` |
| `P(upgrade) = upgradeCap × gain^k` | `50% × 0.1541 = 7.71%` |

| Outcome | `avg_out` | Notes |
| :--- | ---: | :--- |
| No upgrade | `avg_out = 143.25` | deterministic baseline |
| Upgrade example (`u=0.70`) | `avg_out = 143.25 + (153.5-143.25)×0.70^2 = 148.27` | exciting spike towards donor |

##### Example 2: Cross-type weapons do **not** change base damage (Spear + 2H Sword)
Different `WeaponType` ⇒ cross-type (`TypeMatch=false`).

| Item | `WeaponType` | Tooltip damage | `avgDamage` |
| :--- | :--- | :---: | ---: |
| Slot 1 (main) | Spear | `150–157` | `A = 153.5` |
| Slot 2 (donor) | 2H Sword | `170–188` | `B = 179.0` |

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

| Channel | Slot 1 `A` | Slot 2 `B` | `delta = (B-A)` | `Base = A + t×delta` | `gain = max(0, delta/max(A,1))` | `P(upgrade)` | No-upgrade output |
| :--- | ---: | ---: | ---: | ---: | ---: | :---: | ---: |
| Physical | `713` | `140` | `-573` | `713 + 0.30×(-573) = 541.1` | `0` | `0%` | `541` |
| Magic | `140` | `713` | `573` | `140 + 0.30×573 = 311.9` | `573/140 = 4.093` | `50%` (cap) | `312` |

Interpretation:
- The output remains a Strength chest (slot 1 identity is preserved).
- Per-channel upgrades are possible, and a magic-channel “spike” can pull significantly towards the donor when the donor is much better.

<details>
<summary><strong>Fully explicit view</strong></summary>

##### Physical Armour Channel

| Name | Value | How it was obtained |
| :--- | :---: | :--- |
| `A_phys` | `713` | slot 1 physical armour |
| `B_phys` | `140` | slot 2 physical armour |
| `w` | `0.70` | same rarity (Divine vs Divine) |
| `t = 1-w` | `0.30` | donor pull strength |
| `delta` | `(140-713) = -573` | donor is worse |
| `Base` | `713 + 0.30×(-573) = 541.1` | deterministic baseline |
| `P(upgrade)` | `0%` | donor is not better |

##### Magic Armour Channel

| Name | Value | How it was obtained |
| :--- | :---: | :--- |
| `A_magic` | `140` | slot 1 magic armour |
| `B_magic` | `713` | slot 2 magic armour |
| `w` | `0.70` | same rarity (Divine vs Divine) |
| `t = 1-w` | `0.30` | donor pull strength |
| `delta` | `(713-140) = 573` | donor improvement |
| `Base` | `140 + 0.30×573 = 311.9` | deterministic baseline |
| `gain` | `573/140 = 4.093` | relative improvement |
| `P(upgrade)` | `clamp(50% × 4.093, 0, 50%) = 50%` | capped |
| `Out (no upgrade)` | `round(311.9) = 312` | rounding policy |
| `Out (upgrade example, u=0.70)` | `311.9 + (713-311.9)×0.70^2 = 508.4 → 508` | exciting spike |

</details>

---

## 3. Stats Modifier Inheritance
<a id="3-stats-modifiers-inheritance"></a>

This section defines how **stats modifiers** are inherited when you forge.

In vNext, stats modifiers are split into three dedicated channels, each with its own unshared pool:
- **Blue Stats**: numeric “blue text” boosts like Strength, crit, resistances, etc.
- **ExtraProperties**: semicolon-separated tokens (counts as **1 slot** overall if present)
- **Skills**: rollable granted skills (each counts as **1 slot** overall)

The forged item applies one shared cap across these channels:
- `OverallCap[Rarity_out]` (default max 5 for Divine; default+learned per save; see [`rarity_system.md`](rarity_system.md#221-overall-rollable-slots-cap))

### 3.1. Introduction + design principles
<a id="31-stats-modifiers-definition"></a>

Design principles:
- **Shared-first**: shared modifiers are stable and predictable.
- **Pool risk/reward**: non-shared modifiers go into that channel’s pool and are harder to keep.
- **Consistent algorithms**: merging and selection are defined once up front; each channel applies them with its own identity keys.

The universal rules are defined next:
- **Selection rule + overall cap trimming** (Section 3.2)
- **Merging rule** (Section 3.3)

### 3.2. Selection rule (all modifiers)
<a id="34-selection-rule-shared--pool--cap"></a>

This selection rule is **universal** for all three modifier channels:
- **Blue Stats** (Section 3.4)
- **ExtraProperties** (Section 3.5)
- **Skills** (Section 3.6)

Each channel has its own **unshared pool candidates list** and is selected independently, then everything competes under the single **overall rollable slots cap** (`OverallCap`, max 5 by default for Divine).

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

$$E =
\begin{cases}
0 & \text{if } P_{size} = 0 \text{ or } P_{size} = 1 \\
\lfloor (P_{size} + 1) / 3 \rfloor & \text{otherwise}
\end{cases}
$$

#### Step 3: Choose the tier (sets luck odds)
The tier depends only on **pool size**:

| Pool size | Tier | First roll chances (Bad / Neutral / Good) | Chain chance (Down / Up) |
| :--- | :--- | :--- | :--- |
| **1** | Tier 1 (Safe) | `0% / 60% / 40%` | None |
| **2–4** | Tier 2 (Early) | `14% / 60% / 26%` | `0% / 24.23%` |
| **5–7** | Tier 3 (Mid) | `30% / 52% / 18%` | `30% / 25%` |
| **8+** | Tier 4 (Risky) | `33% / 55% / 12%` | `40% / 25%` |

Notation used below:
- `d` = down-chain chance (`p_chain_down`)
- `u` = up-chain chance (`p_chain_up`)

#### Weapon-type match modifier (Cross-type vs Same-type)
For **weapons**, we treat **exact same `WeaponType`** as "same-type". For other item categories, type mismatches are not allowed by eligibility rules, so they always behave like "same-type".

Let:
- `TypeMatch = (WeaponType_1 == WeaponType_2)` for weapons
- `TypeMatch = true` for non-weapons

The luck adjustment `A` is sampled from a tier-specific distribution:
- **Cross-type (default)** distribution if `TypeMatch=false`
- **Same-type** distribution if `TypeMatch=true`

Same-type is derived from the cross-type baseline by **doubling the "good" branch** and renormalising (this doubles every `A > 0` outcome):

For a tier with cross-type first-roll chances:
- `p_bad_cross`
- `p_neutral_cross`
- `p_good_cross`

We define same-type weights:

$$w_{bad}=p_{bad,cross}$$
$$w_{neutral}=p_{neutral,cross}$$
$$w_{good}=2\times p_{good,cross}$$

Then normalise:

$$Z=w_{bad}+w_{neutral}+w_{good}$$
$$p_{bad,same}=w_{bad}/Z,\ \ p_{neutral,same}=w_{neutral}/Z,\ \ p_{good,same}=w_{good}/Z$$

#### Step 4: Roll the luck adjustment (can chain)
The system samples a **luck adjustment** `A` using a "first roll + chain" model.
This `A` is a **variance** added to the expected baseline **E**, changing how many pool stats you keep:

- **Bad roll** (`A < 0`): you keep fewer pool stats than the baseline.
- **Neutral roll** (`A = 0`): you keep the expected baseline.
- **Good roll** (`A > 0`): you keep more pool stats than the baseline.

##### First roll (choose Bad / Neutral / Good)
Each tier defines `p_bad`, `p_neutral`, `p_good` (sum to 100%).

##### Chain (push further down/up)
If the first roll is:
- **Bad**: set `A = -1`, then repeatedly apply a **down-chain** with probability `p_chain_down`:
  - on success: `A -= 1` and try again
  - on failure: stop
- **Neutral**: set `A = 0` and stop
- **Good**: set `A = +1`, then repeatedly apply an **up-chain** with probability `p_chain_up`:
  - on success: `A += 1` and try again
  - on failure: stop

Finally apply the clamp via `P = clamp(E + A, 0, P_size)`. Equivalently, `A` is effectively clamped to:
- `A_min = -E` (cannot keep fewer than 0 pool modifiers)
- `A_max = P_size - E` (cannot keep more than all pool modifiers)

Closed form probabilities (after clamping) for any tier:

Let `d = p_chain_down`, `u = p_chain_up`, and let:
- `N_down = E` (max negative magnitude, since `A_min = -E`)
- `N_up = P_size - E` (max positive magnitude, since `A_max = P_size - E`)

Then:

- For `n = 1..(N_down-1)`:  
  `P(A = -n) = p_bad × d^(n-1) × (1 - d)`
- `P(A = -N_down) = p_bad × d^(N_down-1)` *(cap bucket; includes all deeper chains; i.e. "hit the cap or go beyond it")*
- `P(A = 0) = p_neutral`
- For `n = 1..(N_up-1)`:  
  `P(A = +n) = p_good × u^(n-1) × (1 - u)`
- `P(A = +N_up) = p_good × u^(N_up-1)` *(cap bucket; includes all deeper chains; i.e. "hit the cap or go beyond it")*

**How tables may show the cap bucket (Option A):**
- Some worked-example tables expand the cap bucket into:
  - "Stop at the cap" (exactly `A = ±N_*`), and
- "Overflow; clamped" (the chain would go beyond `±N_*`, but `P` is clamped).
- If an overflow row rounds to `0.00%`, the table may omit it for readability.

All tier parameters are defined in the **Step 3** table above.

**Safety rule (always true):** you can't keep fewer than **0** pool modifiers, and you can't keep more than the **pool size**.

#### Step 5: Build the per-channel result list
For a given channel:
1. Keep all **shared modifiers** (`S`).
2. Add **P** random modifiers from the channel's pool candidates list (uniformly).
3. This yields the channel's planned result count: `F = S + P`.

#### Step 6: Apply the overall modifier cap (cross-channel)
The forged item has a single cap `OverallCap[Rarity_out]` across:
- Blue stats
- ExtraProperties (slot)
- Skills

This section defines how we trim when `F_total > OverallCap`.

**Protection rule:**
- Shared modifiers are protected (not dropped by cap trimming).
- ExtraProperties slot is protected if `Sp ≥ 1` (shared ExtraProperties exists).

**Fair trimming rule (Option A, slot-weighted):**
- After protected/shared slots are counted, the remaining slots are allocated by rolling between *pending pool-picked slots*.
- Weight per channel is:
  - Blue stats: `Pb` (number of pool-picked blue stats)
  - Skills: `Ps` (number of pool-picked skills, if any)
  - ExtraProperties slot: `1` if the EP slot is pending as a pool slot (i.e. `Sp = 0` and EP exists), else `0`

If a channel wins a slot:
- **Blue stats**: pick one of the remaining pool-picked blue stats uniformly.
- **Skills**: pick one of the remaining pool-picked skills uniformly.
- **ExtraProperties**: keep the EP slot (then apply Section 3.5 internal token selection).

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
- Expected baseline: `E = floor((Pb_size + 1) / 3) = floor(5 / 3) = 1`
- Suppose your luck adjustment roll comes out as `V = +1`
- Modifiers from pool (kept): `Pb = clamp(E + V, 0, Pb_size) = clamp(1 + 1, 0, 4) = 2`
- Planned forged blue modifiers (before overall trimming): `Fb = Sb + Pb = 2 + 2 = 4`

Finally apply the overall rollable-slot cap:
- Assume the rarity system gives the new item **Rare** → `OverallCap[Rare] = 5`
- Final (blue only, no other channels in this example): `Final = min(Fb, OverallCap) = min(4, 5) = 4`

So you end up with:
- The 2 shared blue stats (always)
- Plus 2 of the pool blue stats (no trimming needed in this example)

#### Corner cases (park for later work)
- **Protection stacking vs OverallCap**: if multiple "protected" sources (shared modifiers, skillbook lock, `Sp ≥ 1` protecting the EP slot) ever imply more than `OverallCap`, the system needs an explicit priority rule for what breaks first.
- **ExtraProperties internal payload vs 1-slot accounting**: `Sp ≥ 1` can guarantee the EP slot, but internal token selection (`Pp_size → Pp`, clamped by `InternalCap`) may still represent multiple tooltip lines. This may skew balance compared to blue stats/skills.
- **Parent max-modifier cap implications**: if parent items themselves are capped to 5 total modifiers (blue + skills + EP slot), some pool sizes become impossible in certain scenarios (e.g. `Sb = 4` and EP present implies `Pb_size = 0` on both parents).

---

#### 3.2.1. Safe vs YOLO forging
<a id="35-safe-vs-yolo-forging"></a>

These two standalone examples are meant to show the difference between:
- **Safe forging**: many shared stats → stable outcomes (pool stats are just "bonus").
- **YOLO forging**: zero shared stats → pure variance (rare spikes are possible, but unreliable).

#### Safe forging (realistic cap: `OverallCap ≤ 5`, with skills/ExtraProperties competing)
```
Output rarity: Divine ⇒ `OverallCap[Divine] = 5` (default).

Item A: Divine Warhammer
 - Blue stats: +3 Strength, +2 Warfare, +15% Critical Chance, +20% Fire Resistance  (4)
 - Granted skill: Shout_Whirlwind  (1)

Item B: Divine Warhammer
 - Blue stats: +3 Strength, +2 Warfare, +15% Critical Chance, +20% Poison Resistance  (4)
 - ExtraProperties: (present; no shared token)  (1)
─────────────────────────────────────────
Shared Modifiers:
 - Shared Blue Stats: +3 Strength, +2 Warfare, +15% Critical Chance → `Sb = 3`
Pool candidates (unshared, per channel):
 - Pool Blue Stats candidates: +20% Fire Resistance, +20% Poison Resistance → `Pb_size = 2`
 - Pool Skills candidates: Shout_Whirlwind (no skillbook; not shared) → `Ps_size = 1`
 - ExtraProperties slot is a pool slot (present on B only; `Sp = 0`) → pending EP slot
```

Inputs for this example:
- `OverallCap[Divine] = 5`
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
- Using the **slot-weighted** overall trimming rule (Section 3.2):
  - weight(Blue) = `Pb = 1`, weight(Skills) = `Ps = 1`, weight(EP) = `1`
  - one of these three pool-picked slots is dropped (each **33.33%** in this case).

#### YOLO forging (realistic cap: `OverallCap ≤ 5`, everything competes)
```
Output rarity: Divine ⇒ `OverallCap[Divine] = 5` (default).

Item A: Divine Warhammer
 - Blue stats: +3 Strength, +2 Warfare, +2 Two-Handed, +15% Accuracy  (4)
 - Granted skill: Shout_Whirlwind  (1)

Item B: Divine Warhammer
 - Blue stats: +15% Critical Chance, +20% Fire Resistance, +10% Air Resistance, +1 Two-Handed  (4)
 - ExtraProperties: (present; no shared token)  (1)
─────────────────────────────────────────
Shared Modifiers:
 (none) → `S_total = 0`
Pool candidates (unshared, per channel):
 - Pool Blue Stats candidates: 8 lines → `Pb_size = 8`
 - Pool Skills candidates: 1 skill (no shared; no skillbook) → `Ps_size = 1`
 - ExtraProperties slot is a pool slot (`Sp = 0`) → pending EP slot
```

Inputs for this example:
- `OverallCap[Divine] = 5`

This is the perfect example for **YOLO forging**:
- With **0 shared stats**, you have **no guarantees**. Everything is a roll from the pool.
- Even if the blue-stats roll "wants" to keep many stats, the final result is hard-limited to **5 total rollable slots**.
- Because skills and ExtraProperties are pool slots here, they can be dropped under the same overall trimming step as pool-picked blue stats.

---
### 3.3. Merging rule (Blue Stats + ExtraProperties)
<a id="33-merging-rule-how-numbers-are-merged"></a>

Sometimes both parents have the **same stats**, but the **numbers** are different:
- `+10% Critical Chance` vs `+14% Critical Chance`
- `+3 Strength` vs `+4 Strength`

In this system, those are still treated as **shared modifiers** (same identity key), but the forged item will roll a **merged value**:
- **Blue Stats**: identity key is the stats key (e.g. `CriticalChance`, `Strength`)
- **ExtraProperties**: identity key is the canonicalised token key; if a shared token has numeric parameters, those parameters are merged using the same algorithm below

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

| Roll type | Chance | Multiplier |
| :--- | :---: | :--- |
| Tight (less volatile) | **50%** | $r \sim Tri(0.85,\ 1.00,\ 1.15)$ |
| Wide (more volatile) | **50%** | $r \sim Tri(0.70,\ 1.00,\ 1.30)$ |

##### 3. Clamp the result (allowed min/max range):

$$lo = \min(a,b)\times 0.85$$
$$hi = \max(a,b)\times 1.15$$

##### 4. Final merged value:

$$value = clamp(m \times r,\ lo,\ hi)$$

Then format the number back into a stats line using the stats' rounding rules.

#### Rounding rules
- **Integer stats** (Attributes, skill levels): round to the nearest integer.
- **Percent stats** (Critical Chance, Accuracy, Resistances, "X% chance to set Y"): round to the nearest integer percent.

#### Worked examples

##### Example A: `+10%` vs `+14%` Critical Chance
- `a=10`, `b=14` → `m=12`
- `lo = 8.5`, `hi = 16.1`
- Tight roll range is `12 × [0.85, 1.15] = [10.2, 13.8]` → roughly **10%–14%** after rounding.
- Wide roll range is `12 × [0.70, 1.30] = [8.4, 15.6]` → **9%–16%** after rounding (low end clamps to 8.5).

##### Example B (shield): `Blocking +10` vs `Blocking +15`
- `a=10`, `b=15` → `m=12.5`
- `lo = 8.5`, `hi = 17.25`
- Tight roll gives roughly **11–14** after rounding.
- Wide roll can reach roughly **9–16** after rounding:
  - Low end: `m × 0.70 = 8.75` (already above `lo=8.5`) → rounds to **9**
  - High end: `m × 1.30 = 16.25` (below `hi=17.25`) → rounds to **16**

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

#### Quick "one forge" walk-through (shows what the 50% wide-roll chance means)
Using Example A (`+10%` vs `+14%` Critical Chance):

| Step | Roll | Calculation | Result (rounded) |
| :---: | :--- | :--- | :--- |
| 1 | Choose roll type | 50% tight vs 50% wide | Tight or Wide |
| 2A | Wide case | `r=1.22` → `value = clamp(12×1.22, 8.5, 16.1) = 14.64` | `15%` |
| 2B | Tight case | `r=0.90` → `value = clamp(12×0.90, 8.5, 16.1) = 10.8` | `11%` |
---

### 3.4. Blue Stats
<a id="34-blue-stats-channel"></a>

#### 3.4.1. Blue Stats (definition)
<a id="341-blue-stats-definition"></a>

Blue Stats are rollable numeric boosts (blue text stats) that appear on items based on their rarity. These include:
- Attributes (Strength, Finesse, Intelligence, etc.)
- Combat abilities (Warfare, Scoundrel, etc.)
- Resistances (Fire, Poison, etc.)
- Status chance effects ("X% chance to set Y")
- Other numeric modifiers (Critical Chance, Accuracy, Initiative, Movement, Blocking, etc.)

#### 3.4.2. Shared vs pool (Blue Stats)
<a id="32-the-two-stats-lists"></a>

- **Shared Blue Stats (Sb)**: blue stats lines on **both** parents (guaranteed).
- **Pool Blue Stats size (Pb_size)**: blue stats lines that are **not shared** (unique to either parent). This is the combined pool candidates list from both parents.

Key values:
- `Sb`: Shared Blue Stats (count)
- `Pb_size`: pool size for Blue Stats (candidate count)
- `Pb`: modifiers from pool (kept/picked count) for Blue Stats
- `Fb`: forged blue modifiers before overall trimming (`Fb = Sb + Pb`)

#### 3.4.3. Worked examples (Blue Stats)
<a id="36-worked-examples-stats-modifiers"></a>

vNext note:
- The worked examples below focus on the **blue-stats selection step** (blue stats channel only).
- To keep the tables readable and consistent, we assume:
  - Output rarity is **Divine**, so `OverallCap = 5` (default).
  - Other channels (Skills / ExtraProperties) do not occupy slots in these tables.
- Therefore, any outcomes where the blue-stats result would exceed 5 are bucketed into **`5+`** (meaning “would be >5, then clamped by the overall cap”).

#### Tier 1 (Pool size = 1, no chains)

##### Example 1
```
Item A: Traveller’s Amulet
 - +1 Aerotheurge
 - +0.5m Movement

Item B: Scout’s Amulet
 - +1 Aerotheurge
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
- Cross-type: `p_bad=0%`, `p_neutral=60%`, `p_good=40%`, `d=0.00`, `u=0.00` (no chain)
- Same-type: `p_bad=0%`, `p_neutral=42.86%`, `p_good=57.14%`, `d=0.00`, `u=0.00` (no chain)

| Luck adjustment<br>(A) | Modifiers from pool<br>(Pb) | Forged item modifiers<br>(Fb) | Chance (math) | Cross-type (default) | Same-type |
| :---: | :---: | :---: | :--- | ---: | ---: |
| 0 | 0 | 1 | Cross: `p_neutral = 60%`<br>Same: `p_neutral = 42.86%` | 60.00% | 42.86% |
| +1 | 1 | 2 | Cross: `p_good = 40%` (no chain)<br>Same: `p_good = 57.14%` (no chain) | 40.00% | 57.14% |

#### Tier 2 (Pool size = 2–4)

##### Example 1 (Pool size = 3)
```
Item A: Mage’s Helmet
 - +2 Intelligence
 - +10% Fire Resistance
 - +1 Loremaster

Item B: Scholar’s Helmet
 - +2 Intelligence
 - +10% Water Resistance
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
- Cross-type: `p_bad=14%`, `p_neutral=60%`, `p_good=26%`, `d=0.00`, `u=0.2423`
- Same-type: `p_bad=11.11%`, `p_neutral=47.62%`, `p_good=41.27%`, `d=0.00`, `u=0.2423`

| Luck adjustment<br>(A) | Modifiers from pool<br>(Pb) | Forged item modifiers<br>(Fb) | Chance (math) | Cross-type (default) | Same-type |
| :---: | :---: | :---: | :--- | ---: | ---: |
| -1 | 0 | 1 | Cross: `p_bad = 14%` (no down-chain)<br>Same: `p_bad = 11.11%` | 14.00% | 11.11% |
| 0 | 1 | 2 | Cross: `p_neutral = 60%`<br>Same: `p_neutral = 47.62%` | 60.00% | 47.62% |
| +1 | 2 | 3 | Cross: `p_good × (1-u) = 26% × (1-0.2423) = 19.70%`<br>Same: `p_good × (1-u) = 41.27% × (1-0.2423) = 31.27%` | 19.70% | 31.27% |
| +2 | 3 | 4 | Cross: `p_good × u = 26% × 0.2423 = 6.30%` (cap bucket)<br>Same: `p_good × u = 41.27% × 0.2423 = 10.00%` | 6.30% | 10.00% |

##### Example 2 (Pool size = 4, weapon-only cross-subtype allowed)
```
Item A: Knight’s Dagger
 - +1 Warfare
 - +10% Critical Chance
 - +1 Finesse
 - +2 Initiative

Item B: Soldier’s One-Handed Axe
 - +1 Warfare
 - +10% Critical Chance
 - +12% Fire Resistance
 - 10% chance to set Bleeding
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
- Cross-type: `p_bad=14%`, `p_neutral=60%`, `p_good=26%`, `d=0.00`, `u=0.2423`
- Same-type: `p_bad=11.11%`, `p_neutral=47.62%`, `p_good=41.27%`, `d=0.00`, `u=0.2423`

| Luck adjustment<br>(A) | Modifiers from pool<br>(Pb) | Forged item modifiers<br>(Fb) | Chance (math) | Cross-type (default) | Same-type |
| :---: | :---: | :---: | :--- | ---: | ---: |
| -1 | 0 | 2 | Cross: `p_bad = 14%` (no down-chain)<br>Same: `p_bad = 11.11%` | 14.00% | 11.11% |
| 0 | 1 | 3 | Cross: `p_neutral = 60%`<br>Same: `p_neutral = 47.62%` | 60.00% | 47.62% |
| +1 | 2 | 4 | Cross: `p_good × (1-u) = 26% × 0.7577 = 19.70%`<br>Same: `p_good × 0.7577 = 41.27% × 0.7577 = 31.27%` | 19.70% | 31.27% |
| +2+ | 3+ | 5+ | Cross: `p_good × u = 26% × 0.2423 = 6.30%`<br>Same: `p_good × u = 41.27% × 0.2423 = 10.00%` | 6.30% | 10.00% |
#### Tier 3 (Pool size = 5–7)

##### Example 1 (Pool size = 5)
```
Item A: Ranger’s Boots
 - +1 Finesse
 - +0.5m Movement
 - +2 Initiative
 - +10% Fire Resistance
 - +1 Sneaking

Item B: Scout’s Boots
 - +1 Finesse
 - +0.5m Movement
 - +10% Air Resistance
 - +10% Earth Resistance
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

| Luck adjustment<br>(A) | Modifiers from pool<br>(Pb) | Forged item modifiers<br>(Fb) | Chance (math) | Cross-type (default) | Same-type |
| :---: | :---: | :---: | :--- | ---: | ---: |
| -2 | 0 | 2 | Cross: `p_bad × d = 30% × 0.30 = 9.00%` (cap bucket)<br>Same: `p_bad × d = 25.42% × 0.30 = 7.63%` | 9.00% | 7.63% |
| -1 | 1 | 3 | Cross: `p_bad × (1-d) = 30% × 0.70 = 21.00%`<br>Same: `p_bad × 0.70 = 25.42% × 0.70 = 17.80%` | 21.00% | 17.80% |
| 0 | 2 | 4 | Cross: `p_neutral = 52%`<br>Same: `p_neutral = 44.07%` | 52.00% | 44.07% |
| +1+ | 3+ | 5+ | Cross: `p_good = 18%`<br>Same: `p_good = 30.51%` | 18.00% | 30.51% |

##### Example 2 (Pool size = 7)
```
Item A: Enchanted Greatsword
 - +1 Strength
 - +1 Warfare
 - +10% Critical Chance
 - +1 Two-Handed
 - +15% Accuracy

Item B: Champion’s Greatsword
 - +1 Strength
 - +12% Fire Resistance
 - +1 Pyrokinetic
 - +1 Aerotheurge
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

| Luck adjustment<br>(A) | Modifiers from pool<br>(Pb) | Forged item modifiers<br>(Fb) | Chance (math) | Cross-type (default) | Same-type |
| :---: | :---: | :---: | :--- | ---: | ---: |
| -2 | 0 | 1 | Cross: `p_bad × d = 30% × 0.30 = 9.00%` (cap bucket)<br>Same: `p_bad × d = 25.42% × 0.30 = 7.63%` | 9.00% | 7.63% |
| -1 | 1 | 2 | Cross: `p_bad × (1-d) = 30% × 0.70 = 21.00%`<br>Same: `p_bad × 0.70 = 25.42% × 0.70 = 17.80%` | 21.00% | 17.80% |
| 0 | 2 | 3 | Cross: `p_neutral = 52%`<br>Same: `p_neutral = 44.07%` | 52.00% | 44.07% |
| +1 | 3 | 4 | Cross: `p_good × (1-u) = 18% × 0.75 = 13.50%`<br>Same: `p_good × 0.75 = 30.51% × 0.75 = 22.88%` | 13.50% | 22.88% |
| +2+ | 4+ | 5+ | Cross: `p_good × u = 18% × 0.25 = 4.50%`<br>Same: `p_good × u = 30.51% × 0.25 = 7.63%` | 4.50% | 7.63% |

#### Tier 4 (Pool size = 8+)

##### Example 1 (Pool size = 8)
```
Item A: Tower Shield
 - +2 Constitution
 - Blocking +15
 - +2 Initiative
 - +10% Water Resistance

Item B: Kite Shield
 - +10% Fire Resistance
 - +10% Earth Resistance
 - +1 Leadership
 - +0.5m Movement
─────────────────────────────────────────
Shared Blue Stats:
 (none)
Pool Blue Stats:
 - +2 Constitution
 - Blocking +15
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

| Luck adjustment<br>(A) | Modifiers from pool<br>(Pb) | Forged item modifiers<br>(Fb) | Chance (math) | Cross-type (default) | Same-type |
| :---: | :---: | :---: | :--- | ---: | ---: |
| -3 | 0 | 0 | Cross: `p_bad × d^2 = 33% × 0.40^2 = 5.28%` (cap bucket)<br>Same: `p_bad × d^2 = 29.46% × 0.40^2 = 4.71%` | 5.28% | 4.71% |
| -2 | 1 | 1 | Cross: `p_bad × d × (1-d) = 33% × 0.40 × 0.60 = 7.92%`<br>Same: `p_bad × 0.40 × 0.60 = 29.46% × 0.40 × 0.60 = 7.07%` | 7.92% | 7.07% |
| -1 | 2 | 2 | Cross: `p_bad × (1-d) = 33% × 0.60 = 19.80%`<br>Same: `p_bad × 0.60 = 29.46% × 0.60 = 17.68%` | 19.80% | 17.68% |
| 0 | 3 | 3 | Cross: `p_neutral = 55%`<br>Same: `p_neutral = 49.11%` | 55.00% | 49.11% |
| +1 | 4 | 4 | Cross: `p_good × (1-u) = 12% × 0.75 = 9.00%`<br>Same: `p_good × 0.75 = 21.43% × 0.75 = 16.07%` | 9.00% | 16.07% |
| +2+ | 5+ | 5+ | Cross: `p_good × u = 12% × 0.25 = 3.00%`<br>Same: `p_good × u = 21.43% × 0.25 = 5.36%` | 3.00% | 5.36% |

---

### 3.5. ExtraProperties
<a id="35-extraproperties-channel"></a>
<a id="4-extraproperties-inheritance"></a>

This section defines how **ExtraProperties** are inherited when you forge.

In vNext, ExtraProperties is treated as its own channel:
- ExtraProperties consumes **1** overall rollable slot if present (regardless of how many internal effects/tooltip lines it expands into).
- The **internal content** (tokens) is merged/selected separately, with an internal cap based on the parents.

#### 3.5.1. ExtraProperties (definition)
<a id="41-extraproperties-definition"></a>

ExtraProperties is a semicolon-separated list of effects stored on the item (e.g. proc chances, statuses, immunities, surfaces).

Important: the tooltip may show multiple lines, but for the overall cap, ExtraProperties is counted as **one slot**.

#### 3.5.2. Shared vs pool tokens
<a id="42-extraproperties-shared-vs-pool"></a>

Parse each parent’s ExtraProperties string into ordered tokens:
- Split on `;`
- Trim whitespace
- Normalise into a canonical key for identity comparisons (e.g. strip whitespace, normalise case where safe, and isolate the “effect type” portion).

Then compute:
- **Shared ExtraProperties (Sp)**: tokens that match by canonical key on both parents (guaranteed to be kept, with parameter merge if applicable).
- **Pool ExtraProperties size (Pp_size)**: tokens present on only one parent (pool candidates).

#### 3.5.3. Selection + internal cap (max of parent lines)
<a id="43-extraproperties-selection--internal-cap"></a>

Let:
- `A = tokenCount(parentA)`
- `B = tokenCount(parentB)`
- `InternalCap = max(A, B)`

Build the output token list:
1. Keep all shared tokens (merge parameters if the same token differs in numbers, using the same “merge then clamp” philosophy as blue stats).
2. Roll additional tokens from the pool using the selection rule in **Section 3.2**:
   - `P_size = Pp_size`, `P = Pp`
3. Clamp the final token list to `InternalCap`.

#### 3.5.4. Slot competition + trimming
<a id="44-extraproperties-slot-competition--trimming"></a>

ExtraProperties occupies one **slot** in the overall rollable cap.

Rule:
- If `Sp ≥ 1`, the ExtraProperties slot is **guaranteed** to be present (it consumes 1 slot and is protected from overall-cap trimming).
- Otherwise, the ExtraProperties slot is a **pool slot**. If the forge result is over the overall cap, this slot competes under the universal overall-cap trimming rule in **Section 3.2** (slot-weighted).

---
### 3.6. Skills
<a id="36-skills-channel"></a>
<a id="4-skills-inheritance"></a>
This section defines how **granted skills** are inherited when you forge (vNext).

- Granted skills are a separate channel from normal **blue stats**.
- vNext: each rollable granted skill consumes **1** overall rollable slot (shared cap with blue stats + ExtraProperties).
- Skills are rollable; unless preserved by the **skillbook lock** or shared between both parents, they can be lost when applying the overall cap (equal drop chance among pool slots).
- Skills also have a per-save learned **skill count cap** (`SkillCap[r]`) defined in [`rarity_system.md`](rarity_system.md#222-skill-cap-vnext).

Here are what you can expect:
- You can sometimes carry a skill across, or gain one from the ingredient pool, but you will always be limited by the rarity’s **skill cap** (default is 1 for all non-Unique rarities).
- Even if a skill is gained by the skill rules, it can still be dropped later if the final item is over the **overall rollable-slot cap** and the skill is not protected (no skillbook lock; not shared).

#### 3.6.1. Granted skills (definition)
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

#### 3.6.2. Skill cap by rarity
<a id="42-skill-cap-by-rarity"></a>

This is the maximum number of **rollable granted skills** on the forged item.

vNext: this cap is **default + learned per save**:
- Default values are listed below.
- The save can learn higher values if the player ever obtains an item of that rarity with more rollable granted skills.
- See: [`rarity_system.md` → Skill count cap (vNext)](rarity_system.md#222-skill-cap-vnext)

| Rarity index | Name | Granted skill cap |
| :--- | :--- | :---: |
| **0** | Common | **1** |
| **1** | Uncommon | **1** |
| **2** | Rare | **1** |
| **3** | Epic | **1** |
| **4** | Legendary | **1** |
| **5** | Divine | **1** |

*Unique is ignored for now (do not consider it in vNext balancing).*

#### 3.6.2.1. Skillbook lock (preserve by exact skill ID)
<a id="421-skillbook-lock"></a>

If the player inserts a skillbook into the dedicated forge UI slot, the forge must validate it against the parent item’s granted skill(s):

- Match by **exact skill ID** (e.g. `Target_ShockingTouch`, `Shout_Whirlwind`), not by display name.
- If the skillbook does not match any skill granted by the main-slot item (parent A), block forging with:
  - “No matched skills found on the item!”

If both parents have matching skillbooks:
- The main-slot item’s (parent A) skill is the guaranteed inherited one.

#### 3.6.3. Shared vs pool skills
<a id="43-shared-vs-pool-skills"></a>

Split granted skills into two lists:

- **Shared Skills (Ss)**: granted skills present on **both** parents (kept unless we must trim due to cap overflow).
- **Pool Skills size (Ps_size)**: granted skills present on **only one** parent (pool candidates).

#### Skill identity (dedupe key)
Use the **skill ID** as the identity key (e.g. `Shout_Whirlwind`, `Projectile_BouncingShield`), not the boost name.

#### 3.6.4. How skills are gained (gated fill)
<a id="44-how-skills-are-gained-gated-fill"></a>

Skills are **more precious than stats**, so the skill channel does **not** use the stat-style “keep half the pool” baseline.

Instead, skills use a **cap + gated fill** model:
- **Shared skills are protected** (kept first).
- You only try to gain skills for **free skill slots** (up to the rarity skill cap).
- The chance to gain a skill **increases with pool size** (`P_remaining`).

#### Key values (skills)
- **Ss**: number of shared rollable skills (present on both parents).
- **Ps_size**: number of pool rollable skills (present on only one parent).
- **SkillCap**: from [Section 3.6.2](#42-skill-cap-by-rarity).
- **FreeSlots**: `max(0, SkillCap - min(Ss, SkillCap))`

#### Gain chance model (rarity + pool size)
We define a per-attempt gain chance:

`p_attempt_cross = base_cross(rarity) * m(P_remaining)`

Weapon-type match modifier:
- If `TypeMatch=true` (exact same WeaponType for weapons; always true for non-weapons), then `p_attempt = clamp(2 × p_attempt_cross, 0, 100%)`.
- Otherwise, `p_attempt = p_attempt_cross`.

Where `base_cross(rarity)` (cross-type default) is:
- `base_cross(Common) = 12%` *(tuning default)*  
- `base_cross(Uncommon) = 14%` *(tuning default)*  
- `base_cross(Rare) = 16%` *(tuning default)*  
- `base_cross(Epic) = 18%` *(tuning default)*  
- `base_cross(Legendary) = 18%` *(tuning default)*  
- `base_cross(Divine) = 20%` *(tuning default)*  

And the pool-size multiplier is:

| `P_remaining` | `m(P_remaining)` |
| :---: | :---: |
| 1 | 1.0 |
| 2 | 1.4 |

Because each parent item can contribute at most **1** rollable granted skill, we always have:
- `P_remaining ∈ {0,1,2}`

So the actual per-attempt gain chances are:

| Output rarity | `P_remaining` | Cross-type `p_attempt` (default) | Same-type `p_attempt` (2×, capped) |
| :--- | :---: | :---: | :---: |
| Common | 1 | 12.0% | 24.0% |
| Common | 2 | 16.8% | 33.6% |
| Uncommon | 1 | 14.0% | 28.0% |
| Uncommon | 2 | 19.6% | 39.2% |
| Rare | 1 | 16.0% | 32.0% |
| Rare | 2 | 22.4% | 44.8% |
| Epic | 1 | 18.0% | 36.0% |
| Epic | 2 | 25.2% | 50.4% |
| Legendary | 1 | 18.0% | 36.0% |
| Legendary | 2 | 25.2% | 50.4% |
| Divine | 1 | 20.0% | 40.0% |
| Divine | 2 | 28.0% | 56.0% |

#### 3.6.5. Overflow + replace (type-modified)
<a id="45-overflow--replace-5"></a>

All randomness in this subsection is **host-authoritative** and driven by `forgeSeed` (see [Section 1.3](#13-deterministic-randomness-seed--multiplayer)).

1. Build `sharedSkills` (deduped) and `poolSkills` (deduped).
2. Keep shared first:
   - `finalSkills = sharedSkills` (trim down to `SkillCap` only if shared exceeds cap).
3. Compute `freeSlots = SkillCap - len(finalSkills)`.
4. Fill free slots with gated gain rolls:
   - For each free slot (at most `freeSlots` attempts):
     - Let `P_remaining = len(poolSkills)`
     - Roll a random number; success chance is `p_attempt` ([Section 3.6.4](#44-how-skills-are-gained-gated-fill)).
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
- `{Shout_Whirlwind}` *(gain succeeded and selected this skill; cap is 1)*

Interpretation:
- With default `SkillCap = 1`, only one skill can ever be kept.
- If the gain roll succeeds (Section 3.6.4), one of the pool skills is selected.
- If the gain roll succeeds and there is still another pool skill remaining, the optional replace roll can swap which single skill you end up with.

#### 3.6.6. Scenario tables
<a id="46-scenario-tables"></a>

These tables show the probability of ending with **0 / 1** rollable granted skills under this skill model (default `SkillCap = 1`).

Notes:
- These tables focus on **skill count outcomes** from the “gated fill” rules above.
- They **ignore the optional replace roll** (10% cross-type / 5% same-type), because replace mainly changes *which* skill you have, not the cap itself.
- Weapon pools only contain weapon skills; shield pools only contain shield skills.

#### Scenario A: `Ss = 0`, `Ps_size ≥ 1` (no shared skill; at most one can be gained)

With default `SkillCap = 1`, there is only **one** free slot. Therefore:
- `P(final 1 skill) = p_attempt`
- `P(final 0 skills) = 1 - p_attempt`

Use the `p_attempt` table in **Section 3.6.4** for the actual values.

#### Scenario B: `Ss ≥ 1` (shared skill exists)

With default `SkillCap = 1`, any shared skill consumes the entire skill cap:
- Final is always **1 skill** (the shared one), unless later dropped by the **overall rollable-slot cap** (if not protected by the skillbook lock/shared rule).

#### 3.6.7. Worked example (Divine)
<a id="47-worked-example-divine"></a>

This is a **weapon** example (weapon-only skill boosts).

Assume the rarity system produces a **Divine** forged item:
- **SkillCap[Divine]**: **1** *(default)*

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
- If you gained a skill and one pool skill remains, the optional replace roll (Section 3.6.5) can still swap which single skill you end up with.

Result:
Result (vNext):
- The forged item can roll up to `OverallCap[Divine]` **overall rollable slots** (blue stats + ExtraProperties + skills), where `OverallCap` is default+learned per save.
- It will have at most `SkillCap[Divine]` rollable granted skills (default+learned per save).

---
## 4. Rune slots inheritance
<a id="4-rune-slots-inheritance"></a>
<a id="5-rune-slots-inheritance"></a>

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
| :---: | :---: | :--- | :--- |
| 0 | 0 | 0 | 0 |
| 1 | 1 | 1 | 1 |
| 0 | 1 | 1 with 50%, else 0 | 1 (100%) |
| 1 | 0 | 1 with 50%, else 0 | 1 (100%) |
---
## 5. Implementation reference 
<a id="5-implementation-reference"></a>
<a id="6-implementation-reference"></a>

This section is a developer reference for implementing the rules in this document.

[forging_system_implementation_blueprint_se.md → Appendix: Pseudocode reference](forging_system_implementation_blueprint_se.md#appendix-pseudocode-reference)
