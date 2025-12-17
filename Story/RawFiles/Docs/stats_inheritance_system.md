# Functional Specification: Stat Inheritance System (v3.0)

## 1. System Overview

This module determines which **Stats** (blue text stats) are inherited from parent items to the child item.

**Crucial Order of Operations:**
1.  **Rarity First (The Container):** The system *must* run the **[Rarity System](rarity_system.md)** first. This sets the **Stat Cap** (The most stats that an item can have).
2.  **Stats Second (The Content):** The system then calculates the **Inherited Stats**.
3.  **Conflict Resolution (The Purge):** If the Inherited Stats exceed the Rarity Cap (e.g., due to a Descension), the system effectively deletes the excess stats.

The logic uses a **"Safe Crafting"** core with a **"Double-Ended Dynamic Slope"**:
* **Safe Crafting:** Matching stats reduces the "Volatile Pool," forcing the system into safer difficulty tiers.
* **The Dynamic Slope:** Probability is not a flat roll. It is a recursive chain. Lucky rolls can trigger an "Ascension Chain" (Jackpots), while unlucky rolls trigger a "Descension Chain" (Collapse).

---

## 2. Data Definitions

### 2.1. The Stat Buckets
* **Guaranteed List ($G$):** Stats present on **BOTH** parents. (Protected).
* **Volatile Pool ($P$):** Stats present on **ONLY ONE** parent. (Rolled for).

### 2.2. The Unified Cap
Defined by the **[Rarity System](rarity_system.md)**.

| Rarity ID | Name | Max Stat Slots |
| :--- | :--- | :--- |
| **1** | Common | **1** |
| **2** | Uncommon | **2** |
| **3** | Rare | **4** |
| **4** | Epic | **6** |
| **5** | Legendary | **7** |
| **6** | Divine | **8** |
| **8** | Unique | **10** |

---

## 3. The Logic Flow

### Step 1: Sorting
Compare Parent A and Parent B.
* Overlaps $\rightarrow$ **List G** (Safe).
* Unique Lines $\rightarrow$ **List P** (Volatile).

### Step 2: Difficulty Calculation ($V_{avg}$)
Calculate the baseline expectation for the Volatile Pool.

$$V_{avg} = Round\left(\frac{Count(P)}{2}\right)$$

*(Note: 0.5 rounds UP).*

### Step 3: Tier Assignment
Assign a Difficulty Tier based on the size of the Pool ($P$).

| Pool Size ($P$) | Difficulty Tier | Base Probability (Bad / Std / Good) | Chain Risk (Descend / Ascend) |
| :--- | :--- | :--- | :--- |
| **1** | **Tier 1 (Safe)** | 0% / 50% / 50% | **None** |
| **2 - 4** | **Tier 2 (Early)** | 12% / 50% / 38% | **12% / 22%** |
| **5 - 7** | **Tier 3 (Mid)** | 28% / 50% / 22% | **28% / 30%** |
| **8+** | **Tier 4 (Risky)** | 45% / 40% / 15% | **45% / 30%** |

### Step 4: The Dynamic Slope Roll (The Chain)
The system calculates `Variance` by rolling against the Base Probability, then entering a recursive loop if a Chain is triggered.

1.  **Standard (0):** Stop. `Variance = 0`.
2.  **Bad Luck (-1):** `Variance = -1`. Roll Chain Risk (Descension).
    * *If Hit:* `Variance -= 1`. Repeat Roll.
    * *If Miss:* Stop.
3.  **Good Luck (+1):** `Variance = +1`. Roll Chain Risk (Ascension).
    * *If Hit:* `Variance += 1`. Repeat Roll.
    * *If Miss:* Stop.

### Step 5: Final Compilation & Cap Enforcement
1.  **Calculate Target:** `Target_Count = Length(G) + V_avg + Variance`.
2.  **Compile:** Add all $G$. Add random stats from $P$ until `Target_Count` is reached.
3.  **Enforce Cap (The Purge):** If `Count > Rarity_Cap`, **discard stats** (Prioritizing deleting Pool stats first) until the limit is met.

---

## 4. Probability Distributions (The Slope)

### 4.1. Tier 1 (Safe Scenario)
*Context: Starting items, Pool size 1. $V_{avg} \approx 1$.*

**Example 1:**
```
Item A: [Strength, Finesse]     (2 stats)
Item B: [Strength]              (1 stat)
─────────────────────────────────────────
Overlap (Guaranteed): [Strength]  (1 stat)
Pool (Volatile):      [Finesse]   (1 stat)
```

