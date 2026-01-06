# Rarity System

## 1. System Overview

This module determines the **Rarity (Color)** of any forged item. It operates independently of the item's stats and replaces linear upgrades with a probability distribution system.

#### Multiplayer + RNG note (implementation)

If you sample an actual rarity outcome from the probabilities in this document at runtime, do it **host-authoritatively** and drive the sampling from the forge's deterministic seed (`forgeSeed`), then replicate the final result to clients.

The system follows three core rules, evaluated in order:

### 1.0. Ingredient eligibility (hard rule)

Items with **socketed runes** must **not** be accepted as forging ingredients (see [`forging_system.md` → Section 1.1](forging_system.md#11-ingredient-eligibility) for details).

Reject an ingredient if it has:

- Any **runes inserted** into sockets, and/or
- Any **stats modifiers or granted skills originating from rune sockets**.

Empty rune slots are allowed.

### 1.1. The "Unique Dominance" (Global Override)

If **any** ingredient used in the forge is of **Unique** rarity, the forging process shifts logic entirely. The Unique item **consumes** the other ingredient as "fuel."

- **The Logic:** Unique items act as a dominant base. They are not "mixed" with other items; they are fed by them.
- **The Effect:** The resulting item is guaranteed to be the **original Unique item** (100% chance). Its Rarity remains Unique, and its specific identity is preserved.
  - _Note: The specific mechanics of how the Unique item is empowered or modified by this fuel are governed by a separate "Unique Empowerment System" and are outside the scope of this Rarity Determination document._

### 1.2. The "Gravity Well" (Mixing Different Rarities)

When combining two items of different quality (and neither is Unique), the forge forces them to meet in the middle.

- **The Logic:** The system calculates the average rarity and pulls the result toward it.
- **The Effect:** This minimizes the chance of "gaming the system." A large gap creates a strong gravity that drags high-rarity items down to a mid-rarity result.

### 1.3. The "Rarity Break" (Mixing Same Rarities)

When combining two items of the exact same quality (and neither is Unique), the forge creates a stable environment with a calculated chance to "Rarity Up" (Ascend).

- **The Logic:** The result is stable, with a small chance to upgrade:
  - Cross-type (default): **5%**
  - Same-type (exact `WeaponType`): **10%**

---

## 2. Item Classification

This system classifies items into three distinct types, each with different forging behaviours and cap rules.

### 2.1. Vanilla Items

<a id="21-vanilla-items"></a>

**Vanilla items** are standard items that follow the normal rarity table and caps. These are the most common item type.

- **Cap behaviour:** Vanilla items adhere to `DefaultOverallCap[r]` based on their rarity index `r`.
- **Forging:** When forging vanilla items, the standard rarity determination rules apply (see [Section 1](#1-system-overview) for details).
- **ExtraProperties:** Internal ExtraProperties token cap follows the rarity cap table (0-5 based on output rarity; see [`forging_system.md` → Section 4.5.3](forging_system.md#453-extraproperties-selection--internal-cap)).

### 2.2. Unique Items

<a id="22-unique-items"></a>

**Unique items** are special items with rarity index 6. They have distinct forging behaviour that overrides standard rules.

- **Rarity:** Always rarity index 6 (Unique).
- **Forging:** When a Unique item is used in forging, it consumes the other ingredient as "fuel" (see [Section 4](#4-global-override-unique-preservation) for details).
- **Identity preservation:** The Unique item's specific identity is preserved during forging.
- **Caps:** Unique items use a per-instance cap system (`UniqueMaxSlots`) rather than the global rarity cap table.

### 2.3. Mutant Items

<a id="23-mutant-items"></a>

**Mutant items** are vanilla game items that exceed the normal rarity cap for their rarity. They can appear in any rarity (Common through Divine).

**Mutant detection:**

An item is considered a "mutant" if:

`slots(item) > DefaultOverallCap[item.rarity]`

Where `slots(item) = blueStatLineCount + rollableSkillCount + (hasExtraProperties ? 1 : 0)`

**Mutant forging rules:**

1. **Mutant + Regular (Vanilla) item:**
   - The forged result follows the normal rarity cap table.
   - `OverallCap = DefaultOverallCap[Rarity_out]`
   - The mutant's excess modifiers do not bypass the cap.
   - Internal ExtraProperties token cap follows the normal rarity cap table (based on output rarity).

2. **Mutant + Mutant:**
   - The forged result bypasses the rarity cap table.
   - `OverallCap = max(slots(parentA), slots(parentB))`
   - The cap is determined by the maximum modifier count from either parent, with no upper limit from the rarity table.
   - **Internal ExtraProperties token cap is also bypassed:** No limit on the number of EP tokens (the rarity-based cap does not apply).
   - **Important:** This exception always applies for Mutant+Mutant forging, regardless of rarity break outcomes. Even if a rarity break occurs during forging, the mutant rules take precedence.

**Notes:**

- Mutant items can be in any rarity (Common, Uncommon, Rare, Epic, Legendary, or Divine).
- Currently, there is no known way to create mutant items in-game, but if they appear (e.g., from vanilla game data), the system handles them according to these rules.
- For detailed cap calculation rules, see [Section 3.2.1.2](#3212-mutant-item-exception).

---

## 3. Data Definitions

### 3.1. Rarities

Each item rarity is assigned a numeric **rarity index** used for calculation.

| Rarity index | Rarity name | Usage note                                                 |
| :----------- | :---------- | :--------------------------------------------------------- |
| **0**        | Common      | Lowest bound.                                              |
| **1**        | Uncommon    |                                                            |
| **2**        | Rare        |                                                            |
| **3**        | Epic        |                                                            |
| **4**        | Legendary   |                                                            |
| **5**        | Divine      |                                                            |
| **6**        | Unique      | **Ignored for vNext balancing** (do not consider for now). |

---

## 3.2. Caps (default by rarity)

<a id="32-caps-default-by-rarity"></a>

This mod uses a **default cap per rarity** that applies to all non-unique items. The cap is fixed and does not change based on items obtained.

All cap logic is **host-authoritative** in multiplayer.

### 3.2.1. Overall rollable-slots cap (shared across channels)

<a id="321-overall-rollable-slots-cap"></a>

This is a **single cap** used by forging across three rollable channels:

- Blue stats (stats modifiers)
- ExtraProperties (as a single slot if present)
- Skills (each rollable skill consumes 1 slot)

#### Overall cap by rarity

<a id="3211-overall-cap-by-rarity"></a>

The overall cap is determined solely by the output rarity:

| Rarity index | Name      | Default overall cap |
| :----------- | :-------- | :-----------------: |
| **0**        | Common    |        **0**        |
| **1**        | Uncommon  |        **1**        |
| **2**        | Rare      |        **2**        |
| **3**        | Epic      |        **3**        |
| **4**        | Legendary |        **4**        |
| **5**        | Divine    |        **5**        |
| **6**        | Unique    |        **X**        |

**Formula:**

For non-unique items, the overall cap is determined as follows:

1. **Normal case (regular items):**
   `OverallCap[r] = DefaultOverallCap[r]`
   Where `r` is the output rarity index.

2. **Mutant case (see [Section 2.3](#23-mutant-items) and [Mutant item exception](#3212-mutant-item-exception) below):**
   - Mutant + Regular: `OverallCap = DefaultOverallCap[Rarity_out]` (normal cap applies)
   - Mutant + Mutant: `OverallCap = max(slots(parentA), slots(parentB))` (bypasses rarity table)

#### Mutant item exception (vanilla overcap items)

<a id="3212-mutant-item-exception"></a>

**Mutant items** are vanilla game items that exceed the normal rarity cap for their rarity (e.g., a Rare item with 4 modifiers when the cap should be 2).

**Mutant detection:**

An item is considered a "mutant" if:

`slots(item) > DefaultOverallCap[item.rarity]`

Where `slots(item) = blueStatLineCount + rollableSkillCount + (hasExtraProperties ? 1 : 0)`

**Mutant forging rules:**

1. **Mutant + Regular item:**
   - The forged result follows the normal rarity cap table.
   - `OverallCap = DefaultOverallCap[Rarity_out]`
   - The mutant's excess modifiers do not bypass the cap.

2. **Mutant + Mutant:**
   - The forged result bypasses the rarity cap table.
   - `OverallCap = max(slots(parentA), slots(parentB))`
   - The cap is determined by the maximum modifier count from either parent, with no upper limit from the rarity table.
   - **Internal ExtraProperties token cap is also bypassed:** No limit on the number of EP tokens (the rarity-based cap does not apply).
   - **Skills cap is also bypassed:** All skills from both parents can enter the pool and be selected without the skill cap limit (see [`forging_system.md` → Section 4.6](forging_system.md#46-skills-inheritance) for details).
   - **Important:** This exception always applies for Mutant+Mutant forging, regardless of rarity break outcomes. Even if a rarity break occurs during forging, the mutant rules take precedence.

**Slot counting (actual instance):**
`slots(item) = blueStatLineCount + rollableSkillCount + (hasExtraProperties ? 1 : 0)`

Notes:

- Rune sockets do not count (and socketed runes are forbidden as ingredients anyway).
- Base values do not count.
- ExtraProperties counts as **1** slot regardless of how many internal tokens/tooltip lines it shows.

### 3.2.2. Skill count cap (vNext: default + learned)

<a id="322-skill-cap-vnext"></a>

Skills are rollable and consume overall slots, but the system also tracks a **per-rarity skill-count cap** to keep the skill channel bounded and “vanilla-feeling” unless the player has already seen higher counts.

#### Default skill cap by rarity (baseline)

<a id="3221-default-skill-cap"></a>

| Rarity index | Name      | Default rollable skill cap |
| :----------- | :-------- | :------------------------: |
| **0**        | Common    |           **1**            |
| **1**        | Uncommon  |           **1**            |
| **2**        | Rare      |           **1**            |
| **3**        | Epic      |           **1**            |
| **4**        | Legendary |           **1**            |
| **5**        | Divine    |           **1**            |

#### Learned skill cap by rarity (per save)

<a id="3222-learned-skill-cap"></a>

For each rarity `r`, the save maintains:

`SkillCap[r] = max(DefaultSkillCap[r], LearnedSkillCap[r])`

Where `LearnedSkillCap[r]` is the maximum number of rollable granted skills the player has ever obtained on an item of rarity `r`.

This cap can be updated using the same acquisition-trigger rule as the overall cap.

**Notification:** use the same “cap breakthrough” messaging pattern, but with the skill wording:

- “New skill limit for **{RarityName}** is updated to **{SkillCap[r]}**.”

## 4. Global Override: Unique Preservation

_Trigger Condition: `Rarity_A == 6` OR `Rarity_B == 6`_

### 4.1. Logic Description

Before calculating averages or stability, the system checks for the presence of a Unique item. If found, the standard rarity calculation is aborted.

- **Result:** 100% Unique (Rarity 6).
- **Identity:** The result is always the ID of the specific Unique input item.

---

## 5. Standard Inheritance (The Gravity Well)

_Trigger Condition: `Rarity_A != Rarity_B` AND `Neither is Unique`_

### 5.1. Logic Description

The forge creates a "Stability Curve" centered on the mathematical average of the two input rarities.

We use an adjusted **Gaussian Distribution** where the "Spread" ($\sigma$) is dynamic. A wider input gap increases the distance from the mean for the extremes, so the overall result is still strongly pulled toward the middle and extreme outcomes stay unlikely.

### 5.2. Boundary Rules

The result is strictly clamped between the input rarities.

- **Min Rarity:** `Lowest(Rarity_A, Rarity_B)`
- **Max Rarity:** `Highest(Rarity_A, Rarity_B)`

### 5.3. The Probability Formula

**Variables:**

- `M (Mean)` = $(Rarity_A + Rarity_B) / 2$
- `Gap` = $|Rarity_A - Rarity_B|$
- `σ (Sigma)` = $0.5 + (0.12 \times Gap)$

**Calculation:**
For every Rarity `t` between `Min` and `Max`:

$$Weight_t = e^{-\frac{(t - M)^2}{2\sigma^2}}$$

_(Results are normalized so the total probability equals 100%)._

### 5.4. Example Scenarios

#### Scenario 1: The "Wide Gap" (Common + Divine)

- **Input:** Rarity 0 + Rarity 5
- **Outcome:** Extreme pull toward the middle.

| Candidate Rarity  | Normalized % | Outcome Verdict              |
| :---------------- | :----------- | :--------------------------- |
| **Common (0)**    | **2.7%**     | **Punishment** (Lose Divine) |
| **Uncommon (1)**  | **14.2%**    | **Low**                      |
| **Rare (2)**      | **33.1%**    | **Likely Outcome**           |
| **Epic (3)**      | **33.1%**    | **Likely Outcome**           |
| **Legendary (4)** | **14.2%**    | **Lucky**                    |
| **Divine (5)**    | **2.7%**     | **Jackpot** (Keep Divine)    |

#### Scenario 2: The "Narrow Gap" (Epic + Legendary)

- **Input:** Rarity 3 + Rarity 4
- **Outcome:** With only two possible results (clamped between inputs), the distribution is evenly split.

| Candidate Rarity  | Normalized % | Outcome Verdict     |
| :---------------- | :----------- | :------------------ |
| **Epic (3)**      | **50.0%**    | **Likely Outcome**  |
| **Legendary (4)** | **50.0%**    | **Lucky** (Upgrade) |

---

## 6. Rarity Break (Ascension)

_Trigger Condition: `Rarity_A == Rarity_B` AND `Neither is Unique`_

### 6.1. Logic Description

Identical rarities create a stable environment with a small chance to upgrade ("Ascend").

Weapon-type match modifier:

- **Cross-type (default)**: **5%** chance to Ascend.
- **Same-type** (**exact same `WeaponType`** for weapons): **10%** chance to Ascend (2×).

**Hard Cap Exception:** If the input items are **Divine (Rarity 5)**, the system forces 100% stability.

### 6.2. The Probability Formula

Let `p_break` be the Ascension probability:

- `p_break = 5%` for cross-type (default)
- `p_break = 10%` for same-type (exact same `WeaponType`)

Then (for non-Divine inputs):

- `P(result = Rarity_A) = 1 - p_break`
- `P(result = Rarity_A + 1) = p_break`

### 6.3. Example Scenario (Legendary + Legendary)

- **Input:** Rarity 4 + Rarity 4

| Candidate Rarity  | Cross-type (default) | Same-type (exact WeaponType) | Outcome Verdict              |
| :---------------- | -------------------: | ---------------------------: | :--------------------------- |
| **Legendary (4)** |              **95%** |                      **90%** | **Stability** (No Change)    |
| **Divine (5)**    |               **5%** |                      **10%** | **Ascension** (Free Upgrade) |

---

## 7. Implementation reference

- [forging_system_implementation_blueprint_se.md → Appendix: Pseudocode reference](forging_system_implementation_blueprint_se.md#appendix-pseudocode-reference)
