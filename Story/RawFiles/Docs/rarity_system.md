# Functional Specification: Rarity Inheritance & Stability System (v1.3)

## 1. System Overview
This module determines the final **Rarity Tier** of a forged item. It replaces linear upgrades with a probability distribution system designed to balance "Smart Crafting" and "Chaotic Crafting."

* **Gravity Well (Different Tiers):** When combining items of different tiers, the result is heavily pulled toward the average tier. This minimizes the chance of "gaming the system" by mixing low-tier and high-tier items.
* **Tier Break (Same Tiers):** When combining items of the same tier, the item creates a stable environment with a calculated chance to "Tier Up" (Ascend).

---

## 2. Data Definitions

### 2.1. Rarity Tiers
Each item rarity is assigned a numeric `TierID` used for calculation.

| Tier ID | Rarity Name | Stable Stat Cap | Usage Note |
| :--- | :--- | :--- | :--- |
| **1** | Common | 1 | Lowest bound. |
| **2** | Uncommon | 2 | |
| **3** | Rare | 3 | |
| **4** | Epic | 4 | |
| **5** | Legendary | 5 | |
| **6** | Divine | 6 | **Hard Cap** for inheritance logic. |

---

## 3. Mechanism A: Standard Inheritance (The Gravity Well)
*Trigger Condition: `Tier_A != Tier_B`*

### 3.1. Logic Description
The forge creates a "Stability Curve" centered on the mathematical average of the two input tiers. The further an outcome is from this center, the less likely it is to happen.

We use an adjusted **Gaussian Distribution** where the "Spread" ($\sigma$) is dynamic. A wider gap between input items creates a stronger "gravity" effect (a tighter curve), forcing the result toward the middle and punishing extremes.

### 3.2. Boundary Rules
The result is strictly clamped between the input tiers to prevent exploiting bounds.
* **Min Tier:** `Lowest(Tier_A, Tier_B)`
* **Max Tier:** `Highest(Tier_A, Tier_B)`

### 3.3. The Probability Formula
**Variables:**
* `M (Mean)` = $(Tier_A + Tier_B) / 2$
* `Gap` = $|Tier_A - Tier_B|$
* `σ (Sigma)` = $0.5 + (0.12 \times Gap)$

**Calculation:**
For every Tier `t` between `Min` and `Max`:

$$Weight_t = e^{-\frac{(t - M)^2}{2\sigma^2}}$$

*(Results are normalized so the total probability equals 100%).*

### 3.4. Example Scenarios

#### Scenario 1: The "Wide Gap" (Common + Divine)
* **Input:** Tier 1 + Tier 6
* **Mean:** 3.5
* **Spread ($\sigma$):** 1.1
* **Outcome:** Extreme pull toward the middle. There is a high risk of losing the Divine tier.

| Candidate Tier | Normalized % | Outcome Verdict |
| :--- | :--- | :--- |
| **Common (1)** | **2.7%** | **Punishment** (Lose Divine) |
| **Uncommon (2)** | **14.2%** | **Low** |
| **Rare (3)** | **33.1%** | **Likely Outcome** |
| **Epic (4)** | **33.1%** | **Likely Outcome** |
| **Legendary (5)** | **14.2%** | **Lucky** |
| **Divine (6)** | **2.7%** | **Jackpot** (Keep Divine) |

#### Scenario 2: The "Standard Gap" (Rare + Legendary)
* **Input:** Tier 3 + Tier 5
* **Mean:** 4.0
* **Spread ($\sigma$):** 0.74
* **Outcome:** High stability around Epic.

| Candidate Tier | Normalized % | Outcome Verdict |
| :--- | :--- | :--- |
| **Rare (3)** | **22.2%** | **Downgrade** |
| **Epic (4)** | **55.6%** | **Stabilized** |
| **Legendary (5)** | **22.2%** | **Status Quo** |

---

## 4. Mechanism B: Tier Break (Ascension)
*Trigger Condition: `Tier_A == Tier_B`*

### 4.1. Logic Description
Identical tiers create a highly stable environment (~88% chance to remain the same) with a small chance to "Break" the ceiling and upgrade (~12%).

**Hard Cap Exception:** If the input items are **Divine (Tier 6)**, the system forces 100% stability. Divine items cannot upgrade further via this mechanic.

### 4.2. The Probability Formula
* `M (Mean)` = `Tier_A`
* `σ (Sigma)` = `0.5` (Fixed constant for maximum stability)
* `Max Tier Bound` = `Tier_A + 1`

### 4.3. Example Scenario (Rare + Rare)
* **Input:** Tier 3 + Tier 3

| Candidate Tier | Normalized % | Outcome Verdict |
| :--- | :--- | :--- |
| **Rare (3)** | **88.1%** | **Stability** (No Change) |
| **Epic (4)** | **11.9%** | **Ascension** (Free Upgrade) |

---

## 5. Implementation Plan (Pseudocode)

```python
FUNCTION GetRarityDistribution(Tier_A, Tier_B):

    GLOBAL_MAX_CAP = 6  # Divine Tier ID

    # 1. DEFINE BOUNDS
    Min_T = MIN(Tier_A, Tier_B)

    # HANDLING SAME TIER SCENARIOS
    IF Tier_A == Tier_B:
        # EXCEPTION: Divine + Divine = 100% Divine
        IF Tier_A >= GLOBAL_MAX_CAP:
            RETURN { Tier_A : 1.0 }

        # Standard Tier Break
        Max_T = Tier_A + 1
        Sigma = 0.5  # Fixed tight spread for stability

    # HANDLING DIFF TIER SCENARIOS
    ELSE:
        Max_T = MAX(Tier_A, Tier_B)
        Gap = ABS(Tier_A - Tier_B)
        # 0.12 Multiplier strengthens gravity for wider gaps
        Sigma = 0.5 + (0.12 * Gap)

    # 2. CALCULATE WEIGHTS (Gaussian Loop)
    Mean = (Tier_A + Tier_B) / 2
    Weights = {}
    Total_Weight = 0

    FOR t FROM Min_T TO Max_T:
        # Formula: e^(-((x-u)^2) / (2s^2))
        Raw_W = EXP( -1 * ((t - Mean)^2) / (2 * Sigma^2) )
        Weights[t] = Raw_W
        Total_Weight = Total_Weight + Raw_W

    # 3. NORMALIZE TO PERCENTAGE
    Final_Probs = {}
    FOR t FROM Min_T TO Max_T:
        Final_Probs[t] = Weights[t] / Total_Weight

    RETURN Final_Probs