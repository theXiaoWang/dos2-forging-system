# Functional Specification: Rarity Determination System (v1.5)

## 1. System Overview

This module determines the **Rarity (Color)** of any forged item. It operates independently of the item's stats and replaces linear upgrades with a probability distribution system.

The system follows three core rules, evaluated in order:

### 1.0. Ingredient eligibility (hard rule)
Weapons that have **any rune socket effects** must **not** be accepted as forging ingredients.

Reject an ingredient if it has:
- Any **runes inserted** into sockets, and/or
- Any **stats modifiers or granted skills originating from rune sockets**.

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
* **The Logic:** The result is stable (~88% chance to stay) with a small chance (~12%) to upgrade.

---

## 2. Data Definitions

### 2.1. Rarities

Each item rarity is assigned a numeric `RarityID` used for calculation.

| Rarity ID | Rarity Name | Max Stat Cap (this mod) | Vanilla rollable boost slots (non-rune) | Usage Note |
| :--- | :--- | :--- | :--- | :--- |
| **1** | Common | 1 | 0..0 | Lowest bound. |
| **2** | Uncommon | 4 | 2..4 | |
| **3** | Rare | 5 | 3..5 | |
| **4** | Epic | 6 | 4..6 | |
| **5** | Legendary | 7 | 4..6 | |
| **6** | Divine | 8 | 5..7 | **Hard Cap** for standard inheritance. |
| **8** | Unique | 10 | 0..0 | **Dominant Rarity.** Acts as the "Consumer." |

---

#### Notes on “Vanilla rollable boost slots”
- These values come from `DefEd/Data/Editor/Mods/Shared/Stats/ItemTypes/ItemTypes.stats`.
- They represent the **min..max count of non-rune boost picks** (i.e. excluding `RuneEmpty`) across the level-dependent `_substat_*` rows.
- Vanilla **Unique** items are largely hand-authored rather than generated from this roll-slot system, hence `0..0` here.

## 3. Global Override: Unique Preservation
*Trigger Condition: `Rarity_A == 8` OR `Rarity_B == 8`*

### 3.1. Logic Description
Before calculating averages or stability, the system checks for the presence of a Unique item. If found, the standard rarity calculation is aborted.

* **Result:** 100% Unique (Rarity 8).
* **Identity:** The result is always the ID of the specific Unique input item.

---

## 4. Mechanism A: Standard Inheritance (The Gravity Well)
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
* **Input:** Rarity 1 + Rarity 6
* **Outcome:** Extreme pull toward the middle.

| Candidate Rarity | Normalized % | Outcome Verdict |
| :--- | :--- | :--- |
| **Common (1)** | **2.7%** | **Punishment** (Lose Divine) |
| **Uncommon (2)** | **14.2%** | **Low** |
| **Rare (3)** | **33.1%** | **Likely Outcome** |
| **Epic (4)** | **33.1%** | **Likely Outcome** |
| **Legendary (5)** | **14.2%** | **Lucky** |
| **Divine (6)** | **2.7%** | **Jackpot** (Keep Divine) |

#### Scenario 2: The "Narrow Gap" (Epic + Legendary)
* **Input:** Rarity 4 + Rarity 5
* **Outcome:** With only two possible results (clamped between inputs), the distribution is evenly split.

| Candidate Rarity | Normalized % | Outcome Verdict |
| :--- | :--- | :--- |
| **Epic (4)** | **50.0%** | **Likely Outcome** |
| **Legendary (5)** | **50.0%** | **Lucky** (Upgrade) |

---

## 5. Mechanism B: Rarity Break (Ascension)
*Trigger Condition: `Rarity_A == Rarity_B` AND `Neither is Unique`*

### 5.1. Logic Description
Identical rarities create a highly stable environment (~88% chance to remain the same) with a small chance to upgrade (~12%).

**Hard Cap Exception:** If the input items are **Divine (Rarity 6)**, the system forces 100% stability.

### 5.2. The Probability Formula
* `M (Mean)` = `Rarity_A`
* `σ (Sigma)` = `0.5` (Fixed constant)
* `Max Rarity Bound` = `Rarity_A + 1`

### 5.3. Example Scenario (Legendary + Legendary)
* **Input:** Rarity 5 + Rarity 5

| Candidate Rarity | Normalized % | Outcome Verdict |
| :--- | :--- | :--- |
| **Legendary (5)** | **88.1%** | **Stability** (No Change) |
| **Divine (6)** | **11.9%** | **Ascension** (Free Upgrade) |

---

## 6. Implementation Plan (Pseudocode)

```python
FUNCTION GetRarityDistribution(Rarity_A, Rarity_B):

    UNIQUE_ID = 8
    GLOBAL_MAX_CAP = 6  # Divine Rarity ID

    # 1. GLOBAL OVERRIDE: UNIQUE DOMINANCE
    # If either item is Unique, it consumes the other. 
    # The output rarity is strictly Unique.
    IF Rarity_A == UNIQUE_ID OR Rarity_B == UNIQUE_ID:
        RETURN { UNIQUE_ID : 1.0 }

    # 2. DEFINE BOUNDS
    Min_T = MIN(Rarity_A, Rarity_B)

    # 3. HANDLING SAME RARITY SCENARIOS
    IF Rarity_A == Rarity_B:
        # EXCEPTION: Divine + Divine = 100% Divine
        IF Rarity_A >= GLOBAL_MAX_CAP:
            RETURN { Rarity_A : 1.0 }

        # Standard Rarity Break
        Max_T = Rarity_A + 1
        Sigma = 0.5  # Fixed tight spread for stability

    # 4. HANDLING DIFF RARITY SCENARIOS
    ELSE:
        Max_T = MAX(Rarity_A, Rarity_B)
        Gap = ABS(Rarity_A - Rarity_B)
        # 0.12 Multiplier strengthens gravity for wider gaps
        Sigma = 0.5 + (0.12 * Gap)

    # 5. CALCULATE WEIGHTS (Gaussian Loop)
    Mean = (Rarity_A + Rarity_B) / 2
    Weights = {}
    Total_Weight = 0

    FOR t FROM Min_T TO Max_T:
        # Formula: e^(-((x-u)^2) / (2s^2))
        Raw_W = EXP( -1 * ((t - Mean)^2) / (2 * Sigma^2) )
        Weights[t] = Raw_W
        Total_Weight = Total_Weight + Raw_W

    # 6. NORMALIZE TO PERCENTAGE
    Final_Probs = {}
    FOR t FROM Min_T TO Max_T:
        Final_Probs[t] = Weights[t] / Total_Weight

    RETURN Final_Probs