# Stat inheritance (how forging keeps and rolls blue stats) (v3.0)

## 1. What this system does


This system aims to deliver a more RPG-like forging experience—one that can be calculated, but with enough RNG to allow for that thrilling “lottery win” feeling.

When you forge two items, this system decides which **blue text stats** are inherited by the new item.
- If both items share the same stat line, it’s **safer** (you’re more likely to keep what you wanted).
- If both items are very different, it’s **riskier** (there are more possible outcomes).
- You’ll usually get a **steady, average** result, but you can still get **lucky** or **unlucky** streaks.

In short: **more matching lines = more predictable forging**, and **vice versa**.

*Below is the technical breakdown (symbols + formulas) for players who want the exact maths.*

---
## 2. Forging steps
1. **Rarity first**: run the **[Rarity System](rarity_system.md)** to get the item’s **max stat slots**.
2. **Stats second**: work out which stats carry over (shared + rolled from pool).
3. **Cap last**: if the result has more stats than the **max stat slots**, remove extra stats (pool-derived ones first).

### 2.1. The two stat lists
- **Shared stats (S)**: stats on **both** parents (guaranteed).
- **Pool stats (P)**: stats that are **not shared** (unique to either parent). This is the combined pool from both parents.

### 2.2. The rarity cap (max stat lines for each rarity)
**Example**:  
A "Two-Handed Greatsword" could appear at different rarities.  
- If the sword is **Rare** (Rarity ID 3), it can have up to **4 blue stats** (for example: +12% Critical Chance, +2 Strength, +1 Warfare, 10% chance to set Bleeding).
- If the same sword is **Epic** (Rarity ID 4), it can have up to **6 blue stats**.  

Defined by the **[Rarity System](rarity_system.md)**:

| Rarity ID | Name | Max stat slots |
| :--- | :--- | :--- |
| **1** | Common | **1** |
| **2** | Uncommon | **2** |
| **3** | Rare | **4** |
| **4** | Epic | **6** |
| **5** | Legendary | **7** |
| **6** | Divine | **8** |
| **8** | Unique | **10** |

---

## 3. Inheritance rules (stats)

#### Key values

- **S (Shared stats)**: stat lines both parents share (always carried over).
- **P (Pool stats)**: stat lines not shared (all unique lines from both parents combined).
- **E (Expected baseline)**: your starting pool pick count: $E = \lceil P / 2 \rceil$ (half the pool, rounded up).
- **A (Luck adjustment)**: the luck result that nudges E up/down (can chain).
- **K (Stats from pool)**: how many you actually take from the pool (after luck adjustment, limited to 0–P).
- **T (Planned total)**: planned stat lines before the rarity cap.
- **Cap**: the max stat slots from rarity.
- **Final**: stat lines after the cap is applied.

### Formula

These are the same rules as above, written as formulas:

$$E = \lceil P / 2 \rceil$$

$$K = \min(\max(E + A,\ 0),\ P)\ \text{or}\ K = E + A\ \ (0 \le E + A \le P)$$

$$T = S + K$$

$$Final = \min(T,\ Cap)$$
### Step 1: Separate shared vs pool stats
Compare the two parents:
- For all the **shared stats** from both items, put into **Shared stats (S)**.
- For all the **non-shared stats** from both items, put into **Pool stats (P)**.

### Step 2: Set the expected baseline (E)
Now work out your starting point for the pool.
You begin at **about half the pool**, rounded up (this is the “expected baseline”, E).

Examples:
- Pool size 1 → expect to keep 1
- Pool size 4 → expect to keep 2
- Pool size 7 → expect to keep 4

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

### Step 5: Build the result and apply the cap
1. **Plan total stats**:
   - Total stats = (number of shared stats) + (number of pool stats kept)
2. **Build the list**:
   - Start with all **shared stats**, then add that many random stats from the **pool**.
3. **Apply the cap last**:
   - If the total is above the item’s **max stat slots**, remove extra stats until you reach the limit (remove pool-picked stats first).

Imagine you’re forging these two weapons:

```
Parent A: Steel Longsword
 - +1 Warfare
 - +10% Critical Chance
 - +2 Strength
 - +1 Two-Handed

Parent B: Knight’s Greatsword
 - +1 Warfare
 - +10% Critical Chance
 - +1 Necromancer
 - +12% Fire Resistance
```

Split into lists:
- Shared stats (on both): `+1 Warfare`, `+10% Critical Chance` → **S = 2**
- Pool stats (not shared): `+2 Strength`, `+1 Two-Handed`, `+1 Necromancer`, `+12% Fire Resistance` → **P = 4**