**Example 2:**
```
Item A: [Strength, Finesse, Constitution]  (3 stats)
Item B: [Strength, Finesse]                (2 stats)
─────────────────────────────────────────────────────
Overlap (Guaranteed): [Strength, Finesse]  (2 stats)
Pool (Volatile):      [Constitution]        (1 stat)
```

*Risks:* **0%** Chance to continue falling / **0%** Chance to continue rising. (No chains possible)

| Outcome Classification | Variance | Probability Formula | Final % |
| :--- | :--- | :--- | :--- |
| **Standard** | 0 | $50\%$ (Flat) | **50.00%** |
| **Win** | +1 | $50\%$ (No chain) | **50.00%** |

### 4.2. Tier 2 (Early-Game Scenario)
*Context: Early items, Pool size 2-4. $V_{avg} \approx 1-2$.*

**Example 1:**
```
Item A: [Strength, Finesse, Constitution]  (3 stats)
Item B: [Strength, Wits]                   (2 stats)
─────────────────────────────────────────────────────
Overlap (Guaranteed): [Strength]            (1 stat)
Pool (Volatile):      [Finesse, Constitution, Wits]  (3 stats)
```

**Example 2:**
```
Item A: [Strength, Finesse, Constitution, Intelligence]  (4 stats)
Item B: [Strength, Finesse, Wits, Memory]               (4 stats)
─────────────────────────────────────────────────────────────────────
Overlap (Guaranteed): [Strength, Finesse]                (2 stats)
Pool (Volatile):      [Constitution, Intelligence, Wits, Memory]  (4 stats)
```

*Risks (Example 1, Pool size 3):* **12%** Chance to continue falling / **0%** Chance to continue rising. (Capped at +1)

| Outcome Classification | Variance | Probability Formula | Final % |
| :--- | :--- | :--- | :--- |
| **Minor Loss** | -2 | $12\% \times 12\%$ (Cap) | **1.44%** |
| **Loss** | -1 | $12\% \times 88\%$ (Stop) | **10.56%** |
| **Standard** | 0 | $50\%$ (Flat) | **50.00%** |
| **Win** | +1 | $38\%$ (Capped at +1) | **38.00%** |

*Risks (Example 2, Pool size 4):* **12%** Chance to continue falling / **22%** Chance to continue rising.

| Outcome Classification | Variance | Probability Formula | Final % |
| :--- | :--- | :--- | :--- |
| **Minor Loss** | -2 | $12\% \times 12\%$ (Cap) | **1.44%** |
| **Loss** | -1 | $12\% \times 88\%$ (Stop) | **10.56%** |
| **Standard** | 0 | $50\%$ (Flat) | **50.00%** |
| **Win** | +1 | $38\% \times 78\%$ (Stop) | **29.64%** |
| **Jackpot** | +2 | $38\% \times 22\%$ (Cap) | **8.36%** |

### 4.3. Tier 3 (Mid-Game Scenario)
*Context: Decent items, Pool size 5-7. $V_{avg} \approx 3-4$.*

**Example 1:**
```
Item A: [Strength, Finesse, Constitution, Intelligence, Memory]  (5 stats)
Item B: [Strength, Finesse, Warfare, Pyrokinetic]                (4 stats)
─────────────────────────────────────────────────────────────────────
Overlap (Guaranteed): [Strength, Finesse]                        (2 stats)
Pool (Volatile):      [Constitution, Intelligence, Memory, Warfare, Pyrokinetic]  (5 stats)
```

**Example 2:**
```
Item A: [Strength, Finesse, Constitution, Intelligence, Wits, Memory]  (6 stats)
Item B: [Strength, Finesse, Warfare, Pyrokinetic, Hydrosophist]        (5 stats)
─────────────────────────────────────────────────────────────────────────────────────
Overlap (Guaranteed): [Strength, Finesse]                                (2 stats)
Pool (Volatile):      [Constitution, Intelligence, Wits, Memory, Warfare, Pyrokinetic, Hydrosophist]  (7 stats)
```

*Risks (Example 1, Pool size 5):* **28%** Chance to continue falling / **30%** Chance to continue rising.

| Outcome Classification | Variance | Probability Formula | Final % |
| :--- | :--- | :--- | :--- |
| **Deep Loss** | -3 | $28\% \times 28\%^2$ (Cap) | **2.20%** |
| **Major Loss** | -2 | $28\% \times 28\% \times 72\%$ (Stop) | **5.64%** |
| **Loss** | -1 | $28\% \times 72\%$ (Stop) | **20.16%** |
| **Standard** | 0 | $50\%$ (Flat) | **50.00%** |
| **Win** | +1 | $22\% \times 70\%$ (Stop) | **15.40%** |
| **Jackpot** | +2 | $22\% \times 30\%$ (Cap) | **6.60%** |

