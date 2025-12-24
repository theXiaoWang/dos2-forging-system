# Inheritance System

## What this system does

This system aims to deliver a more RPG-like forging experience, one that can be calculated, but with enough RNG to allow for that YOLO.

When you forge two items, this system decides **which and how stats are inherited** by the new forged item.
- It also inherits the item's **base values**: weapon **base damage** and armour/shield **base armour & magic armour**, using **levelled, type-safe normalisation**.
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
- [2.4. Baseline budget cache and parent measurement](#24-baseline-budget-cache-and-parent-measurement)
- [2.5. Normalisation (raw to percentile)](#25-normalisation-raw-to-percentile)
- [2.6. Merge algorithm (percentiles to output base values)](#26-merge-algorithm-percentiles-to-output-base-values)
- [2.7. Worked examples (base values)](#27-worked-examples-base-values)
</details>

<details>
<summary><strong><a href="#3-stats-modifiers-inheritance">3. Stats modifiers inheritance</a></strong></summary>

- [3.1. Stats modifiers (definition)](#31-stats-modifiers-definition)
- [3.2. The two stats lists](#32-the-two-stats-lists)
- [3.3. Merging rule (how numbers are merged)](#33-merging-rule-how-numbers-are-merged)
- [3.4. Selection rule (shared + pool + cap)](#34-selection-rule-shared--pool--cap)
</details>

<details>
<summary><strong><a href="#4-skills-inheritance">4. Skills inheritance</a></strong></summary>

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
This document splits forging into independent “channels”, because vanilla item generation works the same way:

- **Base values** (base damage / armour / magic armour): determined by **item type + level + rarity**.
- **Stats modifiers** (boosts): rollable modifiers (eg attributes, crit, "chance to set status") bounded by rarity modifier caps.
- **Granted skills**: a separate, rarity-capped channel (vanilla-aligned).
- **Rune slots**: a separate channel (only when empty; rune effects are forbidden as ingredients).

High-level forge order:
1. Decide the output’s **rarity** using the **[Rarity System](rarity_system.md)**.
2. Decide the output's **base values** (damage/armour) using **[Section 2](#2-base-values-inheritance)**.
3. Inherit **stats modifiers** using **[Section 3](#3-stats-modifiers-inheritance)** (including the modifier cap table).
4. Inherit **skills** using **[Section 4](#4-skills-inheritance)**.
5. Inherit **rune slots** using **[Section 5](#5-rune-slots-inheritance)**.

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
- Prevents “cross-type budget stealing” (e.g. importing a two-handed axe’s raw budget into a dagger).
- Avoids nonsense when ingredient levels are far apart (e.g. level 6 + level 13).
- Ensures the output stays **capped by its own (type, level, rarity)** budget.

Forging can improve the **white numbers** (base damage / base armour / base magic armour). But it’s still limited by the item’s **type**, **your level**, and **its rarity**.

With the right strategy, forging is a way to **upgrade your favourite item over time**: good ingredients push it upwards more reliably, and with some luck you can sometimes get a **big jump**, or very rarely can gain an **exceptional result**.

Here are what you can expect:
- **If slot 1 is already very strong** (near the top for its rarity), most forges will be **small changes** — maybe a point or two up or down, or staying about the same. This is normal: you’re already near the ceiling for that rarity. However, You could push it beyond the normal maximum with excellent donor with right strategy and luck.
- **If slot 1 is weak and the donors are strong**, you’ll see **clear improvements** more often, with very rare **exceptional results** that can feel like a real jackpot.

### 2.1. Base values (definition)
<a id="21-base-values-definition"></a>
This normalisation model is intentionally generic: it works for any item that has a meaningful **base values** (raw template numbers, not stats modifiers/granted skills/runes).

- **Weapons**: base damage range.
- **Shields**: base armour and base magic armour.
- **Armour pieces** (helmets/chest/gloves/boots/pants): base armour and/or base magic armour.
- **Jewellery** (rings/amulets): base magic armour.
- **Slots that have no meaningful base values** (e.g. if both base armour and base magic armour are `0`): Section 2 is a **no-op** for those numeric channels (do not attempt to normalise/divide by a `0` baseline).

Overview on how the forged item's base values are calculated:
- Measure a parent's base value relative to a **baseline for the same (type, level, rarity)**.
- Merge in **percentile space**.
- Re-apply to the output's baseline at the player's level, then clamp to the output band.

### 2.2. Output rules (level/type/rarity)
<a id="22-output-rules-leveltyperarity"></a>
- **Output level**: always the forger’s level, `Level_out = Level_player`.
- **Output type**: always the item in the **main forge slot** (first slot).
- **Output rarity**: decided by the **[Rarity System](rarity_system.md)**.
- **Capped result**: the output's raw numeric values are normally limited by the output's **type + level + rarity** band, but can **exceed the normal maximum** via the **overcap mechanism** (Section 2.6, Step 8) when an upgrade succeeds (up to +10% above the band's maximum).

### 2.3. Inputs and tuning parameters
<a id="23-inputs-and-tuning-parameters"></a>
<a id="23-parameters-tuning-knobs"></a>

This section defines the **inputs**, **notation**, and the **balance knobs** used by the base values merge. The actual algorithm is in Section 2.6.

#### Inputs (per forge)
- **Output selectors**:
  - `Type_out`: always the item type in the **main forge slot** (slot 1).
  - `Level_out`: always the forger’s level, `Level_out = Level_player`.
  - `Rarity_out`: decided by the **[Rarity System](rarity_system.md)**.
- **Numeric channels (what “base values” means)**:
  - **Weapons**: one channel (white damage average).
  - **Shields / armour pieces**: two channels (physical armour and magic armour).
  - **Jewellery**: typically one channel (magic armour).
- **No-op rule**: if an item has no meaningful base value for a channel (e.g. baseline is `0`), do **not** normalise that channel.

#### Balance knobs (tuning table)
| Parameter | Meaning | Default | Notes |
| :--- | :--- | :---: | :--- |
| `w` | Slot 1 dominance when merging percentiles | **0.70** | The main slot's base values are more likely to be inherited by the output. |
| `[L_r, H_r]` | Allowed base roll band for rarity `r` (in quality-ratio space) | See table below | Defines “bottom roll” / “top roll” for base values at each rarity. |
| `α` | Cross-type conversion softness | **0.75** | Used inside `conversionLoss` (Section 2.6). |
| `g(Family_out, Family_donor)` | Family adjacency multiplier (cross-type flexibility) | See table below | Enables weapon “close family” forging without allowing budget stealing (Section 2.6). |
| `p_upgrade_min` | Minimum percentile for an “upgrade roll” | **0.60** | On an upgrade, you roll into `[p_upgrade_min, 1.0]` (or higher if `p_base` is already higher). |
| `upgradeCap` | Maximum upgrade chance | **50%** | Upgrade chance depends only on ingredient quality. |
| `k` | Upgrade difficulty exponent (“higher is harder”) | **2** | Higher values make extreme upgrades rarer; this document uses `k=2`. |
| `overcap` | Upgrade overcap range | **+1%..+10%** | Applied only on an upgrade; higher overcap is harder. |
| Rounding policy | How to convert the final float into the displayed integer | Nearest (half-up) | Optional “player-favour” bias is to always round up. |

#### Base values roll bands (shared across equipment)
These bands are used both to:
- convert parent quality ratios into percentiles (Section 2.5), and
- convert the merged percentile back into an output quality ratio (Section 2.6).

| Rarity | `[L_r, H_r]` | Interpretation |
| :--- | :---: | :--- |
| Common | `[0.97, 1.03]` | Small variance only. |
| Uncommon | `[0.97, 1.04]` | Slightly wider. |
| Rare | `[0.96, 1.06]` | Noticeable, still controlled. |
| Epic | `[0.96, 1.07]` | A bit wider. |
| Legendary | `[0.95, 1.08]` | “Good rolls matter”. |
| Divine | `[0.95, 1.09]` | Top-end, still capped. |
| Unique | `[0.95, 1.08]` | Use Legendary band for now (normalisation is already special-cased). |

#### Weapon families (used by `g`)
| Family | Weapon types |
| :--- | :--- |
| 1H melee | 1H Sword, 1H Axe, 1H Mace |
| Dagger | Dagger |
| 2H melee | 2H Sword, 2H Axe, 2H Mace |
| Spear | Spear |
| Ranged 2H | Bow, Crossbow |
| Magic 1H | Wand |
| Magic 2H | Staff |

#### Family adjacency multiplier `g(Family_out, Family_donor)`
When forging across weapon types, we apply an additional multiplier to make “close family” forging more effective without breaking type safety:
- `g` is always clamped to `[0, 1]`
- `g = 1.00` means “no extra penalty beyond the baseline-ratio loss”

| Relationship | Examples | `g` |
| :--- | :--- | :---: |
| Same family | 2H sword ↔ 2H axe, bow ↔ crossbow | **1.00** |
| Strong adjacency | Spear ↔ 2H melee; Spear ↔ Ranged 2H | **0.95** |
| Medium adjacency | 2H melee ↔ Ranged 2H | **0.90** |
| Weak adjacency | Anything ↔ Magic weapons (unless same magic family); Dagger ↔ non-dagger; everything else | **0.85** |

---

### 2.4. Baseline budget cache and parent measurement
<a id="24-baseline-budget-cache-and-parent-measurement"></a>
<a id="24-measuring-base-values-no-runeboost-pollution"></a>

This system measures parent base values from real items (white tooltip numbers), then compares them to a **baseline budget cache** to make the merge vanilla-fair and type-safe.

#### Parent measurement
Important constraints (already enforced elsewhere, but repeated here because they matter for correctness):
- **Socketed runes are rejected** as ingredients (Section 1.1), so rune pollution does not enter the system.
- Try to measure from a stable state (not mid-combat / not under temporary buffs), so the tooltip reflects the item’s own base values.

Weapons (single channel):
- Read the weapon’s white damage range from the item tooltip: `D_min..D_max`
- Compute the average: `D_avg = (D_min + D_max) / 2`

Shields / armour pieces (two channels):
- Read `Armour` and `MagicArmour` from the item tooltip.
- Treat each channel independently throughout Sections 2.5–2.6.

#### Baseline cache `B(Type, Level, Rarity)` (runtime-sampled, data-driven)
`B(Type, Level, Rarity)` is the expected (mean) base value for that cell in vanilla.

Because this curve is not cleanly exposed as a single editor table, obtain it empirically via Script Extender and treat the result as a **data asset**.

Recommended approaches:
- **Preferred (ship/precompute)**: run a developer-only sampling command (or build step), export the resulting baseline table (for all `(Type, Level, Rarity)`), and ship it with the mod. Runtime then simply loads the table.
- **Fallback (first-run calibration)**: if cannot ship a baseline table, sample once on first run, then **persist** the results (e.g. to a saved cache file / persistent mod data) and reuse them on all later runs.

Sampling procedure (either approach uses the same method):
- Spawn (or otherwise obtain) `N` vanilla items for each `(Type, Level, Rarity)` cell.
- Read the measured base value(s) (e.g. `D_avg`).
- Store `B` as the sample mean (optionally also store p10/p50/p90 for debugging).

Cache invalidation (when to resample):
- If you change the sampling algorithm, item filters, or supported type list.
- If a game/mod update materially changes item generation curves (treat this as “baseline version bump”).

Recommended starting point:
- `N = 200` per cell for stable means (use fewer for dev, more for final tuning).

Note on “Type” for armour:
- For armour, `Type` should include the **slot** (e.g. Chest) and the **armour archetype/material** (Strength / Finesse / Intelligence families), because those families have intentionally different physical vs magic baseline budgets.

---

### 2.5. Normalisation (raw to percentile)
<a id="25-normalisation-raw-to-percentile"></a>
<a id="25-normalisation-q--percentile-p"></a>

This converts “how good is this item for its own type/level/rarity” into a stable percentile `p ∈ [0, 1]`.

For a parent item `i` and one numeric channel (weapon damage average, physical armour, or magic armour):
- `Base_i`: the measured base value (from Section 2.4).
- `Type_i`, `Level_i`, `Rarity_i`: the parent’s identifiers.
- `B_i = B(Type_i, Level_i, Rarity_base)`:
  - Normally `Rarity_base = Rarity_i`

Compute:
- Quality ratio: `q_i = Base_i / B_i`
- Band for the parent’s displayed rarity: `[L_{Rarity_i}, H_{Rarity_i}]`
- Percentile: `p_i = clamp((q_i - L_{Rarity_i}) / (H_{Rarity_i} - L_{Rarity_i}), 0, 1)`

Interpretation:
- `p_i = 0` means “bottom of the allowed base band for that rarity”.
- `p_i = 1` means “top of the allowed base band for that rarity”.

---

### 2.6. Merge algorithm (percentiles to output base values)
<a id="26-merge-algorithm-percentiles-to-output-base-values"></a>
<a id="26-cross-type-merging-w--conversionloss"></a>

Never merge raw base numbers across types. Instead:
1) normalise each parent into a percentile (Section 2.5),
2) merge percentiles with slot 1 dominance, and
3) denormalise back onto the output type’s baseline at the player’s level.

#### Step-by-step algorithm (one numeric channel)
Let slot 1 be the “main” parent and slot 2 the “donor” parent.

#### Legend

| Name | Meaning | Range / units |
| :--- | :--- | :--- |
| `Type_out`, `Level_out`, `Rarity_out` | Output selectors (always slot 1 type, player level, rarity system result) | n/a |
| `B(Type, Level, Rarity)` | Baseline mean base value from cache | base-value units |
| `[L_r, H_r]` | Allowed quality-ratio band for rarity `r` | ratio |
| `p_1`, `p_2` | Parent percentiles (“how good for its own type/level/rarity”) | `[0,1]` |
| `ratioLoss` | Cross-type loss from baseline budget ratio (softened by `α`) | `[0,1]` |
| `g(…)` | Weapon-family adjacency multiplier | `[0,1]` |
| `conversionLoss` | Final cross-type donor effectiveness (`ratioLoss × g`) | `[0,1]` |
| `w` | Slot 1 dominance weight | `[0,1]` |
| `p_base` | Deterministic merged percentile (type-safe) | `[0,1]` |
| `p_ing` | Ingredient quality (ignores type conversion penalties) | `[0,1]` |
| `upgradeCap`, `k` | Upgrade chance cap and difficulty exponent | `%` or `num` |
| `P(upgrade)` | Upgrade chance | `[0,50%]` |
| `u` | Upgrade quality roll (only if upgrade succeeds) | `U(0,1)` |
| `p_out` | Final output percentile (either `p_base` or upgraded) | `[0,1]` |
| `v` | Overcap size roll (only if upgrade succeeds) | `U(0,1)` |
| `Δ` | Overcap bonus applied to `q_out` | `+1%..10%` |
| `q_out` | Output quality ratio (applied to `B_out`) | ratio |

#### Cross-type conversion loss

$$ratioLoss = \min\left(1,\ \left(\frac{B(Type_{out}, Level_{out}, Rarity_{out})}{B(Type_{donor}, Level_{out}, Rarity_{out})}\right)^{\alpha}\right)$$

$$conversionLoss = clamp(ratioLoss \times g(Family_{out}, Family_{donor}),\ 0,\ 1)$$

Notes:
- `g(Family_out, Family_donor)` is primarily defined for **weapons** (Section 2.3 “Weapon families”). Treat `g = 1.0` for other categories.

#### Step-by-step explanation (per numeric channel)

##### 1. Choose output selectors:
   - `Type_out = Type_1` (always the main slot’s type)
   - `Level_out = Level_player` (always the forger’s level)
   - `Rarity_out` (from the rarity system)

##### 2. Normalise each parent to percentiles:
   - For each parent `i`, compute `q_i = Base_i / B_i` (where `B_i = B(Type_i, Level_i, Rarity_i)`)
   - Then compute `p_i = clamp((q_i - L_{Rarity_i}) / (H_{Rarity_i} - L_{Rarity_i}), 0, 1)`
   - This gives you `p_1` and `p_2` (how good each parent is for its own type/level/rarity)

##### 3. Compute cross-type conversion loss (only when types differ):
   - If `Type_1 == Type_2`: set `conversionLoss = 1.0` and skip to step 4.
   - Otherwise:
     - Compute `ratioLoss = min(1, (B_out / B_donor_on_out_curve)^α)` (budgets compared on the output curve)
     - Apply the family adjacency multiplier: `conversionLoss = clamp(ratioLoss × g, 0, 1)` (where `g` comes from weapon-family adjacency, Section 2.3)

##### 4. Compute deterministic merged percentile:
   - `p_base = clamp(w × p_1 + (1 - w) × p_2 × conversionLoss, 0, 1)`
   - This is the type-safe, deterministic result (what you get if no upgrade happens)

##### 5. Compute ingredient quality (used only for upgrade chance):
   - `p_ing = clamp(w × p_1 + (1 - w) × p_2, 0, 1)`
   - upgrade chance only depends on raw ingredient quality

##### 6. Compute upgrade chance:
   - `P(upgrade) = upgradeCap × (p_ing)^k` (this document uses `k=2`)

##### 7. Roll for upgrade:
   - Roll once to check if the upgrade succeeds (compare a random value to `P(upgrade)`).
   - **If upgrade fails**: set `p_out = p_base` and skip to step 9 (no overcap).
   - **If upgrade succeeds**: continue to step 8.

##### 8. Roll upgraded percentile and overcap (only if upgrade succeeded):
   - Compute `p_min = max(p_upgrade_min, p_base)` (upgrade floor)
   - Roll `u ~ U(0,1)` and compute `p_out = p_min + (1 - p_min) × u^2` (higher is harder)
   - Roll `v ~ U(0,1)` and compute `Δ = 0.01 + 0.09 × v^4` (overcap bonus, range +1%..+10%, higher is harder)

##### 9. Convert percentile to quality ratio:
   - `q_out = L_out + p_out × (H_out - L_out)` (where `[L_out, H_out]` is the output rarity band)
   - If the upgrade succeeded (from step 7), apply overcap: `q_out = q_out × (1 + Δ)`

##### 10. Apply to baseline and round:
   - `B_out = B(Type_out, Level_out, Rarity_out)` (look up from baseline cache)
   - `Base_target_out = B_out × q_out`
   - Round to integer for display (rounding policy: nearest, or optionally always round up)

#### Multi-channel note (shields / armour)
For shields/armour, apply the same steps as above  **per numeric channel** (physical armour and magic armour). The `conversionLoss` ratio is also computed per channel because the relevant `B(…)` differs per channel.

#### Why this avoids exploits
- **Level gap**: because each parent is normalised against its own `(type, level, rarity)` baseline, a level 13 item does not directly inject level 13 raw damage into a level 10 output.
- **Cross-type budget stealing**: the donor only contributes a percentile, and that percentile is re-expressed on the output type’s baseline; a dagger remains “a very good dagger”, not “a dagger with two-handed damage”.
- **Rune/boost pollution**: rune sockets are rejected up-front (Section 1.1), and any remaining variation is handled fairly because all comparisons are made against the sampled baseline budget `B(Type, Level, Rarity)`.

### 2.7. Worked examples
<a id="27-worked-examples-base-values"></a>

#### Shared settings (used by all examples)
| Name | Value | Meaning |
| :--- | :---: | :--- |
| `w` | 0.70 | Slot 1 dominance (merge weight) |
| `p_upgrade_min` | 0.60 | Upgrade minimum percentile floor (only on upgrade success) |
| `upgradeCap` | 50% | Maximum upgrade chance |
| `k` | 2 | Upgrade difficulty exponent (“higher is harder”) |
| Upgrade quality roll | `u^2` | Rolls `p_out` towards the low end unless you get lucky |
| Overcap roll | `v^4` | Rolls overcap towards +1% unless you get lucky |

The examples below use real level 20 in-game items (white damage ranges / armour values). `B(...)` values shown are example baseline-cache values (your sampler provides the real ones). You can toggle the fully explicit view to see the detailed calculations.

#### Example 1: Same type, "steady improvement" (crossbow + crossbow)
Assume the realised output rarity is **Divine** (the rarity system is documented separately).

| Item | Rarity | Measured base | Baseline `B` | Band | `q = Base/B` | `p` |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| Slot 1 (Crossbow) | Divine | `150–157` → `153.5` | `152.0` | `[0.95, 1.09]` | `1.010` | `0.428` |
| Slot 2 (Crossbow) | Common | `130–136` → `133.0` | `133.0` | `[0.97, 1.03]` | `1.000` | `0.500` |
| Output (Crossbow) | Divine | (computed) | `152.0` | `[0.95, 1.09]` | – | – |

| Key value | Result |
| :--- | :---: |
| `conversionLoss` | `1.00` (same type) |
| `p_base` | `0.450` |
| `p_ing` | `0.450` |
| `P(upgrade)` | `50% × 0.450^2 ≈ 10.13%` |

| Outcome | `p_out` | `q_out` | Output damage |
| :--- | :---: | :---: | :---: |
| No upgrade | `0.450` | `1.013` | `152×1.013 = 154.0` |
| Upgrade example (`u=0.70`, `v=0.30`) | `0.796` | `1.061×(1+0.0107)=1.072` | `≈ 163.0` |

<details>
<summary><strong>Fully explicit view</strong></summary>

| Name | Value | How it was obtained |
| :--- | :---: | :--- |
| `Base_1` | `153.5` | average of `150–157` |
| `Base_2` | `133.0` | average of `130–136` |
| `B_1` | `152.0` | `B(Crossbow,20,Divine)` |
| `B_2` | `133.0` | `B(Crossbow,20,Common)` |
| `q_1` | `153.5/152.0 = 1.010` | definition |
| `q_2` | `133.0/133.0 = 1.000` | definition |
| `p_1` | `clamp((1.010-0.95)/0.14)=0.428` | Divine band width `0.14` |
| `p_2` | `clamp((1.000-0.97)/0.06)=0.500` | Common band width `0.06` |
| `conversionLoss` | `1.00` | same type |
| `p_base` | `0.70×0.428 + 0.30×0.500 = 0.450` | merge |
| `p_ing` | `0.70×0.428 + 0.30×0.500 = 0.450` | ingredient quality |
| `P(upgrade)` | `0.50×0.450^2 = 0.1013` | cap `50%`, `k=2` |
| `p_min` | `max(0.60, 0.450) = 0.60` | upgrade floor |
| `p_out` (example) | `0.60 + 0.40×0.70^2 = 0.796` | `u=0.70` |
| `q_out` (pre-overcap) | `0.95 + 0.796×0.14 = 1.061` | Divine band |
| `Δ` (example) | `0.01 + 0.09×0.30^4 ≈ 0.0107` | `v=0.30` |
| `q_out` (final) | `1.061×1.0107 ≈ 1.072` | overcap |
| `D_out` (final) | `152×1.072 ≈ 163.0` | apply baseline |

</details>

#### Example 2: Strong adjacency, "high-quality donor" (spear + high-roll 2H sword)
Slot 1 (spear): `150–157` → `D_avg = 153.5`  
Slot 2 (2H sword, high roll): `170–188` → `D_avg = 179.0`

Assume the realised output rarity is **Divine** (slot 1 identity is preserved).

| Item | Rarity | Measured base | Baseline `B` | Band | `q = Base/B` | `p` |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| Slot 1 (Spear) | Divine | `150–157` → `153.5` | `152.0` | `[0.95, 1.09]` | `1.010` | `0.428` |
| Slot 2 (2H Sword) | Divine | `170–188` → `179.0` | `160.0` | `[0.95, 1.09]` | `1.119` | `1.000` (clamp) |
| Output (Spear) | Divine | (computed) | `152.0` | `[0.95, 1.09]` | – | – |

| Key value | Result |
| :--- | :---: |
| `ratioLoss` | `(152/160)^0.75 ≈ 0.96` |
| `g` | `0.95` (strong adjacency) |
| `conversionLoss` | `0.96×0.95 ≈ 0.91` |
| `p_base` | `0.574` |
| `p_ing` | `0.600` |
| `P(upgrade)` | `50% × 0.600^2 = 18.00%` |

| Outcome | `p_out` | `q_out` | Output damage |
| :--- | :---: | :---: | :---: |
| No upgrade | `0.574` | `1.030` | `152×1.030 = 156.6` |
| Upgrade example (`u=0.80`, `v=0.30`) | `0.856` | `1.070×(1+0.0107)=1.081` | `≈ 164.3` |

<details>
<summary><strong>Fully explicit view</strong></summary>

| Name | Value | How it was obtained |
| :--- | :---: | :--- |
| `Base_1` | `153.5` | average of `150–157` |
| `Base_2` | `179.0` | average of `170–188` |
| `B_1` | `152.0` | `B(Spear,20,Divine)` |
| `B_2` | `160.0` | `B(2H_Sword,20,Divine)` |
| `B_out` | `152.0` | `B(Spear,20,Divine)` (output type) |
| `q_1` | `153.5/152.0 = 1.010` | definition |
| `q_2` | `179.0/160.0 = 1.119` | definition |
| `p_1` | `clamp((1.010-0.95)/0.14)=0.428` | Divine band width `0.14` |
| `p_2` | `clamp((1.119-0.95)/0.14)=1.000` | clamped to 1.0 (above band) |
| `ratioLoss` | `(152/160)^0.75 ≈ 0.96` | budget comparison on output curve |
| `g` | `0.95` | strong adjacency (2H melee family) |
| `conversionLoss` | `0.96×0.95 ≈ 0.91` | family-adjusted conversion |
| `p_base` | `0.70×0.428 + 0.30×1.000×0.91 = 0.574` | merge with conversion loss |
| `p_ing` | `0.70×0.428 + 0.30×1.000 = 0.600` | ingredient quality (no conversion loss) |
| `P(upgrade)` | `0.50×0.600^2 = 0.18` | cap `50%`, `k=2` |
| `p_min` | `max(0.60, 0.574) = 0.60` | upgrade floor |
| `p_out` (example) | `0.60 + 0.40×0.80^2 = 0.856` | `u=0.80` |
| `q_out` (pre-overcap) | `0.95 + 0.856×0.14 = 1.070` | Divine band |
| `Δ` (example) | `0.01 + 0.09×0.30^4 ≈ 0.0107` | `v=0.30` |
| `q_out` (final) | `1.070×1.0107 ≈ 1.081` | overcap |
| `D_out` (final) | `152×1.081 ≈ 164.3` | apply baseline |

</details>

#### Example 3: Weak adjacency, "works but is harder" (1H sword + staff)
Slot 1 (1H sword): `98–108` → `D_avg = 103.0`  
Slot 2 (staff): `132–160` → `D_avg = 146.0`

Assume the realised output rarity is **Divine** (slot 1 identity is preserved).
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |

| Item | Rarity | Measured base | Baseline `B` | Band | `q = Base/B` | `p` |
| Slot 1 (1H Sword) | Divine | `98–108` → `103.0` | `102.0` | `[0.95, 1.09]` | `1.010` | `0.428` |
| Slot 2 (Staff) | Divine | `132–160` → `146.0` | `145.0` | `[0.95, 1.09]` | `1.007` | `0.406` |
| Output (1H Sword) | Divine | (computed) | `102.0` | `[0.95, 1.09]` | – | – |

| Key value | Result |
| :--- | :---: |
| `ratioLoss` | `(102/145)^0.75 ≈ 0.77` |
| `g` | `0.85` (weak adjacency) |
| `conversionLoss` | `0.77×0.85 ≈ 0.65` |
| `p_base` | `0.379` |
| `p_ing` | `0.422` |
| `P(upgrade)` | `50% × 0.422^2 ≈ 8.90%` |

| Outcome | `p_out` | `q_out` | Output damage |
| :--- | :---: | :---: | :---: |
| No upgrade | `0.379` | `1.003` | `102×1.003 = 102.3` |
| Upgrade example (`u=0.80`, `v=0.30`) | `0.856` | `1.070×(1+0.0107)=1.081` | `≈ 110.3` |

<details>
<summary><strong>Fully explicit view</strong></summary>

| Name | Value | How it was obtained |
| :--- | :---: | :--- |
| `Base_1` | `103.0` | average of `98–108` |
| `Base_2` | `146.0` | average of `132–160` |
| `B_1` | `102.0` | `B(1H_Sword,20,Divine)` |
| `B_2` | `145.0` | `B(Staff,20,Divine)` |
| `B_out` | `102.0` | `B(1H_Sword,20,Divine)` (output type) |
| `q_1` | `103.0/102.0 = 1.010` | definition |
| `q_2` | `146.0/145.0 = 1.007` | definition |
| `p_1` | `clamp((1.010-0.95)/0.14)=0.428` | Divine band width `0.14` |
| `p_2` | `clamp((1.007-0.95)/0.14)=0.406` | Divine band width `0.14` |
| `ratioLoss` | `(102/145)^0.75 ≈ 0.77` | budget comparison on output curve |
| `g` | `0.85` | weak adjacency (1H melee vs staff) |
| `conversionLoss` | `0.77×0.85 ≈ 0.65` | family-adjusted conversion |
| `p_base` | `0.70×0.428 + 0.30×0.406×0.65 = 0.379` | merge with conversion loss |
| `p_ing` | `0.70×0.428 + 0.30×0.406 = 0.422` | ingredient quality (no conversion loss) |
| `P(upgrade)` | `0.50×0.422^2 ≈ 0.089` | cap `50%`, `k=2` |
| `p_min` | `max(0.60, 0.379) = 0.60` | upgrade floor |
| `p_out` (example) | `0.60 + 0.40×0.80^2 = 0.856` | `u=0.80` |
| `q_out` (pre-overcap) | `0.95 + 0.856×0.14 = 1.070` | Divine band |
| `Δ` (example) | `0.01 + 0.09×0.30^4 ≈ 0.0107` | `v=0.30` |
| `q_out` (final) | `1.070×1.0107 ≈ 1.081` | overcap |
| `D_out` (final) | `102×1.081 ≈ 110.3` | apply baseline |

</details>

#### Example 4: Armour (two channels), same maths per channel (Strength chest + Intelligence chest)
Slot 1 (Strength chest): `713 Physical Armour`, `140 Magic Armour`  
Slot 2 (Intelligence chest): `140 Physical Armour`, `713 Magic Armour`

Assume the realised output rarity is **Divine** (slot 1 identity is preserved).

Baseline cache (Divine):
- `B(Chest_Str)`: `B_phys = 700`, `B_magic = 150`
- `B(Chest_Int)`: `B_phys = 150`, `B_magic = 700`

| Channel | Slot 1 `Base/B → p_1` | Slot 2 `Base/B → p_2` | `conversionLoss` | `p_base` | `p_ing` | `P(upgrade)` | No-upgrade output |
| :--- | :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| Physical | `713/700=1.019 → 0.490` | `140/150=0.933 → 0.000` | `1.00` | `0.343` | `0.343` | `≈ 5.88%` | `q=0.998 → 700×0.998 = 699` |
| Magic | `140/150=0.933 → 0.000` | `713/700=1.019 → 0.490` | `≈ 0.32` | `0.047` | `0.147` | `≈ 1.08%` | `q=0.957 → 150×0.957 = 144` |

Interpretation:
- The output remains a Strength chest (slot 1 identity is preserved).
- Per-channel upgrades are possible (rare), and a magic-channel "spike" is intentionally much harder than a physical-channel spike with these inputs.

<details>
<summary><strong>Fully explicit view</strong></summary>

##### Physical Armour Channel

| Name | Value | How it was obtained |
| :--- | :---: | :--- |
| `Base_1_phys` | `713` | measured physical armour (Slot 1) |
| `Base_2_phys` | `140` | measured physical armour (Slot 2) |
| `B_1_phys` | `700` | `B(Chest_Str,20,Divine)` physical |
| `B_2_phys` | `150` | `B(Chest_Int,20,Divine)` physical |
| `B_out_phys` | `700` | `B(Chest_Str,20,Divine)` physical (output type) |
| `q_1_phys` | `713/700 = 1.019` | definition |
| `q_2_phys` | `140/150 = 0.933` | definition |
| `p_1_phys` | `clamp((1.019-0.95)/0.14)=0.490` | Divine band width `0.14` |
| `p_2_phys` | `clamp((0.933-0.95)/0.14)=0.000` | clamped to 0 (below band) |
| `conversionLoss_phys` | `1.00` | same type (both are physical armour) |
| `p_base_phys` | `0.70×0.490 + 0.30×0.000×1.00 = 0.343` | merge |
| `p_ing_phys` | `0.70×0.490 + 0.30×0.000 = 0.343` | ingredient quality |
| `P(upgrade)_phys` | `0.50×0.343^2 ≈ 0.0588` | cap `50%`, `k=2` |
| `q_out_phys` (no upgrade) | `0.95 + 0.343×0.14 = 0.998` | Divine band |
| `Base_out_phys` (no upgrade) | `700×0.998 = 699` | apply baseline |

##### Magic Armour Channel

| Name | Value | How it was obtained |
| :--- | :---: | :--- |
| `Base_1_magic` | `140` | measured magic armour (Slot 1) |
| `Base_2_magic` | `713` | measured magic armour (Slot 2) |
| `B_1_magic` | `150` | `B(Chest_Str,20,Divine)` magic |
| `B_2_magic` | `700` | `B(Chest_Int,20,Divine)` magic |
| `B_out_magic` | `150` | `B(Chest_Str,20,Divine)` magic (output type) |
| `q_1_magic` | `140/150 = 0.933` | definition |
| `q_2_magic` | `713/700 = 1.019` | definition |
| `p_1_magic` | `clamp((0.933-0.95)/0.14)=0.000` | clamped to 0 (below band) |
| `p_2_magic` | `clamp((1.019-0.95)/0.14)=0.490` | Divine band width `0.14` |
| `ratioLoss_magic` | `(150/700)^0.75 ≈ 0.38` | budget comparison on output curve |
| `g` | `0.85` | weak adjacency (different armour types) |
| `conversionLoss_magic` | `0.38×0.85 ≈ 0.32` | family-adjusted conversion |
| `p_base_magic` | `0.70×0.000 + 0.30×0.490×0.32 = 0.047` | merge with conversion loss |
| `p_ing_magic` | `0.70×0.000 + 0.30×0.490 = 0.147` | ingredient quality (no conversion loss) |
| `P(upgrade)_magic` | `0.50×0.147^2 ≈ 0.0108` | cap `50%`, `k=2` |
| `q_out_magic` (no upgrade) | `0.95 + 0.047×0.14 = 0.957` | Divine band |
| `Base_out_magic` (no upgrade) | `150×0.957 = 144` | apply baseline |

</details>

---

## 3. Stats modifiers inheritance
<a id="3-stats-modifiers-inheritance"></a>

This section defines how **blue stats** (rollable stats modifiers like Strength, crit, resistances, etc.) are inherited when you forge.

- The system prefers **shared stats** (safer and more predictable).
- Non-shared stats go into a **pool** (risk/reward).
- The final item is still limited by the rarity’s **stats slot cap** (see the cap table below).

Here are what you can expect:
- **If the parents share many stats**, the result is usually very stable: you keep most of what you already like, and the pool acts like a small “bonus” chance.
- **If the parents share few or no stats**, the result is much more random: you can gain different stats lines, but it’s harder to reliably keep specific ones.

### 3.1. Stats modifiers (definition)
<a id="31-stats-modifiers-definition"></a>

**Stats modifiers** are rollable boosts (blue text stats) that appear on items based on their rarity. These include:
- Attributes (Strength, Finesse, Intelligence, etc.)
- Combat abilities (Warfare, Scoundrel, etc.)
- Resistances (Fire, Poison, etc.)
- Status chance effects ("X% chance to set Y")
- Other numeric modifiers (Critical Chance, Accuracy, Initiative, Movement, Blocking, etc.)

Stats modifiers are **separate from base values** (Section 2) and **granted skills** (Section 4). They are bounded by rarity-based caps defined in the **[Rarity System](rarity_system.md)**.

#### Modifier cap for each rarity

| Rarity ID | Name | Max stats slots (this mod) | Vanilla rollable boost slots (non-rune) |
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
- If the shield is **Rare** (Rarity ID 3), it can have up to **5 stats modifiers** (for example: `Blocking +15`, `+2 Constitution`, `+1 Warfare`, `+10% Fire Resistance`, `+1 Retribution`).  
  - Vanilla reference: `Shield.stats` defines `_Boost_Shield_Special_Block_Shield_*` boosts that apply the `Blocking` stats (e.g. `Blocking=10/15/20`).
- If the same shield is **Epic** (Rarity ID 4), it can have up to **6 stats modifiers**.

### 3.2. The two stats lists
<a id="32-the-two-stats-lists"></a>
- **Shared stats (S)**: stats on **both** parents (guaranteed).
- **Pool stats (P)**: stats that are **not shared** (unique to either parent). This is the combined pool from both parents.

#### Key values

- **S (Shared stats)**: stats lines both parents share (always carried over).
- **P (Pool stats)**: stats lines not shared (all unique lines from both parents combined).
- **E (Expected baseline)**: your starting pool pick count (baseline picks from the pool).
  - Default rule: `E = floor((P + 1) / 3)` (one-third of the pool, rounded down, with +1 bias).
  - Special case: if `P = 0` or `P = 1`, use `E = 0` (this enables a clean 50/50 keep-or-lose roll for a single pool stat).
- **V (Luck adjustment/variance)**: the luck result that nudges E up/down (can chain).
- **K (Stats from pool)**: how many you actually take from the pool (after luck adjustment, limited to 0–P).
- **T (Planned total)**: planned stats lines before the rarity cap.
- **Cap**: the max stats slots from rarity.
- **Final**: stats lines after the cap is applied.

---
#### Two rules define inheritance
- [Merging rule](#33-merging-rule-how-numbers-are-merged)
- [Selection rule](#34-selection-rule-shared--pool--cap)

### 3.3. Merging rule (how numbers are merged)
<a id="33-merging-rule-how-numbers-are-merged"></a>

Sometimes both parents have the **same stats**, but the **numbers** are different:
- `+10% Critical Chance` vs `+14% Critical Chance`
- `+3 Strength` vs `+4 Strength`

In this system, those are still treated as **Shared stats (S)** (same stats **key**), but the forged item will roll a **merged value** for those stats.

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
- **Percent stats** (Critical Chance, Accuracy, Resistances, “X% chance to set Y”): round to the nearest integer percent.

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

#### Quick “one forge” walk-through (shows what the 50% wide-roll chance means)
Using Example A (`+10%` vs `+14%` Critical Chance):

| Step | Roll | Calculation | Result (rounded) |
| :---: | :--- | :--- | :--- |
| 1 | Choose roll type | 50% tight vs 50% wide | Tight or Wide |
| 2A | Wide case | `r=1.22` → `value = clamp(12×1.22, 8.5, 16.1) = 14.64` | `15%` |
| 2B | Tight case | `r=0.90` → `value = clamp(12×0.90, 8.5, 16.1) = 10.8` | `11%` |

---
### 3.4. Selection rule (shared + pool + cap)
<a id="34-selection-rule-shared--pool--cap"></a>

Now that **Shared stats (S)** includes the value-merge behaviour above (same stats key, merged number if needed), the next step:
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
#### Step 1: Separate shared vs pool stats
Compare the two parents:
- For all the **shared stats** from both items (same stats **key**), put into **Shared stats (S)**.
  - If the values differ, use the **value merge** rules in **3.3** to roll the merged number for the forged item.
- For all the **non-shared stats** from both items, put into **Pool stats (P)**.

#### Step 2: Set the expected baseline (E)
Now work out your starting point for the pool.
You begin at **about one-third of the pool**, rounded down (this is the “expected baseline”, E). This makes **non-shared** stats noticeably harder to keep, while **shared** stats remain stable.

Examples:
- Pool size 1 → baseline is 0 (then you 50/50 roll to keep it or lose it)
- Pool size 3 → expect to keep 1
- Pool size 4 → expect to keep 1
- Pool size 7 → expect to keep 2
- Pool size 12 → expect to keep 4

#### Step 3: Choose the tier (sets luck odds)
The tier depends only on **pool size**:

| Pool size | Tier | First roll chances (Bad / Neutral / Good) | Chain chance (Down / Up) |
| :--- | :--- | :--- | :--- |
| **1** | Tier 1 (Safe) | 0% / 50% / 50% | None |
| **2–4** | Tier 2 (Early) | 12% / 50% / 38% | 12% / 22% |
| **5–7** | Tier 3 (Mid) | 28% / 50% / 22% | 28% / 30% |
| **8+** | Tier 4 (Risky) | 45% / 40% / 15% | 45% / 30% |

#### Step 4: Roll the luck adjustment (can chain)
The system rolls a **luck adjustment** which is essentially a **variance** that gets added to the expected baseline **E**, which changes how many pool stats you keep:

- **Bad roll**: you try to keep 1 fewer, and you may chain further down.
- **Neutral roll**: you keep the expected amount (no change).
- **Good roll**: you try to keep 1 more, and you may chain further up.

**Safety rule (always true):** you can’t keep fewer than **0** pool stats, and you can’t keep more than the **pool size**.


#### Step 5: Build the result and apply the cap
##### 1. Plan total stats:
   - Total stats = number of shared stats + number of pool stats kept
##### 2. Build the list:
   - Start with all **shared stats**, then add that many random stats from the **pool**.
##### 3. Apply the cap last:
   - If the total is above the item's **max stats slots**, remove extra stats until you reach the limit (remove pool-picked stats first).

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
- Shared stats (on both): `+1 Finesse`, `+0.5m Movement` → `S = 2`
- Pool stats (not shared): `+10% Fire Resistance`, `+1 Sneaking`, `+2 Initiative`, `+10% Air Resistance` → `P = 4`

Now calculate how many pool stats you keep:
- Expected baseline: `E = floor((P + 1) / 3) = floor(5 / 3) = 1`
- Suppose your luck adjustment roll comes out as `V = +1`
- Pool stats kept (from the pool): `K = clamp(E + V, 0, P) = clamp(1 + 1, 0, 4) = 2`
- Planned total before cap: `T = S + K = 2 + 2 = 4`

Finally apply the rarity cap:
- Assume the rarity system gives the new item **Rare** → `Cap = 5`
- Final total: `Final = min(T, Cap) = min(4, 5) = 4`

So you end up with:
- The 2 shared stats (always)
- Plus 2 of the pool stats (no trimming needed in this example)

---

#### Safe vs YOLO forging

These two standalone examples are meant to show the difference between:
- **Safe forging**: many shared stats → stable outcomes (pool stats are just “bonus”).
- **YOLO forging**: zero shared stats → pure variance (rare spikes are possible, but unreliable).

#### Safe Forging (Pool size = 2, 2× Divine items with high shared stats)
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
- `S = 7` (Shared stats)
- `P = 2` (Pool size)
- `E = floor((P + 1) / 3) = floor(3 / 3) = 1` (Expected baseline)
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
- `T = 7` → Final = 7 (no trimming)
- `T = 8` → Final = 8 (at cap)
- `T = 9` → Final = 8 (trim 1 pool stat)

Chance to end with a **Divine item with 8 stats** (Final = 8):
- `P(T >= 8) = P(A = 0) + P(A = +1) + P(A = +2) = 50% + 29.64% + 8.36% = 88%`

**Key insight:** With **very high shared stats (7)**, you’re guaranteed a near-max item even if you lose all pool stats.

#### YOLO forging (Common + Divine, 0 shared, everything in the pool)
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
- `S = 0` (Shared stats)
- `P = 9` (Pool size)
- `E = floor((P + 1) / 3) = floor(10 / 3) = 3` (Expected baseline)
- **Tier used:** Tier 4 odds (because `P = 9` is `8+`)
- **Assume output rarity:** Divine (2.7% chance)

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
- `T = 0–7` → Final = T
- `T = 8` → Final = 8 (at cap)
- `T = 9` → Final = 8 (trim 1 pool stat)

Chance to end with a **Divine item with 8 stats** (Final = 8):
- `P(T ≥ 8) = P(A = +5) + P(A = +6) = 0.09% + 0.04% ≈ 0.12%`

**Key insight:** YOLO forging can still “spike” into a full Divine statline, but it’s intentionally **very rare** when you have **0 shared stats**.

---
#### Tier 1 (Pool size = 1, no chains)

##### Example 1
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
- `S = 1` (Shared stats)
- `P = 1` (Pool size)
- `E = 0` (Expected baseline, special case for P = 1)

| Luck adjustment<br>(A) | Stats from pool<br>(K) | Forged item stats<br>(T) | Chance<br>(math) | Chance |
| :---: | :---: | :---: | :---: | :---: |
| 0 | 0 | 1 | 50% (cap) | **50.00%** |
| +1 | 1 | 2 | 50% (cap) | **50.00%** |

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
Shared stats:
 - +2 Intelligence
Pool stats:
 - +10% Fire Resistance
 - +1 Loremaster
 - +10% Water Resistance
```

Inputs for this example:
- `S = 1` (Shared stats)
- `P = 3` (Pool size)
- `E = floor((P + 1) / 3) = floor(4 / 3) = 1` (Expected baseline)

Before the rarity cap, the forged item ends up with between **1** and **4** stats (**1** shared + **0–3** from the pool).

| Luck adjustment<br>(A) | Stats from pool<br>(K) | Forged item stats<br>(T) | Chance<br>(math) | Chance |
| :---: | :---: | :---: | :---: | :---: |
| -1 | 0 | 1 | 12% (cap) | **12.00%** |
| 0 | 1 | 2 | 50% | **50.00%** |
| +1 | 2 | 3 | 38% × 78% | **29.64%** |
| +2 | 3 | 4 | 38% × 22% (cap) | **8.36%** |

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
- `S = 2` (Shared stats)
- `P = 4` (Pool size)
- `E = floor((P + 1) / 3) = floor(5 / 3) = 1` (Expected baseline)

Before the rarity cap, the forged item ends up with between **2** and **6** stats (**2** shared + **0–4** from the pool).

| Luck adjustment<br>(A) | Stats from pool<br>(K) | Forged item stats<br>(T) | Chance<br>(math) | Chance |
| :---: | :---: | :---: | :---: | :---: |
| -1 | 0 | 2 | 12% (cap) | **12.00%** |
| 0 | 1 | 3 | 50% | **50.00%** |
| +1 | 2 | 4 | 38% × 78% | **29.64%** |
| +2 | 3 | 5 | 38% × 22% × 78% | **6.54%** |
| +3 | 4 | 6 | 38% × (22%)^2 (cap) | **1.84%** |
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
- `S = 2` (Shared stats)
- `P = 5` (Pool size)
- `E = floor((P + 1) / 3) = floor(6 / 3) = 2` (Expected baseline)

Before the rarity cap, the forged item ends up with between **2** and **7** stats (**2** shared + **0–5** from the pool).

| Luck adjustment<br>(A) | Stats from pool<br>(K) | Forged item stats<br>(T) | Chance<br>(math) | Chance |
| :---: | :---: | :---: | :---: | :---: |
| -2 | 0 | 2 | 28% × 28% (cap) | **7.84%** |
| -1 | 1 | 3 | 28% × 72% | **20.16%** |
| 0 | 2 | 4 | 50% | **50.00%** |
| +1 | 3 | 5 | 22% × 70% | **15.40%** |
| +2 | 4 | 6 | 22% × 30% × 70% | **4.62%** |
| +3 | 5 | 7 | 22% × (30%)^2 (cap) | **1.98%** |

##### Example 2 (Pool size = 7)
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
- `S = 2` (Shared stats)
- `P = 7` (Pool size)
- `E = floor((P + 1) / 3) = floor(8 / 3) = 2` (Expected baseline)

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

#### Tier 4 (Pool size = 8+)

##### Example 1 (Pool size = 12)
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
- `S = 2` (Shared stats)
- `P = 12` (Pool size)
- `E = floor((P + 1) / 3) = floor(13 / 3) = 4` (Expected baseline)

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
## 4. Skills inheritance
<a id="4-skills-inheritance"></a>
This section defines how **granted skills** are inherited when you forge.

- Granted skills are a separate channel from normal **blue stats**.
- They have strict rarity caps (vanilla-aligned), and they do **not** consume your normal **stats slots**.
- Unlike blue stats, **shared skills are not 100% “safe”**: shared skills are kept first, but they can still be lost if the result must be trimmed to the rarity’s **skill cap** due to an overflow, which has a 5% chance to replace the shared skill with a new one from the pool (see section 4.5).

Here are what you can expect:
- **Most items won’t gain skills at all** at low rarities (because the cap is 0).
- **At higher rarities**, you can sometimes carry skills across, or gain one from the ingredient pool, but you will always be limited by the rarity’s **skill cap**.

### 4.1. Granted skills (definition)
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

### 4.2. Skill cap by rarity
<a id="42-skill-cap-by-rarity"></a>

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
<a id="43-shared-vs-pool-skills"></a>

Split granted skills into two lists:

- **Shared skills (Sₛ)**: granted skills present on **both** parents (kept unless we must trim due to cap overflow).
- **Pool skills (Pₛ)**: granted skills present on **only one** parent (rolled).

#### Skill identity (dedupe key)
Use the **skill ID** as the identity key (e.g. `Shout_Whirlwind`, `Projectile_BouncingShield`), not the boost name.

### 4.4. How skills are gained (gated fill)
<a id="44-how-skills-are-gained-gated-fill"></a>

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

### 4.5. Overflow + replace (5%)
<a id="45-overflow--replace-5"></a>

All randomness in this subsection is **host-authoritative** and driven by `forgeSeed` (see Section 1.3).

1. Build `sharedSkills` (deduped) and `poolSkills` (deduped).
2. Keep shared first:
   - `finalSkills = sharedSkills` (trim down to `SkillCap` only if shared exceeds cap).
3. Compute `freeSlots = SkillCap - len(finalSkills)`.
4. Fill free slots with gated gain rolls:
   - For each free slot (at most `freeSlots` attempts):
     - Let `P_remaining = len(poolSkills)`
     - Roll a random number; success chance is `p_attempt = base(rarity) * m(P_remaining)` (Section 4.4).
     - If success: pick 1 random skill from `poolSkills`, add to `finalSkills`, remove it from `poolSkills`, and decrement `freeSlots`.
     - If failure: do nothing for that slot (skills are precious; you do not retry the same slot).
5. Optional “replace” roll: **5% chance**
   - If `poolSkills` is not empty and `finalSkills` is not empty:
     - With 5% chance, replace 1 random skill in `finalSkills` with 1 random skill from remaining `poolSkills`.

#### Example
Assume the forged output rarity is **Divine**, so `SkillCap = 2`.

Parent skills:
- Parent A: `{Shout_Whirlwind, Projectile_SkyShot}`
- Parent B: `{Shout_Whirlwind, Target_SerratedEdge}`

5% chance to have final skills:
- Output: `{Projectile_SkyShot, Target_SerratedEdge}`

Interpretation:
- `Shout_Whirlwind` is shared, so it is kept first; then one pool skill is gained; and the optional 5% swap can change which two skills you end up with (still limited by `SkillCap = 2`).

### 4.6. Scenario tables
<a id="46-scenario-tables"></a>

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
<a id="47-worked-example-divine"></a>

This is a **weapon** example (weapon-only skill boosts).

Assume the rarity system produces a **Divine** forged item:
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
- If the roll succeeds, pick 1 from the pool, e.g. `Projectile_SkyShot`

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

If **exactly one** parent has `RuneSlots = 1`, then the forged item gets `RuneSlots_out = 1` with a **small** chance, otherwise `0`.

$$RuneSlots_{out} \in \{0,1\}$$

Examples (non-Unique):

| Parent A slots | Parent B slots | Forged slots |
| :---: | :---: | :--- |
| 0 | 0 | 0 |
| 1 | 1 | 1 |
| 0 | 1 | 1 with 50%, else 0 |
| 1 | 0 | 1 with 50%, else 0 |
---
## 6. Implementation reference 
<a id="6-implementation-reference"></a>

This section is a developer reference for implementing the rules in this document.

[forging_system_implementation_blueprint_se.md → Appendix: Pseudocode reference](forging_system_implementation_blueprint_se.md#appendix-pseudocode-reference)