Now calculate how many pool stats you keep:
- Expected baseline: **E = ceil(P / 2) = ceil(4 / 2) = 2**
- Suppose your luck adjustment roll comes out as **A = +1**
- Pool stats kept (from the pool): **K = clamp(E + A, 0, P) = clamp(2 + 1, 0, 4) = 3**
- Planned total before cap: **T = S + K = 2 + 3 = 5**

Finally apply the rarity cap:
- Assume the rarity system gives the new item **Rare** → **Cap = 4**
- Final total: **Final = min(T, Cap) = min(5, 4) = 4**

So you end up with:
- The 2 shared stats (always)
- Plus 2 of the pool stats (because 1 gets trimmed by the cap)

---

### Examples

The tables below are examples only. They apply the formulas above to show what you can roll in each pool-size tier.

### Tier 1 (Pool size = 1, no chains)

**Example 1:**
```
Item A: Rusty Longsword
 - +1 Strength
 - +5% Accuracy

Item B: Old Longsword
 - +1 Strength
─────────────────────────────────────────
Shared stats:
 - +1 Strength
Pool stats:
 - +5% Accuracy
```

Worked numbers:
- Shared stats: 1
- Pool size: 1
- Expected baseline (half, rounded up): 1

| Luck adjustment | Stats from pool | Forged item Stats | Chance (math) | Chance |
| :---: | :---: | :---: | :--- | :---: |
| 0 | 1 | 2 | $50\% + 50\%$ (good roll is capped) | **100.00%** |

**Example 2 (same pool size, same tier):**
```
Item A: Soldier’s Axe
 - +1 Strength
 - +1 Warfare
 - +10% Critical Chance

Item B: Soldier’s Sword
 - +1 Strength
 - +1 Warfare
─────────────────────────────────────────
Shared stats:
 - +1 Strength
 - +1 Warfare
Pool stats:
 - +10% Critical Chance
```

Worked numbers:
- Shared stats: 2
- Pool size: 1
- Expected baseline: 1

### Tier 2 (Pool size = 2–4)

**Example 1 (Pool size = 3):**
```
Item A: Traveller’s Dagger
 - +1 Strength
 - +1 Finesse
 - 10% chance to inflict Bleeding

Item B: Scout’s Dagger
 - +1 Strength
 - +1 Wits
─────────────────────────────────────────
Shared stats:
 - +1 Strength
Pool stats:
 - +1 Finesse
 - 10% chance to inflict Bleeding
 - +1 Wits
```

Worked numbers:
- Shared stats: 1
- Pool size: 3
- Expected baseline (half, rounded up): 2
- Before the rarity cap, the forged item ends up with between **1** and **4** stats (**1** shared + **0–3** from the pool).

| Luck adjustment | Stats from pool | Forged item Stats | Chance (math) | Chance |
| :---: | :---: | :---: | :--- | :---: |
| -2 | 0 | 1 | $12\% \times 12\%$ (cap) | **1.44%** |
| -1 | 1 | 2 | $12\% \times 88\%$ | **10.56%** |
| 0 | 2 | 3 | $50\%$ | **50.00%** |
| +1 | 3 | 4 | $38\%$ (capped at +1) | **38.00%** |

**Example 2 (Pool size = 4):**
```
Item A: Magister’s Mace
 - +1 Strength
 - +1 Finesse
 - +10% Critical Chance
 - 10% chance to inflict Blinded

Item B: Scholar’s Mace
 - +1 Strength
 - +1 Finesse
 - +1 Wits
 - +10% Cleave chance
─────────────────────────────────────────
Shared stats:
 - +1 Strength
 - +1 Finesse
Pool stats:
 - +10% Critical Chance
 - 10% chance to inflict Blinded
 - +1 Wits
 - +10% Cleave chance
```

Worked numbers:
- Shared stats: 2
- Pool size: 4
- Expected baseline (half, rounded up): 2
- Before the rarity cap, the forged item ends up with between **2** and **6** stats (**2** shared + **0–4** from the pool).

| Luck adjustment | Stats from pool | Forged item Stats | Chance (math) | Chance |
| :---: | :---: | :---: | :--- | :---: |
| -2 | 0 | 2 | $12\% \times 12\%$ (cap) | **1.44%** |
| -1 | 1 | 3 | $12\% \times 88\%$ | **10.56%** |
| 0 | 2 | 4 | $50\%$ | **50.00%** |
| +1 | 3 | 5 | $38\% \times 78\%$ | **29.64%** |
| +2 | 4 | 6 | $38\% \times 22\%$ (cap) | **8.36%** |

### Tier 3 (Pool size = 5–7)

