# Inheritance System

## What this system does


This system aims to deliver a more RPG-like forging experience, one that can be calculated, but with enough RNG to allow for that YOLO.

When you forge two items, this system decides which and how **blue text stats** are inherited by the new forged item.
- If both items share the same stat line, you’re more likely to **keep the overlapping stat** (it’s safer).
- If both items share the same stat **but the numbers differ** (e.g. `+10%` vs `+14%` Critical Chance), it still counts as a **shared stat**, but the forged item will **merge the numbers** into a new  value based on the parents' value.
- If both items are very different, it’s **riskier but can be more rewarding** (there are more possible outcomes).
- Depending on your forging strategy, You could get a **steady, average** result, or a **unpredictable, volatile** result which can get **lucky** or **unlucky** streaks.

In short: 
- **More matching lines = more predictable forging**, and **vice versa** 
- **Closer stats values = merged numbers more consistent**.

<details>
<summary><strong>Contents (click to expand)</strong></summary>

<details>
<summary><strong><a href="#1-forge-preconditions">1. Forge preconditions</a></strong></summary>

- [1.1. Ingredient eligibility](#11-ingredient-eligibility)
- [1.2. Forge flow overview](#12-forge-flow-overview)
</details>

<details>
<summary><strong><a href="#2-innate-damage-and-armour-inheritance">2. Innate damage and armour inheritance</a></strong></summary>

- [2.1. Innate chassis (definition)](#21-innate-chassis-definition)
- [2.2. Output rules (level/type/rarity)](#22-output-rules-leveltyperarity)
- [2.3. Parameters (tuning knobs)](#23-parameters-tuning-knobs)
- [2.4. Measuring innate values (no rune/boost pollution)](#24-measuring-innate-values-no-runeboost-pollution)
- [2.5. Normalisation (q → percentile p)](#25-normalisation-q--percentile-p)
- [2.6. Cross-type merging (w + conversionLoss)](#26-cross-type-merging-w--conversionloss)
- [2.7. Worked examples (tables)](#27-worked-examples-tables)
</details>

<details>
<summary><strong><a href="#3-blue-stat-modifiers-inheritance">3. Blue stat modifiers inheritance</a></strong></summary>

- [3.1. Modifier cap for each rarity](#31-modifier-cap-for-each-rarity)
- [3.2. The two stat lists](#32-the-two-stat-lists)
- [3.3. Merging rule (how numbers are merged)](#33-merging-rule-how-numbers-are-merged)
- [3.4. Selection rule (shared + pool + cap)](#34-selection-rule-shared--pool--cap)
</details>

<details>
<summary><strong><a href="#4-granted-skill-inheritance">4. Granted skill inheritance</a></strong></summary>

- [4.1. Granted skills (definition)](#41-granted-skills-definition)
- [4.2. Skill cap by rarity](#42-skill-cap-by-rarity)
- [4.3. Shared vs pool skills](#43-shared-vs-pool-skills)
- [4.4. How skills are gained (gated fill)](#44-how-skills-are-gained-gated-fill)
- [4.5. Overflow + replace (5%)](#45-overflow--replace-5)
- [4.6. Scenario tables](#46-scenario-tables)
- [4.7. Worked example (Divine)](#47-worked-example-divine)
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
### 1.1. Ingredient eligibility
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
The forged output item is always the same **item type/slot** as the ingredient in the **first forge slot**.

| Forge slot 1 | Forge slot 2 | Output type | Notes |
| :--- | :--- | :--- | :--- |
| Boots | Boots | Boots | Armour is slot-locked (boots ↔ boots only). |
| Dagger | One-handed axe | Dagger | Cross weapon sub-types are allowed, but the output still follows slot 1. |

### 1.2. Forge flow overview
This document splits forging into independent “channels”, because vanilla item generation works the same way:

- **Innate chassis** (base damage / armour / magic armour): determined by **item type + level + rarity**.
- **Blue stat modifiers** (boosts): rollable modifiers (eg attributes, crit, “chance to set status”) bounded by rarity modifier caps.
- **Granted skills**: a separate, rarity-capped channel (vanilla-aligned).
- **Rune slots**: a separate channel (only when empty; rune effects are forbidden as ingredients).

High-level forge order:
1. Decide the output’s **rarity** using the **[Rarity System](rarity_system.md)**.
2. Decide the output’s **innate chassis** (damage/armour) using **[Section 2](#2-innate-damage-and-armour-inheritance)**.
3. Inherit **blue stat modifiers** using **[Section 3](#3-blue-stat-modifiers-inheritance)** (including the modifier cap table).
4. Inherit **granted skills** using **[Section 4](#4-granted-skill-inheritance)**.
5. Inherit **rune slots** using **[Section 5](#5-rune-slots-inheritance)**.

*Below is the technical breakdown for players who want the exact maths.*

---
## 2. Innate damage and armour inheritance

This section defines how to merge **raw numeric power** (weapon damage, shield armour) in a way that:

- Always outputs an item at the **player’s current level**.
- Prevents “cross-type budget stealing” (e.g. importing a two-handed axe’s raw budget into a dagger).
- Avoids nonsense when ingredient levels are far apart (e.g. level 6 + level 13).
- Ensures the output stays **capped by its own (type, level, rarity)** budget.

This is a **separate** step from “blue stats” inheritance:
- Section 3 governs rollable stat lines (boosts).
- Section 4 governs granted skills (separate cap).
- Section 5 governs rune slots (separate channel).
- This section governs the item’s **innate/base numeric chassis** only.

### 2.1. Innate chassis (definition)
This normalisation model is intentionally generic: it works for any item that has a meaningful **innate numeric chassis** (raw template numbers, not boosts).

- **Weapons**: innate/base damage range.
- **Shields**: innate/base armour and innate/base magic armour.
- **Armour pieces** (helmets/chest/gloves/boots/pants): innate/base armour and innate/base magic armour.
- **Slots that have no meaningful chassis** (e.g. if both base armour and base magic armour are `0`): Section 2 is a **no-op** for those numeric channels (do not attempt to normalise/divide by a `0` baseline).

Quick “what is chassis vs what is rollable?” table (vanilla-backed examples):

| Equipment category | Innate chassis (Section 2) | Rollable numeric examples (Section 3 blue boosts) |
| :--- | :--- | :--- |
| Weapon | Damage range (`D_min..D_max`) | Initiative on weapons (e.g. `_Boost_Weapon_Secondary_Initiative_Normal` / `_Boost_Weapon_Secondary_Initiative_Small`) |
| Shield | `Armor Defense Value`, `Magic Armor Value` | Blocking (e.g. `_Boost_Shield_Special_Block_Shield` applies `Blocking=10`, with Medium/Large variants), plus shield initiative/movement boosts (`_Boost_Shield_Secondary_Initiative_*`, `_Boost_Shield_Secondary_MovementSpeed_*`) |
| Armour pieces (helmet/chest/gloves/boots/pants) | `Armor Defense Value`, `Magic Armor Value` | Boots: movement (`_Boost_Armor_Boots_Secondary_MovementSpeed` applies `Movement=50`, Medium `Movement=75`, Large `Movement=100`) and initiative (`_Boost_Armor_Boots_Secondary_Initiative_*`); Belt: initiative (`_Boost_Armor_Belt_Secondary_Initiative` applies `Initiative=2`, Medium `Initiative=4`, Large `Initiative=6`) |
| Jewellery (rings/amulets) | Usually no meaningful chassis (often `Armor Defense Value=0` / `Magic Armor Value=0` on the base template) | Jewellery can still roll numeric boosts, including armour/magic armour via boosts (e.g. `_Boost_Armor_Ring_Armour_Magical` applies `Magic Armor Value=10`, Medium `20`, Large `30`; `_Boost_Armor_Amulet_Secondary_MovementSpeed_*` applies `Movement=50/75/100`) |

- `DeltaModifier.stats` shows the same “boost slot” concept is used across slots (`SlotType` includes boots/helmet/ring/amulet/belt), which strongly suggests “blue stats” are universally boost-driven.
- Armour/jewellery may have **different boost pools**, but the **cap model** (rarity → number of boost slots) remains the same pattern; only the eligible boosts change by `SlotType` and `ModifierType`.

The key idea is always the same:
- Measure a parent’s innate value relative to a **baseline for the same (type, level, rarity)**.
- Merge in **percentile space**.
- Re-apply to the output’s baseline at the player’s level, then clamp to the output band.

### 2.2. Output rules (level/type/rarity)
- **Output level**: always the forger’s level.
  - `Level_out = Level_player`
- **Output type**: always the item in the **first forge slot**.
- **Output rarity**: decided by the **[Rarity System](rarity_system.md)**.
- **Capped result**: the output’s raw numeric values must not exceed what is allowed for the output’s **type + level + rarity**.

### 2.3. Parameters (tuning knobs)
These are the only “balance knobs” you should tune for the numeric chassis merge.

| Parameter | Meaning | Suggested default | Notes |
| :--- | :--- | :---: | :--- |
| `w` | Slot 1 dominance when merging percentiles | **0.70** | Keeps the output feeling like “slot 1’s type”, even cross-type. |
| `conversionLoss` | Donor effectiveness when types differ | See table below | Prevents cross-type budget stealing. |
| `[L_r, H_r]` | Allowed innate numeric roll band for rarity `r` | See band table below | Clamp both parents and output to rarity-appropriate bands. |
| Unique baseline | How to normalise Unique parents | **Use Legendary baseline** | Unique is too bespoke; this is normalisation only. |

##### Suggested conversion-loss table (cross-type safety)
Use this when the two parents are not the same exact weapon type.

| Case | `conversionLoss` | Rationale |
| :--- | :---: | :--- |
| Same weapon type | **1.00** | Safe: no budget conversion needed. |
| Different types, both 1H melee (non-dagger) | **0.85** | Similar budget family; mild loss. |
| 1H ↔ 2H | **0.70** | Stops 2H raw budget from over-influencing 1H. |
| Dagger involved (either side) | **0.60** | Daggers are the easiest exploit vector; stricter loss. |
| Melee ↔ ranged (if you ever allow it) | **0.60** | Different combat patterns; strict loss. |

##### Suggested innate numeric roll bands (shared across equipment for now)
These bands define what “bottom roll” and “top roll” mean for the **innate numeric chassis** at a given rarity.

They are intentionally narrow to keep a vanilla feel (most of the “power” still comes from level + rarity, then blue stats).

| Rarity | `[L_r, H_r]` | Interpretation |
| :--- | :---: | :--- |
| Common | `[0.97, 1.03]` | Small variance only. |
| Uncommon | `[0.97, 1.04]` | Slightly wider. |
| Rare | `[0.96, 1.06]` | Noticeable, still controlled. |
| Epic | `[0.96, 1.07]` | A bit wider. |
| Legendary | `[0.95, 1.08]` | “Good rolls matter”. |
| Divine | `[0.95, 1.09]` | Top-end, still capped. |
| Unique | `[0.95, 1.08]` | Use Legendary band for now (normalisation is already special-cased). |

### 2.4. Measuring innate values (no rune/boost pollution)
When computing a parent’s “base numeric power”, ignore anything that is not part of the item’s innate template.

Specifically, exclude:
- Rune socket effects (already blocked by **1.0 Ingredient eligibility**).
- Any rollable boost-driven effects (anything coming from `DeltaModifier.stats` / `_Boost_*`).
- Any forging-system-injected boosts (your mod’s own “forged” metadata/bonuses).

Practical rule of thumb:
- Do not try to subtract unknown modifiers from a live weapon.
- Instead, compute innate values by using a **boost-free** reference (a stripped clone or a clean spawn of the same template), so the measurement is not contaminated.

### 2.5. Normalisation (q → percentile p)
This converts “how good is this item for its own type/level/rarity” into a stable percentile in \([0,1]\).

#### Definitions (weapons)
For a weapon:
- `D_min`, `D_max`: the displayed physical damage range (or the relevant damage type range if you choose to normalise elemental weapons differently).
- `D_avg = (D_min + D_max) / 2`

For parent weapon `i`:
- `Type_i`: the weapon type (dagger, two-handed axe, etc.).
- `Rarity_i`: item rarity.
- `Level_i`: item level.
- `D_innate_i`: the weapon’s **innate-only** average damage at `Level_i` (boost-free measurement).
- `D_base_i`: a **baseline** innate-only average damage for `(Type_i, Level_i, Rarity_i)` (also boost-free).
- `q_i = D_innate_i / D_base_i`: the parent’s innate-only quality ratio.

Then convert `q_i` into a percentile `p_i` within the allowed “innate damage roll band” for that rarity:

- Choose a band `[L_r, H_r]` per rarity `r` (design parameter; keep bands narrow for vanilla feel).
- `p_i = clamp((q_i - L_r) / (H_r - L_r), 0, 1)`

Interpretation:
- `p_i = 0.0` means “bottom of the allowed innate-damage band for that rarity”.
- `p_i = 1.0` means “top of the allowed innate-damage band for that rarity”.

#### Definitions (shields)
Shields do not have weapon damage; they primarily have:
- `Armour`: `Armor Defense Value`
- `MagicArmour`: `Magic Armor Value`

Treat each numeric channel the same way:
- Compute `q_armour`, `p_armour` using baseline normalisation.
- Compute `q_magic`, `p_magic` likewise.

#### Baseline selection (same rarity baseline, plus the Unique normalisation rule)
You requested “baseline percentile uses the same rarity as the parent”. Use:
- `D_base_i = baseline(Type_i, Level_i, Rarity_i)`

Special case for Unique:
- **Unique baseline = Legendary baseline**, purely for normalisation:
  - If `Rarity_i` is Unique, use `Rarity_base = Legendary` when computing `D_base_i`.
  - This avoids “bespoke Unique templates” making baseline comparisons meaningless.

Note: this does not change the item’s displayed rarity; it only defines the reference curve for normalisation.

### 2.6. Cross-type merging (w + conversionLoss)
Never merge raw damage numbers across types. Merge **percentiles** (or quality ratios) and then re-express the result on the output type’s baseline.

1) Compute `p_1` and `p_2` from the two parents (as above).
2) Apply a “cross-type conversion loss” if the weapon types differ:
   - `conversionLoss = 1.0` if `Type_1 == Type_2`
   - Otherwise `conversionLoss < 1.0` (design parameter) to prevent importing a donor’s strength too efficiently.
3) Weighted merge where slot 1 is dominant:
   - `p_out = clamp(w * p_1 + (1 - w) * p_2 * conversionLoss, 0, 1)`
   - Recommended starting point: `w = 0.70`
4) Convert `p_out` back into an output quality ratio within the output rarity band:
   - `q_out = L_out + p_out * (H_out - L_out)`
5) Re-express at player level on the output type’s baseline:
   - `Level_out = Level_player`
   - `D_base_out = baseline(Type_out, Level_out, Rarity_out)`
   - `D_target_out = D_base_out * q_out`
6) Apply clamping again to guarantee the output stays within the output band.

This achieves your “latter” requirement:
- Players can chase better raw numbers by feeding better-percentile parents.
- But the output is still bounded by the output’s own (type, level, rarity) budget.

#### Step-by-step summary (weapons and shields)
Use this as the “mental model” for the process.

| Step | What you compute | Why |
| :---: | :--- | :--- |
| 1 | Decide output `Type_out` (slot 1), `Rarity_out` (rarity system), `Level_out` (player level) | The output budget is defined here. |
| 2 | Measure each parent’s innate-only numeric value(s) (`D_innate`, or `Armour_innate`/`Magic_innate`) | Avoid boost/rune pollution. |
| 3 | Measure each parent’s baseline numeric value(s) for `(Type_i, Level_i, Rarity_i)` | Defines “what is normal for that parent”. |
| 4 | Convert to quality ratios `q_i = innate/base`, then to percentiles `p_i` using `[L_r, H_r]` | Puts all items on a comparable 0..1 scale. |
| 5 | Merge percentiles into `p_out` (slot 1 weight `w`, cross-type `conversionLoss`) | Prevents cross-type budget stealing. |
| 6 | Convert back to output quality `q_out`, then apply to output baseline at player level | Makes the output “a good roll of its own type”. |
| 7 | Clamp to output band `[L_out, H_out]` | Enforces the “capped by output budget” rule. |

#### Why this avoids exploits (failure modes addressed)
- **Level gap**: because each parent is normalised against its own `(type, level, rarity)` baseline, a level 13 item does not directly inject level 13 raw damage into a level 10 output.
- **Cross-type budget stealing**: the donor only contributes a percentile, and that percentile is re-expressed on the output type’s baseline; a dagger remains “a very good dagger”, not “a dagger with two-handed damage”.
- **Boost leakage**: by measuring `D_innate` and `D_base` using boost-free references, you do not accidentally include DeltaModifier boosts, runes, or mod-injected effects.

### 2.7. Worked examples (tables)
All numbers below are illustrative; the structure and clamping rules are what matter.

##### Example 1: Same type weapon (simple case)
Player level is 10. Both parents are Rare daggers (slot 1 decides output type: dagger). Output is level 10 Rare dagger.

Assume the Rare band is `[L_r, H_r] = [0.96, 1.06]`, and `w = 0.70`.

| Value | Slot 1 parent (Rare dagger, level 10) | Slot 2 parent (Rare dagger, level 10) |
| :--- | ---: | ---: |
| `D_innate` | 23.0 | 25.2 |
| `D_base` | 24.0 | 24.0 |
| `q = D_innate / D_base` | 0.958 | 1.050 |
| `p = clamp((q - 0.96) / 0.10)` | 0.00 | 0.90 |

Merge (same type → `conversionLoss = 1.00`):
- `p_out = clamp(0.70 * 0.00 + 0.30 * 0.90 * 1.00) = 0.27`
- `q_out = 0.96 + 0.27 * 0.10 = 0.987`
- Output baseline (player level): `D_base_out = baseline(dagger, 10, Rare) = 24.0`
- `D_target_out = 24.0 * 0.987 = 23.69`

Interpretation:
- The output becomes a level 10 Rare dagger that is slightly below average in innate damage (because slot 1’s innate roll was poor and slot 1 dominates).

##### Example 2: Cross-type + big level gap (the “why normalisation exists” case)
Player level is 10. Slot 1 is a Rare dagger (level 13). Slot 2 is a Rare two-handed axe (level 6). Output is level 10 Rare dagger.

Assume Rare band `[0.96, 1.06]`, `w = 0.70`, and because types differ (and dagger is involved) `conversionLoss = 0.60`.

| Value | Slot 1 parent (Rare dagger, level 13) | Slot 2 parent (Rare 2H axe, level 6) |
| :--- | ---: | ---: |
| `D_innate` | 26.0 | 18.0 |
| `D_base` | 24.0 | 20.0 |
| `q = D_innate / D_base` | 1.083 | 0.900 |
| `p = clamp((q - 0.96) / 0.10)` | 1.00 | 0.00 |

Merge (cross-type):
- `p_out = clamp(0.70 * 1.00 + 0.30 * 0.00 * 0.60) = 0.70`
- `q_out = 0.96 + 0.70 * 0.10 = 1.03`
- Output baseline is at player level: `D_base_out = baseline(dagger, 10, Rare) = 24.0`
- `D_target_out = 24.0 * 1.03 = 24.72`

Interpretation:
- The level 13 dagger does not “force” a level 13 output; it only contributes that it was a high-quality dagger for its own baseline.
- The level 6 axe cannot inject two-handed raw budget into a dagger because its contribution is percentile-based and conversion-limited.

##### Example 3: Shields (two numeric channels)
Player level is 12. Both parents are Rare shields (slot 1 decides output type: shield). Output is a level 12 Rare shield.

Use the same Rare band `[0.96, 1.06]`, `w = 0.70`, `conversionLoss = 1.00` (same type family).

Assume these are the boost-free baselines for a Rare shield at level 12:
- `Armour_base_out = 150`
- `Magic_base_out = 120`

Compute per-channel percentiles:

| Channel | Slot 1 `innate` | Slot 1 `base` | Slot 1 `p` | Slot 2 `innate` | Slot 2 `base` | Slot 2 `p` |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: |
| Armour | 160 | 150 | 1.00 | 150 | 150 | 0.40 |
| Magic armour | 110 | 120 | 0.00 | 132 | 120 | 1.00 |

Merge per channel:
- Armour:
  - `p_out = 0.70 * 1.00 + 0.30 * 0.40 = 0.82`
  - `q_out = 0.96 + 0.82 * 0.10 = 1.042`
  - `Armour_target_out = 150 * 1.042 = 156.3`
- Magic armour:
  - `p_out = 0.70 * 0.00 + 0.30 * 1.00 = 0.30`
  - `q_out = 0.96 + 0.30 * 0.10 = 0.99`
  - `Magic_target_out = 120 * 0.99 = 118.8`

Interpretation:
- Slot 1 heavily influences both channels.
- You can “mix and match” a parent that is good on armour with a parent that is good on magic armour, but the result is still capped within Rare expectations.

---

## 3. Blue stat modifiers inheritance

### 3.1. Modifier cap for each rarity
Defined by the **[Rarity System](rarity_system.md)**:

| Rarity ID | Name | Max stat slots (this mod) | Vanilla rollable boost slots (non-rune) |
| :--- | :--- | :--- | :--- |
| **1** | Common | **1** | 0..0 |
| **2** | Uncommon | **4** | 2..4 |
| **3** | Rare | **5** | 3..5 |
| **4** | Epic | **6** | 4..6 |
| **5** | Legendary | **7** | 4..6 |
| **6** | Divine | **8** | 5..7 |
| **8** | Unique | **10** | 0..0 |

**Example:**  
A shield can appear at different rarities too.  
- If the shield is **Rare** (Rarity ID 3), it can have up to **5 blue stats** (for example: `Blocking +15`, `+2 Constitution`, `+1 Warfare`, `+10% Fire Resistance`, `+1 Retribution`).  
  - Vanilla reference: `Shield.stats` defines `_Boost_Shield_Special_Block_Shield_*` boosts that apply the `Blocking` stat (e.g. `Blocking=10/15/20`).
- If the same shield is **Epic** (Rarity ID 4), it can have up to **6 blue stats**.

### 3.2. The two stat lists
- **Shared stats (S)**: stats on **both** parents (guaranteed).
- **Pool stats (P)**: stats that are **not shared** (unique to either parent). This is the combined pool from both parents.

#### Key values

- **S (Shared stats)**: stat lines both parents share (always carried over).
- **P (Pool stats)**: stat lines not shared (all unique lines from both parents combined).
- **E (Expected baseline)**: your starting pool pick count (baseline picks from the pool).
  - Default rule: $E = \lceil P / 2 \rceil$ (half the pool, rounded up).
  - Special case: if **P = 1**, use **E = 0** (this enables a clean 50/50 keep-or-lose roll for a single pool stat).
- **V (Luck adjustment/variance)**: the luck result that nudges E up/down (can chain).
- **K (Stats from pool)**: how many you actually take from the pool (after luck adjustment, limited to 0–P).
- **T (Planned total)**: planned stat lines before the rarity cap.
- **Cap**: the max stat slots from rarity.
- **Final**: stat lines after the cap is applied.

---
**Two rules define inheritance:**
- [Merging rule](#33-merging-rule-how-numbers-are-merged)
- [Selection rule](#34-selection-rule-shared--pool--cap)

### 3.3. Merging rule (how numbers are merged)

Sometimes both parents have the **same stat**, but the **numbers** are different:
- `+10% Critical Chance` vs `+14% Critical Chance`
- `+3 Strength` vs `+4 Strength`

In this system, those are still treated as **Shared stats (S)** (same stat **key**), but the forged item will roll a **merged value** for that stat.

Slot note:
- These “blue stat” keys are not limited to weapons/shields. Armour/jewellery can roll numeric blue stats too, for example:
  - Movement speed via `_Boost_Armor_Boots_Secondary_MovementSpeed` (applies `Movement=50`, Medium `75`, Large `100`)
  - Initiative via `_Boost_Armor_Belt_Secondary_Initiative` (applies `Initiative=2`, Medium `4`, Large `6`)

#### Definitions
- **Stat key**: the identity of the stat (e.g. `CriticalChance`, `Strength`). This ignores the number.
- **Stat value**: the numeric magnitude (e.g. `10`, `14`, `3`, `4`).

#### Merge formula (RPG-style)

Given parent values $a$ and $b$ for the same stat key:

1. **Midpoint (baseline):**

$$m = (a + b) / 2$$

2. **Roll type chances:**

| Roll type | Chance | Multiplier |
| :--- | :---: | :--- |
| Tight (less volatile) | **50%** | $r \sim Tri(0.85,\ 1.00,\ 1.15)$ |
| Wide (more volatile) | **50%** | $r \sim Tri(0.70,\ 1.00,\ 1.30)$ |

3. **Clamp the result (allowed min/max range):**

$$lo = \min(a,b)\times 0.85$$
$$hi = \max(a,b)\times 1.15$$

4. **Final merged value:**

$$value = clamp(m \times r,\ lo,\ hi)$$

Then format the number back into a stat line using the stat’s rounding rules.

#### Rounding rules
- **Integer stats** (Attributes, skill levels): round to the nearest integer.
- **Percent stats** (Critical Chance, Accuracy, Resistances, “X% chance to set Y”): round to the nearest integer percent.

#### Worked examples

**Example A: `+10%` vs `+14%` Critical Chance**
- $a=10,\ b=14 \Rightarrow m=12$
- $lo = 8.5,\ hi = 16.1$
- Tight roll range is $12 \times [0.85, 1.15] = [10.2, 13.8]$ → roughly **10%–14%** after rounding.
- Wide roll range is $12 \times [0.70, 1.30] = [8.4, 15.6]$ → **9%–16%** after rounding (low end clamps to 8.5).

**Example B (shield): `Blocking +10` vs `Blocking +15`**
- $a=10,\ b=15 \Rightarrow m=12.5$
- $lo = 8.5,\ hi = 17.25$
- Tight roll gives roughly **11–14** after rounding.
- Wide roll can reach roughly **9–16** after rounding:
  - Low end: $m \times 0.70 = 8.75$ (already above $lo=8.5$) → rounds to **9**
  - High end: $m \times 1.30 = 16.25$ (below $hi=17.25$) → rounds to **16**

**Example C: `+3` vs `+4` Strength (small integers can still spike)**
- $a=3,\ b=4 \Rightarrow m=3.5$
- $lo = 2.55,\ hi = 4.6$
- Tight roll range: $3.5 \times [0.85, 1.15] = [2.975, 4.025]$ → **3–4** after rounding.
- Wide roll range: $3.5 \times [0.70, 1.30] = [2.45, 4.55]$ → **3–5** after rounding (high end is close to 5, and the clamp allows up to 4.6).

**Example D: `+1` vs `+7` Strength (large gaps merge towards the middle)**
- $a=1,\ b=7 \Rightarrow m=4$
- $lo = 0.85,\ hi = 8.05$
- Tight roll range: $4 \times [0.85, 1.15] = [3.4, 4.6]$ → **3–5** after rounding.
- Wide roll range: $4 \times [0.70, 1.30] = [2.8, 5.2]$ → **3–5** after rounding.

#### Quick “one forge” walk-through (shows what the 50% wide-roll chance means)
Using Example A (`+10%` vs `+14%` Critical Chance):

| Step | Roll | Calculation | Result (rounded) |
| :---: | :--- | :--- | :--- |
| 1 | Choose roll type | 50% tight vs 50% wide | Tight or Wide |
| 2A | Wide case | `r=1.22` → `value = clamp(12×1.22, 8.5, 16.1) = 14.64` | `15%` |
| 2B | Tight case | `r=0.90` → `value = clamp(12×0.90, 8.5, 16.1) = 10.8` | `11%` |

---
### 3.4. Selection rule (shared + pool + cap)

Now that **Shared stats (S)** includes the value-merge behaviour above (same stat key, merged number if needed), the next step:
- Count how many shared stats you have (**S**).
- Put everything else into the pool (**P**).
- Roll how many pool stats you keep (**K**) and apply the rarity cap.

These are the same rules as above, written as formulas:

For the expected baseline (**make non-shared stats harder to keep**):

$$E =
\begin{cases}
0 & \text{if } P = 0 \text{ or } P = 1 \\
\lfloor (P + 1) / 3 \rfloor & \text{otherwise}
\end{cases}
$$

Then:

$$K = \min(\max(E + V,\ 0),\ P)$$

$$T = S + K$$

$$Final = \min(T,\ Cap)$$
### Step 1: Separate shared vs pool stats
Compare the two parents:
- For all the **shared stats** from both items (same stat **key**), put into **Shared stats (S)**.
  - If the values differ, use the **value merge** rules in **3.3** to roll the merged number for the forged item.
- For all the **non-shared stats** from both items, put into **Pool stats (P)**.

### Step 2: Set the expected baseline (E)
Now work out your starting point for the pool.
You begin at **about one-third of the pool**, rounded down (this is the “expected baseline”, E). This makes **non-shared** stats noticeably harder to keep, while **shared** stats remain stable.

Examples:
- Pool size 1 → baseline is 0 (then you 50/50 roll to keep it or lose it)
- Pool size 3 → expect to keep 1
- Pool size 4 → expect to keep 1
- Pool size 7 → expect to keep 2
- Pool size 12 → expect to keep 4

### Step 3: Choose the tier (sets luck odds)
The tier depends only on **pool size**:

| Pool size | Tier | First roll chances (Bad / Neutral / Good) | Chain chance (Down / Up) |
| :--- | :--- | :--- | :--- |
| **1** | Tier 1 (Safe) | 0% / 50% / 50% | None |
| **2–4** | Tier 2 (Early) | 12% / 50% / 38% | 12% / 22% |
| **5–7** | Tier 3 (Mid) | 28% / 50% / 22% | 28% / 30% |
| **8+** | Tier 4 (Risky) | 45% / 40% / 15% | 45% / 30% |

### Step 4: Roll the luck adjustment (can chain)
The system rolls a **luck adjustment** which is essentially a **variance** that gets added to the expected baseline **E**, which changes how many pool stats you keep:

- **Bad roll**: you try to keep 1 fewer, and you may chain further down.
- **Neutral roll**: you keep the expected amount (no change).
- **Good roll**: you try to keep 1 more, and you may chain further up.

**Safety rule (always true):** you can’t keep fewer than **0** pool stats, and you can’t keep more than the **pool size**.

Multiplayer note:
- This luck roll (and the later random selection of which pool stats you actually take) should be rolled **host-authoritatively** and driven by the forge’s deterministic seed (`forgeSeed`), for consistency.

### Step 5: Build the result and apply the cap
1. **Plan total stats**:
   - Total stats = number of shared stats + number of pool stats kept
2. **Build the list**:
   - Start with all **shared stats**, then add that many random stats from the **pool**.
3. **Apply the cap last**:
   - If the total is above the item’s **max stat slots**, remove extra stats until you reach the limit (remove pool-picked stats first).

Imagine you’re forging these two **boots** (boots can only forge with boots):

```
Parent A: Ranger’s Boots
 - +1 Finesse
 - +0.5m Movement
 - +10% Fire Resistance
 - +1 Sneaking

Parent B: Scout’s Boots
 - +1 Finesse
 - +0.5m Movement
 - +2 Initiative
 - +10% Air Resistance
```

Split into lists:
- Shared stats (on both): `+1 Finesse`, `+0.5m Movement` → **S = 2**
- Pool stats (not shared): `+10% Fire Resistance`, `+1 Sneaking`, `+2 Initiative`, `+10% Air Resistance` → **P = 4**

Now calculate how many pool stats you keep:
- Expected baseline: **E = floor((P + 1) / 3) = floor(5 / 3) = 1**
- Suppose your luck adjustment roll comes out as **V = +1**
- Pool stats kept (from the pool): **K = clamp(E + V, 0, P) = clamp(1 + 1, 0, 4) = 2**
- Planned total before cap: **T = S + K = 2 + 2 = 4**

Finally apply the rarity cap:
- Assume the rarity system gives the new item **Rare** → **Cap = 5**
- Final total: **Final = min(T, Cap) = min(4, 5) = 4**

So you end up with:
- The 2 shared stats (always)
- Plus 2 of the pool stats (no trimming needed in this example)

---

### Examples

The tables below are examples only. They apply the formulas above to show what you can roll in each pool-size tier.

### Safe vs YOLO forging (intuition extremes)

These two standalone examples are meant to build intuition:
- **Safe forging**: many shared stats → stable outcomes (pool stats are just “bonus”).
- **YOLO forging**: zero shared stats → pure variance (rare spikes are possible, but unreliable).

**Safe Forging (Pool size = 2, 2× Divine items with high shared stats):**
```
Item A: Divine Warhammer
 - +3 Strength
 - +2 Warfare
 - +15% Critical Chance
 - +20% Fire Resistance
 - +20% Poison Resistance
 - +2 Constitution
 - +1 Leadership
 - +1 Persuasion

Item B: Divine Warhammer
 - +3 Strength
 - +2 Warfare
 - +15% Critical Chance
 - +20% Fire Resistance
 - +20% Poison Resistance
 - +2 Constitution
 - +1 Leadership
 - +1 Bartering
─────────────────────────────────────────
Shared stats:
 - +3 Strength
 - +2 Warfare
 - +15% Critical Chance
 - +20% Fire Resistance
 - +20% Poison Resistance
 - +2 Constitution
 - +1 Leadership
Pool stats:
 - +1 Persuasion
 - +1 Bartering
```

Inputs for this example:
- **Shared stats (S):** 7
- **Pool size (P):** 2
- **Expected baseline (E):** floor((P + 1) / 3) = floor(3 / 3) = 1
- **Rarity:** Divine for both

This is the perfect example for **Safe Forging**:
- With **7 shared stats**, you’re already very close to the Divine cap (8). The pool only adds 0–2 more stats, so even losing all pool stats still gives you a near-max item.

| Luck adjustment<br>(A) | Stats from pool<br>(K) | Forged item stats<br>(T) | Chance<br>(math) | Chance |
| :---: | :---: | :---: | :---: | :---: |
| -1 | 0 | 7 | 12% (cap) | **12.00%** |
| 0 | 1 | 8 | 50% | **50.00%** |
| +1 | 2 | 9 | 38% × 78% | **29.64%** |
| +2 | 2 | 9 | 38% × 22% (cap) | **8.36%** |

After applying the **Divine cap (8)**:
- **T = 7** → Final = 7 (no trimming)
- **T = 8** → Final = 8 (at cap)
- **T = 9** → Final = 8 (trim 1 pool stat)

Chance to end with a **Divine item with 8 stats** (Final = 8):
- `P(T >= 8) = P(A = 0) + P(A = +1) + P(A = +2) = 50% + 29.64% + 8.36% = 88%`

**Key insight:** With **very high shared stats (7)**, you’re guaranteed a near-max item even if you lose all pool stats.

**YOLO forging (Common + Divine, 0 shared, everything in the pool):**
```
Item A: Divine Warhammer (8 stats)
 - +3 Strength
 - +2 Warfare
 - +2 Two-Handed
 - +15% Critical Chance
 - +15% Accuracy
 - +20% Fire Resistance
 - +20% Poison Resistance
 - +2 Constitution

Item B: Common Warhammer (1 stat)
 - +1 Aerotheurge
─────────────────────────────────────────
Shared stats:
 (none)
Pool stats:
 - +3 Strength
 - +2 Warfare
 - +2 Two-Handed
 - +15% Critical Chance
 - +15% Accuracy
 - +20% Fire Resistance
 - +20% Poison Resistance
 - +2 Constitution
 - +1 Aerotheurge
```

Inputs for this example:
- **Shared stats (S):** 0
- **Pool size (P):** 9
- **Expected baseline (E):** floor((P + 1) / 3) = floor(10 / 3) = 3
- **Tier used:** Tier 4 odds (because `P = 9` is `8+`)
- **Assume output rarity:** Divine

This is the perfect example for **YOLO forging**:
- With **0 shared stats**, you have **no guarantees**. Everything is a roll from the pool.
- You can still (rarely) hit a “full” Divine statline (Final = 8), but it requires multiple good chains.

| Luck adjustment<br>(A) | Stats from pool<br>(K) | Forged item stats<br>(T) | Chance<br>(math) | Chance |
| :---: | :---: | :---: | :---: | :---: |
| -3 | 0 | 0 | 45% × (45%)^2 (cap) | **9.11%** |
| -2 | 1 | 1 | 45% × 45% × 55% | **11.14%** |
| -1 | 2 | 2 | 45% × 55% | **24.75%** |
| 0 | 3 | 3 | 40% | **40.00%** |
| +1 | 4 | 4 | 15% × 70% | **10.50%** |
| +2 | 5 | 5 | 15% × 30% × 70% | **3.15%** |
| +3 | 6 | 6 | 15% × (30%)^2 × 70% | **0.95%** |
| +4 | 7 | 7 | 15% × (30%)^3 × 70% | **0.28%** |
| +5 | 8 | 8 | 15% × (30%)^4 × 70% | **0.09%** |
| +6 | 9 | 9 | 15% × (30%)^5 (cap) | **0.04%** |

After applying the **Divine cap (8)**:
- **T = 0–7** → Final = T
- **T = 8** → Final = 8 (at cap)
- **T = 9** → Final = 8 (trim 1 pool stat)

Chance to end with a **Divine item with 8 stats** (Final = 8):
- `P(T ≥ 8) = P(A = +5) + P(A = +6) = 0.09% + 0.04% ≈ 0.12%`

**Key insight:** YOLO forging can still “spike” into a full Divine statline, but it’s intentionally **very rare** when you have **0 shared stats**.

### Tier 1 (Pool size = 1, no chains)

**Example 1:**
```
Item A: Traveller’s Amulet
 - +1 Aerotheurge
 - +0.5m Movement

Item B: Scout’s Amulet
 - +1 Aerotheurge
─────────────────────────────────────────
Shared stats:
 - +1 Aerotheurge
Pool stats:
 - +0.5m Movement
```

Inputs for this example:
- **Shared stats (S):** 1
- **Pool size (P):** 1
- **Expected baseline (E):** 0  *(special case for P = 1)*

| Luck adjustment<br>(A) | Stats from pool<br>(K) | Forged item stats<br>(T) | Chance<br>(math) | Chance |
| :---: | :---: | :---: | :---: | :---: |
| 0 | 0 | 1 | 50% (cap) | **50.00%** |
| +1 | 1 | 2 | 50% (cap) | **50.00%** |

### Tier 2 (Pool size = 2–4)

**Example 1 (Pool size = 3):**
```
Item A: Mage’s Helmet
 - +2 Intelligence
 - +10% Fire Resistance
 - +1 Loremaster

Item B: Scholar’s Helmet
 - +2 Intelligence
 - +10% Water Resistance
─────────────────────────────────────────
Shared stats:
 - +2 Intelligence
Pool stats:
 - +10% Fire Resistance
 - +1 Loremaster
 - +10% Water Resistance
```

Inputs for this example:
- **Shared stats (S):** 1
- **Pool size (P):** 3
- **Expected baseline (E):** floor((P + 1) / 3) = floor(4 / 3) = 1

Before the rarity cap, the forged item ends up with between **1** and **4** stats (**1** shared + **0–3** from the pool).

| Luck adjustment<br>(A) | Stats from pool<br>(K) | Forged item stats<br>(T) | Chance<br>(math) | Chance |
| :---: | :---: | :---: | :---: | :---: |
| -1 | 0 | 1 | 12% (cap) | **12.00%** |
| 0 | 1 | 2 | 50% | **50.00%** |
| +1 | 2 | 3 | 38% × 78% | **29.64%** |
| +2 | 3 | 4 | 38% × 22% (cap) | **8.36%** |

**Example 2 (Pool size = 4, weapon-only cross-subtype allowed):**
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
Shared stats:
 - +1 Warfare
 - +10% Critical Chance
Pool stats:
 - +1 Finesse
 - +2 Initiative
 - +12% Fire Resistance
 - 10% chance to set Bleeding
```

Inputs for this example:
- **Shared stats (S):** 2
- **Pool size (P):** 4
- **Expected baseline (E):** floor((P + 1) / 3) = floor(5 / 3) = 1

Before the rarity cap, the forged item ends up with between **2** and **6** stats (**2** shared + **0–4** from the pool).

| Luck adjustment<br>(A) | Stats from pool<br>(K) | Forged item stats<br>(T) | Chance<br>(math) | Chance |
| :---: | :---: | :---: | :---: | :---: |
| -1 | 0 | 2 | 12% (cap) | **12.00%** |
| 0 | 1 | 3 | 50% | **50.00%** |
| +1 | 2 | 4 | 38% × 78% | **29.64%** |
| +2 | 3 | 5 | 38% × 22% × 78% | **6.54%** |
| +3 | 4 | 6 | 38% × (22%)^2 (cap) | **1.84%** |
### Tier 3 (Pool size = 5–7)

**Example 1 (Pool size = 5):**
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
Shared stats:
 - +1 Finesse
 - +0.5m Movement
Pool stats:
 - +2 Initiative
 - +10% Fire Resistance
 - +1 Sneaking
 - +10% Air Resistance
 - +10% Earth Resistance
```

Inputs for this example:
- **Shared stats (S):** 2
- **Pool size (P):** 5
- **Expected baseline (E):** floor((P + 1) / 3) = floor(6 / 3) = 2

Before the rarity cap, the forged item ends up with between **2** and **7** stats (**2** shared + **0–5** from the pool).

| Luck adjustment<br>(A) | Stats from pool<br>(K) | Forged item stats<br>(T) | Chance<br>(math) | Chance |
| :---: | :---: | :---: | :---: | :---: |
| -2 | 0 | 2 | 28% × 28% (cap) | **7.84%** |
| -1 | 1 | 3 | 28% × 72% | **20.16%** |
| 0 | 2 | 4 | 50% | **50.00%** |
| +1 | 3 | 5 | 22% × 70% | **15.40%** |
| +2 | 4 | 6 | 22% × 30% × 70% | **4.62%** |
| +3 | 5 | 7 | 22% × (30%)^2 (cap) | **1.98%** |

**Example 2 (Pool size = 7):**
```
Item A: Enchanted Greatsword
 - +1 Strength
 - +1 Warfare
 - +10% Critical Chance
 - +1 Two-Handed
 - +15% Accuracy
 - +2 Strength
 - +1 Necromancer
 - 10% chance to set Bleeding

Item B: Champion’s Greatsword
 - +1 Strength
 - +1 Warfare
 - +12% Fire Resistance
 - +1 Pyrokinetic
 - +1 Aerotheurge
 - +1 Huntsman
 - 10% chance to set Blinded
 - 10% chance to set Silenced
─────────────────────────────────────────
Shared stats:
 - +1 Strength
 - +1 Warfare
Pool stats:
 - +10% Critical Chance
 - +1 Two-Handed
 - +15% Accuracy
 - +2 Strength
 - +1 Necromancer
 - 10% chance to set Bleeding
 - +12% Fire Resistance
 - +1 Pyrokinetic
 - +1 Aerotheurge
 - +1 Huntsman
 - 10% chance to set Blinded
 - 10% chance to set Silenced
```

Inputs for this example:
- **Shared stats (S):** 2
- **Pool size (P):** 7
- **Expected baseline (E):** floor((P + 1) / 3) = floor(8 / 3) = 2

Before the rarity cap, the forged item ends up with between **2** and **9** stats (**2** shared + **0–7** from the pool).

| Luck adjustment<br>(A) | Stats from pool<br>(K) | Forged item stats<br>(T) | Chance<br>(math) | Chance |
| :---: | :---: | :---: | :---: | :---: |
| -2 | 0 | 2 | 28% × 28% (cap) | **7.84%** |
| -1 | 1 | 3 | 28% × 72% | **20.16%** |
| 0 | 2 | 4 | 50% | **50.00%** |
| +1 | 3 | 5 | 22% × 70% | **15.40%** |
| +2 | 4 | 6 | 22% × 30% × 70% | **4.62%** |
| +3 | 5 | 7 | 22% × (30%)^2 × 70% | **1.39%** |
| +4 | 6 | 8 | 22% × (30%)^3 × 70% | **0.42%** |
| +5 | 7 | 9 | 22% × (30%)^4 (cap) | **0.18%** |

### Tier 4 (Pool size = 8+)

**Example 1 (Pool size = 12):**
```
Item A: Tower Shield
 - +2 Constitution
 - Blocking +15
 - +2 Initiative
 - +10% Fire Resistance
 - +10% Water Resistance
 - +10% Air Resistance
 - +20% Poison Resistance
 - +1 Strength

Item B: Kite Shield
 - Blocking +15
 - +10% Fire Resistance
 - +10% Earth Resistance
 - +1 Leadership
 - +1 Persuasion
 - +0.5m Movement
 - +1 Bartering
 - +1 Loremaster
─────────────────────────────────────────
Shared stats:
 - Blocking +15
 - +10% Fire Resistance
Pool stats:
 - +2 Constitution
 - +2 Initiative
 - +1 Strength
 - +10% Water Resistance
 - +10% Air Resistance
 - +20% Poison Resistance
 - +10% Earth Resistance
 - +1 Leadership
 - +1 Persuasion
 - +0.5m Movement
 - +1 Bartering
 - +1 Loremaster
```

Inputs for this example:
- **Shared stats (S):** 2
- **Pool size (P):** 12
- **Expected baseline (E):** floor((P + 1) / 3) = floor(13 / 3) = 4

Before the rarity cap, the forged item ends up with between **2** and **14** stats (**2** shared + **0–12** from the pool).
  - This is “riskier crafting” in practice: fewer shared stats means more “unknown” stats in the pool.

| Luck adjustment<br>(A) | Stats from pool<br>(K) | Forged item Stats<br>(T) | Chance<br>(math) | Chance |
| :---: | :---: | :---: | :---: | :---: |
| -4 | 0 | 2 | 45% × (45%)^3 (cap) | **4.10%** |
| -3 | 1 | 3 | 45% × (45%)^2 × 55% | **5.01%** |
| -2 | 2 | 4 | 45% × 45% × 55% | **11.14%** |
| -1 | 3 | 5 | 45% × 55% | **24.75%** |
| 0 | 4 | 6 | 40% | **40.00%** |
| +1 | 5 | 7 | 15% × 70% | **10.50%** |
| +2 | 6 | 8 | 15% × 30% × 70% | **3.15%** |
| +3 | 7 | 9 | 15% × (30%)^2 × 70% | **0.95%** |
| +4 | 8 | 10 | 15% × (30%)^3 × 70% | **0.28%** |
| +5 | 9 | 11 | 15% × (30%)^4 × 70% | **0.09%** |
| +6 | 10 | 12 | 15% × (30%)^5 × 70% | **0.03%** |
| +7 | 11 | 13 | 15% × (30%)^6 × 70% | **0.01%** |
| +8 | 12 | 14 | 15% × (30%)^7 (cap) | **0.03%** |

---
## 4. Granted skill inheritance
This section adds **granted skills** as a **separate inheritance channel** from normal “blue stats”.

- **Vanilla-aligned caps**: skills are tightly capped by rarity (Epic 1, Legendary 1, Divine 2).
- **Separate from stat slots**: granted skills do **not** consume your normal **Max stat slots (this mod)**.
- **Stable randomness**: selection/trimming is **random but seeded per forge**, so it is stable for that forge.
- **Multiplayer consistency**: use the same `forgeSeed` approach as stats, and roll skills **host-authoritatively** (clients receive the final result).

### 4.1. Granted skills (definition)

- **Granted skill (rollable)**: any rollable boost/stat line that grants entries via a `Skills` field in its boost definition.
  - Weapon example: `_Boost_Weapon_Skill_Whirlwind` → `Shout_Whirlwind`
  - Shield example: `_Boost_Shield_Skill_BouncingShield` → `Projectile_BouncingShield`
  - Armour/jewellery example: `_Boost_Armor_Gloves_Skill_Restoration` → `Target_Restoration` (defined in `Armor.stats`)
- **Not a granted skill (innate)**: a `Skills` entry baked into the base weapon stat entry (not a rolled boost), e.g. staff base skills like `Projectile_StaffOfMagus` (**innate-only; never enters `poolSkills`**).

**Vanilla scope note:**
- Only treat **`BoostType="Legendary"`** skill boosts as “vanilla rarity-roll skills”.
- Ignore **`BoostType="ItemCombo"`** skill boosts for vanilla-aligned behaviour.

#### Item-type constraints (hard rule for skill inheritance)
- **Weapon can only forge with weapon**, and **shield can only forge with shield**.
- Therefore:
  - A **weapon** must only ever roll/inherit **weapon skill boosts**.
  - A **shield** must only ever roll/inherit **shield skill boosts**.
- If you ever encounter “mixed” skills in runtime data, treat that as invalid input (or ignore the mismatched skill boosts).

### 4.2. Skill cap by rarity

This is the maximum number of **granted skills** on the forged item:

| Rarity ID | Name | Granted skill cap |
| :--- | :--- | :---: |
| **1** | Common | **0** |
| **2** | Uncommon | **0** |
| **3** | Rare | **0** |
| **4** | Epic | **1** |
| **5** | Legendary | **1** |
| **6** | Divine | **2** |
| **8** | Unique | **3** |

### 4.3. Shared vs pool skills

Split granted skills into two lists:

- **Shared skills (Sₛ)**: granted skills present on **both** parents (kept unless we must trim due to cap overflow).
- **Pool skills (Pₛ)**: granted skills present on **only one** parent (rolled).

#### Skill identity (dedupe key)
Use the **skill ID** as the identity key (e.g. `Shout_Whirlwind`, `Projectile_BouncingShield`), not the boost name.

### 4.4. How skills are gained (gated fill)

Skills are **more precious than stats**, so the skill channel does **not** use the stat-style “keep half the pool” baseline.

Instead, skills use a **cap + gated fill** model:
- **Shared skills are protected** (kept first).
- You only try to gain skills for **free skill slots** (up to the rarity skill cap).
- The chance to gain a skill **increases with pool size** (`P_remaining`).

#### Key values (skills)
- **Sₛ**: number of shared rollable skills (present on both parents).
- **Pₛ**: number of pool rollable skills (present on only one parent).
- **SkillCap**: from Section 4.2.
- **FreeSlots**: `max(0, SkillCap - min(Sₛ, SkillCap))`

#### Gain chance model (rarity + pool size)
We define a per-attempt gain chance:

`p_attempt = base(rarity) * m(P_remaining)`

Where:
- `base(Epic) = 25%`
- `base(Legendary) = 25%`
- `base(Divine) = 28%`

And the pool-size multiplier is:

| `P_remaining` | `m(P_remaining)` |
| :---: | :---: |
| 1 | 1.0 |
| 2 | 1.4 |
| 3 | 1.6 |
| 4+ | 2.4 |

So the actual per-attempt gain chances are:

| Output rarity | `P_remaining=1` | `P_remaining=2` | `P_remaining=3` | `P_remaining=4+` |
| :--- | :---: | :---: | :---: | :---: |
| Epic | 25.0% | 35.0% | 40.0% | 60.0% |
| Legendary | 25.0% | 35.0% | 40.0% | 60.0% |
| Divine | 28.0% | 39.2% | 44.8% | 67.2% |

#### Seeded, stable-per-forge randomness
All randomness in this section must be driven by a single forge seed:

- **forgeSeed**: generated once per forge operation, and used to seed a deterministic PRNG for:
  - shuffling/choosing pool skills,
  - trimming when over cap.

This makes outcomes random, but **stable for that forge** (deterministic for multiplayer + debugging).

Notes:
- **Host-authoritative**: the host/server should be the only machine that rolls this seeded randomness. Clients should receive the final skills/stats result from the host.
- **Save/load fishing**: if `forgeSeed` changes each attempt, a player can save before forging and reload to try for different outcomes. Seeding alone does not prevent that unless `forgeSeed` is also stable across reload for the same pre-forge state.

### 4.5. Overflow + replace (5%)

1. Build `sharedSkills` (deduped) and `poolSkills` (deduped).
2. Keep shared first:
   - `finalSkills = sharedSkills` (trim down to `SkillCap` only if shared exceeds cap; use seeded trimming).
3. Compute `freeSlots = SkillCap - len(finalSkills)`.
4. Fill free slots with gated gain rolls (seeded):
   - For each free slot (at most `freeSlots` attempts):
     - Let `P_remaining = len(poolSkills)`
     - Roll a seeded random number; success chance is `p_attempt = base(rarity) * m(P_remaining)` (Section 4.4).
     - If success: pick 1 random skill from `poolSkills` (seeded), add to `finalSkills`, remove it from `poolSkills`, and decrement `freeSlots`.
     - If failure: do nothing for that slot (skills are precious; you do not retry the same slot).
5. Optional “replace” roll (seeded): **5% chance**
   - If `poolSkills` is not empty and `finalSkills` is not empty:
     - With 5% chance, replace 1 random skill in `finalSkills` with 1 random skill from remaining `poolSkills` (both seeded).

### 4.6. Scenario tables

These tables show the probability of ending with **0 / 1 / 2 rollable granted skills** under this skill model.

Notes:
- These tables focus on **skill count outcomes** from the “gated fill” rules above.
- They **ignore the optional 5% replace roll**, because replace mainly changes *which* skill you have, not the cap itself.
- Weapon pools only contain weapon skills; shield pools only contain shield skills.

#### Scenario A: `Sₛ = 0`, `Pₛ = 1`

Weapon example pool: `{Projectile_SkyShot}`
Shield example pool: `{Projectile_BouncingShield}`

| Output rarity | Final 0 skills | Final 1 skill | Final 2 skills |
| :--- | ---: | ---: | ---: |
| Epic (cap 1) | **75.0%** | **25.0%** | 0% |
| Legendary (cap 1) | **75.0%** | **25.0%** | 0% |
| Divine (cap 2) | **51.84%** | **48.16%** | 0% |

#### Scenario B: `Sₛ = 0`, `Pₛ = 2`

Weapon example pool: `{Projectile_SkyShot, Target_SerratedEdge}`
Shield example pool: `{Projectile_BouncingShield, Shout_Taunt}`

| Output rarity | Final 0 skills | Final 1 skill | Final 2 skills |
| :--- | ---: | ---: | ---: |
| Epic (cap 1) | **65.0%** | **35.0%** | 0% |
| Legendary (cap 1) | **65.0%** | **35.0%** | 0% |
| Divine (cap 2) | **36.97%** | **52.06%** | **10.98%** |

#### Scenario C: `Sₛ = 0`, `Pₛ = 3`

Weapon example pool: `{Shout_Whirlwind, Projectile_SkyShot, Target_SerratedEdge}`

| Output rarity | Final 0 skills | Final 1 skill | Final 2 skills |
| :--- | ---: | ---: | ---: |
| Epic (cap 1) | **60.0%** | **40.0%** | 0% |
| Legendary (cap 1) | **60.0%** | **40.0%** | 0% |
| Divine (cap 2) | **30.47%** | **51.97%** | **17.56%** |

#### Scenario D: `Sₛ = 0`, `Pₛ = 4`

Weapon example pool: `{Shout_Whirlwind, Projectile_SkyShot, Target_SerratedEdge, Shout_BattleStomp}`

| Output rarity | Final 0 skills | Final 1 skill | Final 2 skills |
| :--- | ---: | ---: | ---: |
| Epic (cap 1) | **40.0%** | **60.0%** | 0% |
| Legendary (cap 1) | **40.0%** | **60.0%** | 0% |
| Divine (cap 2) | **10.76%** | **59.13%** | **30.11%** |

#### Scenario E: `Sₛ = 1`, `Pₛ = 1` (one shared, one in pool)

Weapon example:
- Shared: `{Shout_Whirlwind}`
- Pool: `{Projectile_SkyShot}`

| Output rarity | Final 1 skill | Final 2 skills |
| :--- | ---: | ---: |
| Epic (cap 1) | **100%** | 0% |
| Legendary (cap 1) | **100%** | 0% |
| Divine (cap 2) | **72.0%** | **28.0%** |

#### Scenario F: `Sₛ = 1`, `Pₛ = 2` (one shared, two in pool)

Weapon example:
- Shared: `{Shout_Whirlwind}`
- Pool: `{Projectile_SkyShot, Target_SerratedEdge}`

| Output rarity | Final 1 skill | Final 2 skills |
| :--- | ---: | ---: |
| Epic (cap 1) | **100%** | 0% |
| Legendary (cap 1) | **100%** | 0% |
| Divine (cap 2) | **60.8%** | **39.2%** |

### 4.7. Worked example (Divine)

This is a **weapon** example (weapon-only skill boosts).

Assume the rarity system produces a **Divine** forged item:
- Normal stat cap (this mod): **8**
- **SkillCap (Divine)**: **2**

Parent A granted skills:
- `Shout_Whirlwind`
- `Target_SerratedEdge`

Parent B granted skills:
- `Shout_Whirlwind`
- `Projectile_SkyShot`

Split into lists (deduped by skill ID):
- Shared skills `Sₛ = 1`: `Shout_Whirlwind`
- Pool skills `Pₛ = 2`: `Target_SerratedEdge`, `Projectile_SkyShot`

Compute free slots:
- `SkillCap = 2`
- `len(sharedKept) = 1`
- `freeSlots = 1`

Attempt to fill the free slot:
- `P_remaining = 2`
- Divine gain chance: `base(Divine) * m(2) = 28% * 1.4 = 39.2%`
- If the seeded roll succeeds, pick 1 from the pool (seeded), e.g. `Projectile_SkyShot`

Final skills before cap:
- `Shout_Whirlwind`
- `Projectile_SkyShot` *(only if the gain roll succeeded)*

Apply `SkillCap = 2`:
- If you gained 1 pool skill: you are at cap, keep both.
- If you did not gain a pool skill: you stay at 1 skill.

Result:
- The forged Divine item can still roll up to **8 normal blue stats** (the mod’s cap),
- But it will have at most **2 granted skills** (vanilla-aligned).

---
## 5. Rune slots inheritance
Rune slots are inherited by taking the average of the two parents’ rune slot counts, then **rounding up**.

$$RuneSlots_{out} = \lceil (RuneSlots_A + RuneSlots_B) / 2 \rceil$$

Examples:

| Parent A slots | Parent B slots | Forged slots |
| :---: | :---: | :---: |
| 0 | 0 | 0 |
| 0 | 1 | 1 |
| 1 | 2 | 2 |
| 1 | 3 | 2 |
| 2 | 3 | 3 |

---
## 6. Implementation reference 
[forging_system_implementation_blueprint_se.md → Appendix: Pseudocode reference](forging_system_implementation_blueprint_se.md#appendix-pseudocode-reference)
