# Rarity System

## 1. System Overview

This module determines the **Rarity (Color)** of any forged item. It operates independently of the item's stats and replaces linear upgrades with a probability distribution system.

#### Multiplayer + RNG note (implementation)
If you sample an actual rarity outcome from the probabilities in this document at runtime, do it **host-authoritatively** and drive the sampling from the forge’s deterministic seed (`forgeSeed`), then replicate the final result to clients.

The system follows three core rules, evaluated in order:

### 1.0. Ingredient eligibility (hard rule)
Weapons with **socketed runes** must **not** be accepted as forging ingredients.

Reject an ingredient if it has:
- Any **runes inserted** into sockets, and/or
- Any **stats modifiers or granted skills originating from rune sockets**.

Empty rune slots are allowed.

### 1.1. The "Unique Dominance" (Global Override)
If **any** ingredient used in the forge is of **Unique** rarity, the forging process shifts logic entirely. The Unique item **consumes** the other ingredient as "fuel."
* **The Logic:** Unique items acts as a dominant base. They are not "mixed" with other items; they are fed by them.
* **The Effect:** The resulting item is guaranteed to be the **original Unique item** (100% chance). Its Rarity remains Unique, and its specific identity is preserved.
    * *Note: The specific mechanics of how the Unique item is empowered or modified by this fuel are governed by a separate "Unique Empowerment System" and are outside the scope of this Rarity Determination document.*

### 1.2. The "Gravity Well" (Mixing Different Rarities)
When combining two items of different quality (and neither is Unique), the forge forces them to meet in the middle.
* **The Logic:** The system calculates the average rarity and pulls the result toward it.
* **The Effect:** This minimizes the chance of "gaming the system." A large gap creates a strong gravity that drags high-rarity items down to a mid-rarity result.

### 1.3. The "Rarity Break" (Mixing Same Rarities)
When combining two items of the exact same quality (and neither is Unique), the forge creates a stable environment with a calculated chance to "Rarity Up" (Ascend).
* **The Logic:** The result is stable, with a small chance to upgrade:
  - Cross-type (default): **9%**
  - Same-type (exact `WeaponType`): **18%**

---

## 2. Data Definitions

### 2.1. Rarities

Each item rarity is assigned a numeric **rarity index** used for calculation.

| Rarity index | Rarity name | Usage note |
| :--- | :--- | :--- |
| **0** | Common | Lowest bound. |
| **1** | Uncommon | |
| **2** | Rare | |
| **3** | Epic | |
| **4** | Legendary | |
| **5** | Divine | |
| **6** | Unique | **Ignored for vNext balancing** (do not consider for now). |

---

## 2.2. Caps (vNext: default + learned, per save)
<a id="22-caps-vnext-default--learned-per-save"></a>

This mod uses **two cap layers**:
- A hidden **default cap** per rarity (baseline; ensures rarity-break results always have a cap).
- A per-save **learned cap** that increases when the player obtains items with higher rollable slot counts.

All cap logic is **host-authoritative** in multiplayer.

### 2.2.1. Overall rollable-slots cap (shared across channels)
<a id="221-overall-rollable-slots-cap"></a>

This is a **single cap** used by forging across three rollable channels:
- Blue stats (stats modifiers)
- ExtraProperties (as a single slot if present)
- Skills (each rollable skill consumes 1 slot)

#### Default overall cap by rarity (baseline)
<a id="2211-default-overall-cap"></a>

This is the baseline used when the save has not learned a higher cap yet:

| Rarity index | Name | Default overall cap |
| :--- | :--- | :---: |
| **0** | Common | **1** |
| **1** | Uncommon | **4** |
| **2** | Rare | **5** |
| **3** | Epic | **5** |
| **4** | Legendary | **5** |
| **5** | Divine | **5** |

#### Learned overall cap by rarity (per save)
<a id="2212-learned-overall-cap"></a>

For each rarity `r`, the save maintains:

`OverallCap[r] = min(5, max(DefaultOverallCap[r], LearnedOverallCap[r]))`

Where `LearnedOverallCap[r]` is the maximum **actual rollable slot count** the player has ever obtained on an item of rarity `r`.

**Update trigger (acquisition only):**
- Update the learned caps only when the player **obtains** an item (loot pickup, reward, vendor purchase).
- Do **not** update on merely viewing vendor inventory.

**Slot counting (actual instance):**
`slots(item) = blueStatLineCount + rollableSkillCount + (hasExtraProperties ? 1 : 0)`

Notes:
- Rune sockets do not count (and socketed runes are forbidden as ingredients anyway).
- Base values do not count.
- ExtraProperties counts as **1** slot regardless of how many internal tokens/tooltip lines it shows.

#### Player notification (cap breakthrough)
<a id="2213-cap-notification"></a>

This system runs silently, except when a learned cap increases past the previous effective cap.

When `OverallCap[r]` increases, show a one-time message:

- “New stats limit for **{RarityName}** is updated to **{OverallCap[r]}**. You can now forge up to **{OverallCap[r]}** rollable slots on **{RarityName}** items (weapons, shields, rings, etc.).”

If the cap jumps by more than +1 (rare), show only the final value once to avoid spam.

### 2.2.2. Skill count cap (vNext: default + learned)
<a id="222-skill-cap-vnext"></a>

Skills are rollable and consume overall slots, but the system also tracks a **per-rarity skill-count cap** to keep the skill channel bounded and “vanilla-feeling” unless the player has already seen higher counts.