**Example 1 (Pool size = 5):**
```
Item A: Veteran’s Spear
 - +1 Strength
 - +1 Finesse
 - +1 Constitution
 - +10% Critical Chance
 - 10% chance to inflict Bleeding

Item B: Battle Spear
 - +1 Strength
 - +1 Finesse
 - +1 Warfare
 - +1 Pyrokinetic
─────────────────────────────────────────
Shared stats:
 - +1 Strength
 - +1 Finesse
Pool stats:
 - +1 Constitution
 - +10% Critical Chance
 - 10% chance to inflict Bleeding
 - +1 Warfare
 - +1 Pyrokinetic
```

Worked numbers:
- Shared stats: 2
- Pool size: 5
- Expected baseline (half, rounded up): 3
- Before the rarity cap, the forged item ends up with between **2** and **7** stats (**2** shared + **0–5** from the pool).

| Luck adjustment | Stats from pool | Forged item Stats | Chance (math) | Chance |
| :---: | :---: | :---: | :--- | :---: |
| -3 | 0 | 2 | $28\% \times (28\%)^{2}$ (cap) | **2.20%** |
| -2 | 1 | 3 | $28\% \times 28\% \times 72\%$ | **5.64%** |
| -1 | 2 | 4 | $28\% \times 72\%$ | **20.16%** |
| 0 | 3 | 5 | $50\%$ | **50.00%** |
| +1 | 4 | 6 | $22\% \times 70\%$ | **15.40%** |
| +2 | 5 | 7 | $22\% \times 30\%$ (cap) | **6.60%** |

**Example 2 (Pool size = 7):**
```
Item A: Enchanted Halberd
 - +1 Strength
 - +1 Finesse
 - +1 Constitution
 - +2 Initiative
 - +10% Critical Chance
 - 10% chance to inflict Silenced

Item B: Elemental Halberd
 - +1 Strength
 - +1 Finesse
 - +1 Warfare
 - +1 Pyrokinetic
 - +1 Hydrosophist
─────────────────────────────────────────
Shared stats:
 - +1 Strength
 - +1 Finesse
Pool stats:
 - +1 Constitution
 - +2 Initiative
 - +10% Critical Chance
 - 10% chance to inflict Silenced
 - +1 Warfare
 - +1 Pyrokinetic
 - +1 Hydrosophist
```

Worked numbers:
- Shared stats: 2
- Pool size: 7
- Expected baseline (half, rounded up): 4
- Before the rarity cap, the forged item ends up with between **2** and **9** stats (**2** shared + **0–7** from the pool).

| Luck adjustment | Stats from pool | Forged item Stats | Chance (math) | Chance |
| :---: | :---: | :---: | :--- | :---: |
| -4 | 0 | 2 | $28\% \times (28\%)^{3}$ (cap) | **0.61%** |
| -3 | 1 | 3 | $28\% \times (28\%)^{2} \times 72\%$ | **1.58%** |
| -2 | 2 | 4 | $28\% \times 28\% \times 72\%$ | **5.64%** |
| -1 | 3 | 5 | $28\% \times 72\%$ | **20.16%** |
| 0 | 4 | 6 | $50\%$ | **50.00%** |
| +1 | 5 | 7 | $22\% \times 70\%$ | **15.40%** |
| +2 | 6 | 8 | $22\% \times 30\% \times 70\%$ | **4.62%** |
| +3 | 7 | 9 | $22\% \times (30\%)^{2}$ (cap) | **1.98%** |

### Tier 4 (Pool size = 8+)

**Example 1 (Pool size = 11):**
```
Item A: Archmage’s Staff
 - +1 Strength
 - +1 Warfare
 - +10% Critical Chance
 - +2 Intelligence
 - +1 Two-Handed
 - +15% Accuracy
 - 10% chance to inflict Blinded
 - +20% Air Resistance

Item B: Battlemage’s Staff
 - +1 Strength
 - +1 Warfare
 - +10% Critical Chance
 - +1 Pyrokinetic
 - +1 Hydrosophist
 - +1 Aerotheurge
 - +1 Geomancer
 - 10% chance to inflict Bleeding
 - 10% chance to inflict Silenced
─────────────────────────────────────────
Shared stats:
 - +1 Strength
 - +1 Warfare
 - +10% Critical Chance
Pool stats:
 - +2 Intelligence
 - +1 Two-Handed
 - +15% Accuracy
 - 10% chance to inflict Blinded
 - +20% Air Resistance
 - +1 Pyrokinetic
 - +1 Hydrosophist
 - +1 Aerotheurge
 - +1 Geomancer
 - 10% chance to inflict Bleeding
 - 10% chance to inflict Silenced
```