*Risks (Example 2, Pool size 7):* **28%** Chance to continue falling / **30%** Chance to continue rising.

| Outcome Classification | Variance | Probability Formula | Final % |
| :--- | :--- | :--- | :--- |
| **Spiral** | -4 | $28\% \times 28\%^3$ (Cap) | **0.61%** |
| **Deep Loss** | -3 | $28\% \times 28\%^2 \times 72\%$ (Stop) | **1.58%** |
| **Major Loss** | -2 | $28\% \times 28\% \times 72\%$ (Stop) | **5.64%** |
| **Loss** | -1 | $28\% \times 72\%$ (Stop) | **20.16%** |
| **Standard** | 0 | $50\%$ (Flat) | **50.00%** |
| **Win** | +1 | $22\% \times 70\%$ (Stop) | **15.40%** |
| **Jackpot** | +2 | $22\% \times 30\% \times 70\%$ (Stop) | **4.62%** |
| **Legend** | +3 | $22\% \times 30\%^2$ (Cap) | **1.98%** |

### 4.4. Tier 4 (End-Game Chaos)
*Context: Mismatched items, Pool size 8+. $V_{avg} \approx 4-5$.*

**Example 1:**
```
Item A: [Strength, Finesse, Constitution, Intelligence, Wits, Memory]     (6 stats)
Item B: [Strength, Warfare, Pyrokinetic, Hydrosophist, Aerotheurge, Geomancer, Necromancer]  (7 stats)
─────────────────────────────────────────────────────────────────────────────────────────────
Overlap (Guaranteed): [Strength]                                          (1 stat)
Pool (Volatile):      [Finesse, Constitution, Intelligence, Wits, Memory, Warfare, Pyrokinetic, Hydrosophist, Aerotheurge, Geomancer, Necromancer]  (11 stats)
```

**Example 2:**
```
Item A: [Strength, Finesse, Constitution, Intelligence, Wits, Memory, Warfare]        (7 stats)
Item B: [Strength, Pyrokinetic, Hydrosophist, Aerotheurge, Geomancer, Necromancer, Huntsman, Scoundrel]  (8 stats)
─────────────────────────────────────────────────────────────────────────────────────────────────────────────
Overlap (Guaranteed): [Strength]                                                       (1 stat)
Pool (Volatile):      [Finesse, Constitution, Intelligence, Wits, Memory, Warfare, Pyrokinetic, Hydrosophist, Aerotheurge, Geomancer, Necromancer, Huntsman, Scoundrel]  (13 stats)
```

*Risks (Example 1, Pool size 11):* **45%** Chance to continue falling / **30%** Chance to continue rising.

| Outcome Classification | Variance | Probability Formula | Final % |
| :--- | :--- | :--- | :--- |
| **Total Ruin** | -6 | $45\% \times 0.45^5$ (Cap) | **0.83%** |
| **Catastrophe** | -5 | $45\% \times 0.45^4 \times 0.55$ (Stop) | **1.01%** |
| **Total Collapse** | -4 | $45\% \times 0.45^3 \times 0.55$ (Stop) | **2.26%** |
| **Collapse** | -3 | $45\% \times 0.45^2 \times 0.55$ (Stop) | **5.01%** |
| **Deep Loss** | -2 | $45\% \times 0.45 \times 0.55$ (Stop) | **11.14%** |
| **Bad Luck** | -1 | $45\% \times 0.55$ (Stop) | **24.75%** |
| **Standard** | 0 | $40\%$ (Flat) | **40.00%** |
| **Win** | +1 | $15\% \times 70\%$ (Stop) | **10.50%** |
| **Jackpot** | +2 | $15\% \times 30\% \times 70\%$ (Stop) | **3.15%** |
| **Divine** | +3 | $15\% \times 30\%^2 \times 70\%$ (Stop) | **0.95%** |
| **GOD MODE** | +4 | $15\% \times 30\%^3 \times 70\%$ (Stop) | **0.28%** |
| **Transcendent** | +5 | $15\% \times 30\%^4$ (Cap) | **0.12%** |

*Risks (Example 2, Pool size 13):* **45%** Chance to continue falling / **30%** Chance to continue rising.