#### Default skill cap by rarity (baseline)
<a id="2221-default-skill-cap"></a>

| Rarity index | Name | Default rollable skill cap |
| :--- | :--- | :---: |
| **0** | Common | **1** |
| **1** | Uncommon | **1** |
| **2** | Rare | **1** |
| **3** | Epic | **1** |
| **4** | Legendary | **1** |
| **5** | Divine | **1** |

#### Learned skill cap by rarity (per save)
<a id="2222-learned-skill-cap"></a>

For each rarity `r`, the save maintains:

`SkillCap[r] = max(DefaultSkillCap[r], LearnedSkillCap[r])`

Where `LearnedSkillCap[r]` is the maximum number of rollable granted skills the player has ever obtained on an item of rarity `r`.

This cap can be updated using the same acquisition-trigger rule as the overall cap.

**Notification:** use the same “cap breakthrough” messaging pattern, but with the skill wording:
- “New skill limit for **{RarityName}** is updated to **{SkillCap[r]}**.”

## 3. Global Override: Unique Preservation
*Trigger Condition: `Rarity_A == 6` OR `Rarity_B == 6`*

### 3.1. Logic Description
Before calculating averages or stability, the system checks for the presence of a Unique item. If found, the standard rarity calculation is aborted.

* **Result:** 100% Unique (Rarity 6).
* **Identity:** The result is always the ID of the specific Unique input item.

---

## 4. Standard Inheritance (The Gravity Well)
*Trigger Condition: `Rarity_A != Rarity_B` AND `Neither is Unique`*

### 4.1. Logic Description
The forge creates a "Stability Curve" centered on the mathematical average of the two input rarities.

We use an adjusted **Gaussian Distribution** where the "Spread" ($\sigma$) is dynamic. A wider input gap increases the distance from the mean for the extremes, so the overall result is still strongly pulled toward the middle and extreme outcomes stay unlikely.

### 4.2. Boundary Rules
The result is strictly clamped between the input rarities.
* **Min Rarity:** `Lowest(Rarity_A, Rarity_B)`
* **Max Rarity:** `Highest(Rarity_A, Rarity_B)`

### 4.3. The Probability Formula
**Variables:**
* `M (Mean)` = $(Rarity_A + Rarity_B) / 2$
* `Gap` = $|Rarity_A - Rarity_B|$
* `σ (Sigma)` = $0.5 + (0.12 \times Gap)$

**Calculation:**
For every Rarity `t` between `Min` and `Max`:

$$Weight_t = e^{-\frac{(t - M)^2}{2\sigma^2}}$$

*(Results are normalized so the total probability equals 100%).*

### 4.4. Example Scenarios

#### Scenario 1: The "Wide Gap" (Common + Divine)
* **Input:** Rarity 0 + Rarity 5
* **Outcome:** Extreme pull toward the middle.

| Candidate Rarity | Normalized % | Outcome Verdict |
| :--- | :--- | :--- |
| **Common (0)** | **2.7%** | **Punishment** (Lose Divine) |
| **Uncommon (1)** | **14.2%** | **Low** |
| **Rare (2)** | **33.1%** | **Likely Outcome** |
| **Epic (3)** | **33.1%** | **Likely Outcome** |
| **Legendary (4)** | **14.2%** | **Lucky** |
| **Divine (5)** | **2.7%** | **Jackpot** (Keep Divine) |

#### Scenario 2: The "Narrow Gap" (Epic + Legendary)
* **Input:** Rarity 3 + Rarity 4
* **Outcome:** With only two possible results (clamped between inputs), the distribution is evenly split.

| Candidate Rarity | Normalized % | Outcome Verdict |
| :--- | :--- | :--- |
| **Epic (3)** | **50.0%** | **Likely Outcome** |
| **Legendary (4)** | **50.0%** | **Lucky** (Upgrade) |

---

## 5. Rarity Break (Ascension)
*Trigger Condition: `Rarity_A == Rarity_B` AND `Neither is Unique`*

### 5.1. Logic Description
Identical rarities create a stable environment with a small chance to upgrade ("Ascend").

Weapon-type match modifier:
- **Cross-type (default)**: **9%** chance to Ascend.
- **Same-type** (**exact same `WeaponType`** for weapons): **18%** chance to Ascend (2×).

**Hard Cap Exception:** If the input items are **Divine (Rarity 5)**, the system forces 100% stability.

### 5.2. The Probability Formula
Let `p_break` be the Ascension probability:
- `p_break = 9%` for cross-type (default)
- `p_break = 18%` for same-type (exact same `WeaponType`)

Then (for non-Divine inputs):
- `P(result = Rarity_A) = 1 - p_break`
- `P(result = Rarity_A + 1) = p_break`

### 5.3. Example Scenario (Legendary + Legendary)
* **Input:** Rarity 4 + Rarity 4

| Candidate Rarity | Cross-type (default) | Same-type (exact WeaponType) | Outcome Verdict |
| :--- | ---: | ---: | :--- |
| **Legendary (4)** | **91%** | **82%** | **Stability** (No Change) |
| **Divine (5)** | **9%** | **18%** | **Ascension** (Free Upgrade) |

---

## 6. Implementation reference
- [forging_system_implementation_blueprint_se.md → Appendix: Pseudocode reference](forging_system_implementation_blueprint_se.md#appendix-pseudocode-reference)