Worked numbers:
- Shared stats: 3
- Pool size: 11
- Expected baseline (half, rounded up): 6
- Before the rarity cap, the forged item ends up with between **3** and **14** stats (**3** shared + **0–11** from the pool).
  - This is “safer crafting” in practice: more shared stats means fewer “unknown” stats in the pool.

| Luck adjustment | Stats from pool | Forged item Stats | Chance (math) | Chance |
| :---: | :---: | :---: | :--- | :---: |
| -6 | 0 | 3 | $45\% \times 0.45^{5}$ (cap) | **0.83%** |
| -5 | 1 | 4 | $45\% \times 0.45^{4} \times 0.55$ | **1.01%** |
| -4 | 2 | 5 | $45\% \times 0.45^{3} \times 0.55$ | **2.26%** |
| -3 | 3 | 6 | $45\% \times 0.45^{2} \times 0.55$ | **5.01%** |
| -2 | 4 | 7 | $45\% \times 0.45 \times 0.55$ | **11.14%** |
| -1 | 5 | 8 | $45\% \times 0.55$ | **24.75%** |
| 0 | 6 | 9 | $40\%$ | **40.00%** |
| +1 | 7 | 10 | $15\% \times 70\%$ | **10.50%** |
| +2 | 8 | 11 | $15\% \times 30\% \times 70\%$ | **3.15%** |
| +3 | 9 | 12 | $0.15 \times 0.30^{2} \times 0.70$ | **0.95%** |
| +4 | 10 | 13 | $0.15 \times 0.30^{3} \times 0.70$ | **0.28%** |
| +5 | 11 | 14 | $0.15 \times 0.30^{4}$ (cap) | **0.12%** |

**Example 2 (Pool size = 13):**
```
Item A: Champion’s Greatsword
 - +1 Strength
 - +1 Warfare
 - +10% Critical Chance
 - +15% Accuracy
 - +1 Two-Handed
 - +2 Strength
 - +1 Necromancer
 - 10% chance to inflict Crippled
 - 10% chance to inflict Bleeding

Item B: Assassin’s Greatsword
 - +1 Strength
 - +1 Warfare
 - +10% Critical Chance
 - +15% Accuracy
 - +1 Pyrokinetic
 - +1 Aerotheurge
 - +1 Huntsman
 - +12% Fire Resistance
 - 10% chance to inflict Blinded
 - 10% chance to inflict Silenced
─────────────────────────────────────────
Shared stats:
 - +1 Strength
 - +1 Warfare
 - +10% Critical Chance
 - +15% Accuracy
Pool stats:
 - +1 Two-Handed
 - +2 Strength
 - +1 Necromancer
 - 10% chance to inflict Crippled
 - 10% chance to inflict Bleeding
 - +1 Pyrokinetic
 - +1 Aerotheurge
 - +1 Huntsman
 - +12% Fire Resistance
 - 10% chance to inflict Blinded
 - 10% chance to inflict Silenced
 - +1 Scoundrel
 - +12% Air Resistance
```

Worked numbers:
- Shared stats: 4
- Pool size: 13
- Expected baseline (half, rounded up): 7
- Before the rarity cap, the forged item ends up with between **4** and **17** stats (**4** shared + **0–13** from the pool).
  - This is “safer crafting” in practice: more shared stats means fewer “unknown” stats in the pool.

| Luck adjustment | Stats from pool | Forged item Stats | Chance (math) | Chance |
| :---: | :---: | :---: | :--- | :---: |
| -7 | 0 | 4 | $45\% \times 0.45^{6}$ (cap) | **0.37%** |
| -6 | 1 | 5 | $45\% \times 0.45^{5} \times 0.55$ | **0.46%** |
| -5 | 2 | 6 | $45\% \times 0.45^{4} \times 0.55$ | **1.01%** |
| -4 | 3 | 7 | $45\% \times 0.45^{3} \times 0.55$ | **2.26%** |
| -3 | 4 | 8 | $45\% \times 0.45^{2} \times 0.55$ | **5.01%** |
| -2 | 5 | 9 | $45\% \times 0.45 \times 0.55$ | **11.14%** |
| -1 | 6 | 10 | $45\% \times 0.55$ | **24.75%** |
| 0 | 7 | 11 | $40\%$ | **40.00%** |
| +1 | 8 | 12 | $15\% \times 70\%$ | **10.50%** |
| +2 | 9 | 13 | $15\% \times 30\% \times 70\%$ | **3.15%** |
| +3 | 10 | 14 | $0.15 \times 0.30^{2} \times 0.70$ | **0.95%** |
| +4 | 11 | 15 | $0.15 \times 0.30^{3} \times 0.70$ | **0.28%** |
| +5 | 12 | 16 | $0.15 \times 0.30^{4} \times 0.70$ | **0.09%** |
| +6 | 13 | 17 | $0.15 \times 0.30^{5}$ (cap) | **0.04%** |