| Outcome Classification | Variance | Probability Formula | Final % |
| :--- | :--- | :--- | :--- |
| **Absolute Ruin** | -7 | $45\% \times 0.45^6$ (Cap) | **0.37%** |
| **Total Ruin** | -6 | $45\% \times 0.45^5 \times 0.55$ (Stop) | **0.46%** |
| **Catastrophe** | -5 | $45\% \times 0.45^4 \times 0.55$ (Stop) | **1.01%** |
| **Total Collapse** | -4 | $45\% \times 0.45^3 \times 0.55$ (Stop) | **2.26%** |
| **Collapse** | -3 | $45\% \times 0.45^2 \times 0.55$ (Stop) | **5.01%** |
| **Deep Loss** | -2 | $45\% \times 0.45 \times 0.55$ (Stop) | **11.14%** |
| **Bad Luck** | -1 | $45\% \times 0.55$ (Stop) | **24.75%** |
| **Standard** | 0 | $40\%$ (Flat) | **40.00%** |
| **Win** | +1 | $15\% \times 70\%$ (Stop) | **10.50%** |
| **Jackpot** | +2 | $15\% \times 30\% \times 70\%$ (Stop) | **3.15%** |
| **Divine** | +3 | $15\% \times 30\%^2 \times 70\%$ (Stop) | **0.95%** |
| **GOD MODE** | +4 | $15\% \times 30\%^3 \times 70\%$ (Stop) | **0.28%** |
| **Transcendent** | +5 | $15\% \times 30\%^4 \times 70\%$ (Stop) | **0.09%** |
| **Absolute** | +6 | $15\% \times 30\%^5$ (Cap) | **0.04%** |

---

## 5. Implementation Plan (Pseudocode)

```python
FUNCTION ExecuteForging(Item_A, Item_B):

    # 1. RARITY FIRST (Sets the Container)
    # This determines the Cap. (e.g., if Divine -> Cap is 8)
    # If the item descended, the Cap will be small.
    Rarity_ID = RaritySystem.Calculate(Item_A, Item_B)
    Stat_Cap = GetCap(Rarity_ID)

    # 2. SORT STATS
    List_G = Intersect(Item_A.Stats, Item_B.Stats)
    List_P = Unique(Item_A.Stats, Item_B.Stats)
    Pool_Size = Length(List_P)

    # 3. DETERMINE TIER & CONSTANTS
    Tier = 1
    IF Pool_Size >= 8: Tier = 4
    ELSE IF Pool_Size >= 5: Tier = 3
    ELSE IF Pool_Size >= 2: Tier = 2

    # [Bad, Std, Good]
    Base_Probs = [0, 50, 50]
    if Tier == 2: Base_Probs = [12, 50, 38]
    if Tier == 3: Base_Probs = [28, 50, 22]
    if Tier == 4: Base_Probs = [45, 40, 15]

    # [Descend_Rate, Ascend_Rate]
    Chain_Rates = [0, 0]
    if Tier == 2: Chain_Rates = [12, 22]
    if Tier == 3: Chain_Rates = [28, 30]
    if Tier == 4: Chain_Rates = [45, 30]

    # 4. DYNAMIC SLOPE ROLL
    Variance = 0
    Roll = Random(0, 100)
    V_avg = (Pool_Size + 1) // 2
    Max_Variance = Pool_Size - V_avg  # Cannot select more than pool size
    Min_Variance = -V_avg  # Cannot select fewer than 0 stats

    # BAD LUCK CHAIN
    IF Roll < Base_Probs[0]:
        Variance = -1
        # Recursive Descension (capped by pool size)
        WHILE (Variance > Min_Variance AND Random(0, 100) < Chain_Rates[0]):
            Variance -= 1

    # STANDARD
    ELSE IF Roll < (Base_Probs[0] + Base_Probs[1]):
        Variance = 0

    # GOOD LUCK CHAIN
    ELSE:
        Variance = 1
        # Recursive Ascension (capped by pool size)
        WHILE (Variance < Max_Variance AND Random(0, 100) < Chain_Rates[1]):
            Variance += 1

    # 5. COMPILE & ENFORCE
    V_avg = (Pool_Size + 1) // 2
    Target_Count = Length(List_G) + V_avg + Variance

    # Ensure Target doesn't drop below Guaranteed count (Safety Net)
    Target_Count = MAX(Target_Count, Length(List_G))

    # Compile List
    Final_Stats = List_G.Copy()
    Stats_Needed = Target_Count - Length(Final_Stats)

    IF Stats_Needed > 0:
        AddRandom(Final_Stats, List_P, Stats_Needed)

    # PURGE (The Cap Check)
    # If the Slope generated 10 stats but Rarity is Rare (4), delete 6.
    IF Length(Final_Stats) > Stat_Cap:
        Resize(Final_Stats, Stat_Cap) # Truncates end of list (Pool stats)

    RETURN Final_Stats