---

## 4. Implementation details

### 4.1. Name mapping (doc terms → pseudocode variables)

| Doc term | Pseudocode name | Meaning |
| :--- | :--- | :--- |
| Shared stats | `sharedStats` | Stats present on both parents |
| Pool stats | `poolStats` | Stats that are not shared (unique to either parent) |
| Pool size | `poolCount` | How many stats are in the pool |
| Shared count | `sharedCount` | How many shared stats you have |
| Expected baseline | `expectedPoolPicks` | Half the pool, rounded up |
| Luck adjustment | `luckShift` | Luck adding/removing pool picks (can chain) |
| Max stat slots | `maxAllowed` | Max stat slots allowed by rarity |

### 4.2. Pseudocode

```python
FUNCTION ExecuteForging(Item_A, Item_B):

    # Name mapping used in this pseudocode:
    # - SharedStats: stats on both parents (guaranteed)
    # - PoolStats:   stats that are not shared between parents (unique to either parent)
    # - ExpectedPoolPicks: round_up(PoolCount / 2)
    # - LuckShift: adjustment to the pool picks (can chain, but is capped)
    # - PlannedTotalRaw: SharedCount + ExpectedPoolPicks + LuckShift
    # - PoolPicks: clamp(ExpectedPoolPicks + LuckShift, 0, PoolCount)
    # - PlannedTotal: SharedCount + PoolPicks (before rarity cap)
    # - MaxAllowed: max stat slots allowed by the rarity system

    # 1. RARITY FIRST (sets MaxAllowed)
    rarityId = RaritySystem.Calculate(Item_A, Item_B)
    maxAllowed = GetCap(rarityId)

    # 2. SPLIT STATS
    sharedStats = Intersect(Item_A.Stats, Item_B.Stats)
    poolStats = Unique(Item_A.Stats, Item_B.Stats)
    poolCount = Length(poolStats)

    sharedCount = Length(sharedStats)
    expectedPoolPicks = (poolCount + 1) // 2  # round_up(poolCount / 2)

    # LuckShift caps (so you never try to pick fewer than 0 or more than poolCount)
    minLuckShift = -expectedPoolPicks
    maxLuckShift = poolCount - expectedPoolPicks

    # 3. DETERMINE TIER & CONSTANTS
    tier = 1
    IF poolCount >= 8: tier = 4
    ELSE IF poolCount >= 5: tier = 3
    ELSE IF poolCount >= 2: tier = 2

    # [Bad, Neutral, Good] in percentages
    firstRollChances = [0, 50, 50]
    IF tier == 2: firstRollChances = [12, 50, 38]
    IF tier == 3: firstRollChances = [28, 50, 22]
    IF tier == 4: firstRollChances = [45, 40, 15]

    # [DownChainChance, UpChainChance] in percentages
    chainChances = [0, 0]
    IF tier == 2: chainChances = [12, 22]
    IF tier == 3: chainChances = [28, 30]
    IF tier == 4: chainChances = [45, 30]

    # 4. ROLL LuckShift (the chain)
    luckShift = 0
    roll = Random(0, 100)

    # BAD (down chain)
    IF roll < firstRollChances[0]:
        luckShift = -1
        WHILE (luckShift > minLuckShift AND Random(0, 100) < chainChances[0]):
            luckShift -= 1

    # NEUTRAL
    ELSE IF roll < (firstRollChances[0] + firstRollChances[1]):
        luckShift = 0

    # GOOD (up chain)
    ELSE:
        luckShift = 1
        # If the pool is too small, good luck cannot increase picks beyond maxLuckShift.
        IF luckShift > maxLuckShift:
            luckShift = maxLuckShift

        WHILE (luckShift < maxLuckShift AND Random(0, 100) < chainChances[1]):
            luckShift += 1

    poolPicks = Clamp(expectedPoolPicks + luckShift, 0, poolCount)

    # 5. BUILD FINAL STATS
    finalStats = sharedStats.Copy()
    IF poolPicks > 0:
        AddRandom(finalStats, poolStats, poolPicks)

    # 6. APPLY RARITY CAP LAST (remove pool-picked stats first)
    IF Length(finalStats) > maxAllowed:
        Resize(finalStats, maxAllowed)

    RETURN finalStats
```