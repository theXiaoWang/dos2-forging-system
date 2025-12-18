# Stat inheritance (how forging keeps and rolls blue stats) (v3.0)

## 1. What this system does


This system aims to deliver a more RPG-like forging experience, one that can be calculated, but with enough RNG to allow for that YOLO.

When you forge two items, this system decides which and how **blue text stats** are inherited by the new forged item.
- If both items share the same stat line, you’re more likely to **keep the overlapping stat** (it’s safer).
- If both items share the same stat **but the numbers differ** (e.g. `+10%` vs `+14%` Critical Chance), it still counts as a **shared stat**, but the forged item will **merge the numbers** into a new  value based on the parents' value.
- If both items are very different, it’s **riskier but can be more rewarding** (there are more possible outcomes).
- Depending on your forging strategy, You could get a **steady, average** result, or a **unpredictable, volatile** result which can get **lucky** or **unlucky** streaks.

In short: 
- **More matching lines = more predictable forging**, and **vice versa** 
- **Closer stats values = merged numbers more consistent**.

*Below is the technical breakdown for players who want the exact maths.*

---
## 2. Forging steps
1. **Rarity first**: run the **[Rarity System](rarity_system.md)** to decide the forged item's rarity and get the item’s **max stat slots**.
2. **Stats second**: work out which stats carry over and what are the numbers (shared + rolled from pool).
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

## 3. Stats Inheritance rules

Two rules define inheritance: the [Merging rule](#31-merging-rule-how-numbers-are-merged) and the [Selection rule](#32-selection-rule-shared--pool--cap).

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
### 3.1. Merging rule (how numbers are merged)

Sometimes both parents have the **same stat**, but the **numbers** are different:
- `+10% Critical Chance` vs `+14% Critical Chance`
- `+3 Strength` vs `+4 Strength`

In this system, those are still treated as **Shared stats (S)** (same stat **key**), but the forged item will roll a **merged value** for that stat.

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

**Example B: `+5` vs `+6` Strength**
- $a=5,\ b=6 \Rightarrow m=5.5$
- $lo = 4.25,\ hi = 6.9$
- Tight roll gives **5–6**.
- Wide roll can reach **4–7**:
  - Low end: $m \times 0.70 = 3.85$ clamps to $4.25$ → rounds to **4**.
  - High end: $m \times 1.30 = 7.15$ clamps to $6.9$ → rounds to **7**.

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
1. Roll a random number to choose the roll type:
   - If it is in the **wide 50%**, use $Tri(0.70, 1.00, 1.30)$
   - Otherwise use the **tight 50%**, $Tri(0.85, 1.00, 1.15)$
2. Suppose you roll **wide**, then roll $r = 1.22$:
   - $value = clamp(12 \times 1.22,\ 8.5,\ 16.1) = 14.64$ → rounds to **15%**
3. Suppose instead you roll **tight**, then roll $r = 0.90$:
   - $value = clamp(12 \times 0.90,\ 8.5,\ 16.1) = 10.8$ → rounds to **11%**

---
### 3.2. Selection rule (shared + pool + cap)

Now that **Shared stats (S)** includes the value-merge behaviour above (same stat key, merged number if needed), the next step:
- Count how many shared stats you have (**S**).
- Put everything else into the pool (**P**).
- Roll how many pool stats you keep (**K**) and apply the rarity cap.

These are the same rules as above, written as formulas:


For the expected baseline:

$$E =
\begin{cases}
0 & \text{if } P = 1 \\
\lceil P / 2 \rceil & \text{otherwise}
\end{cases}
$$

$$K = \min(\max(E + V,\ 0),\ P)\ \text{or}\ K = E + V\ \ (0 \le E + V \le P)$$

$$T = S + K$$

$$Final = \min(T,\ Cap)$$
### Step 1: Separate shared vs pool stats
Compare the two parents:
- For all the **shared stats** from both items (same stat **key**), put into **Shared stats (S)**.
  - If the values differ, use the **value merge** rules in **3.1** to roll the merged number for the forged item.
- For all the **non-shared stats** from both items, put into **Pool stats (P)**.

### Step 2: Set the expected baseline (E)
Now work out your starting point for the pool.
You begin at **about half the pool**, rounded up (this is the “expected baseline”, E).

Examples:
- Pool size 1 → baseline is 0 (then you 50/50 roll to keep it or lose it)
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
   - Total stats = number of shared stats + number of pool stats kept
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
- Suppose your luck adjustment roll comes out as **V = +1**
- Pool stats kept (from the pool): **K = clamp(E + V, 0, P) = clamp(2 + 1, 0, 4) = 3**
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

Inputs for this example:
- **Shared stats (S):** 1
- **Pool size (P):** 1
- **Expected baseline (E):** 0  *(special case for P = 1)*

| Luck adjustment<br>(A) | Stats from pool<br>(K) | Forged item Stats<br>(T) | Chance<br>(math) | Chance |
| :---: | :---: | :---: | :---: | :---: |
| 0 | 0 | 1 | $50\%$ (cap) | **50.00%** |
| +1 | 1 | 2 | $50\%$ (cap) | **50.00%** |

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

Inputs for this example:
- **Shared stats (S):** 2
- **Pool size (P):** 1
- **Expected baseline (E):** 0  *(special case for P = 1)*

| Luck adjustment<br>(A) | Stats from pool<br>(K) | Forged item Stats<br>(T) | Chance<br>(math) | Chance |
| :---: | :---: | :---: | :---: | :---: |
| 0 | 0 | 2 | $50\%$ (cap) | **50.00%** |
| +1 | 1 | 3 | $50\%$ (cap) | **50.00%** |

### Tier 2 (Pool size = 2–4)

**Example 1 (Pool size = 3):**
```
Item A: Traveller’s Dagger
 - +1 Strength
 - +1 Finesse
 - 10% chance to set Bleeding

Item B: Scout’s Dagger
 - +1 Strength
 - +1 Wits
─────────────────────────────────────────
Shared stats:
 - +1 Strength
Pool stats:
 - +1 Finesse
 - 10% chance to set Bleeding
 - +1 Wits
```

Inputs for this example:
- **Shared stats (S):** 1
- **Pool size (P):** 3
- **Expected baseline (E):** ceil(P / 2) = 2

Before the rarity cap, the forged item ends up with between **1** and **4** stats (**1** shared + **0–3** from the pool).

| Luck adjustment<br>(A) | Stats from pool<br>(K) | Forged item Stats<br>(T) | Chance<br>(math) | Chance |
| :---: | :---: | :---: | :---: | :---: |
| -2 | 0 | 1 | $12\% \times 12\%$ (cap) | **1.44%** |
| -1 | 1 | 2 | $12\% \times 88\%$ | **10.56%** |
| 0 | 2 | 3 | $50\%$ | **50.00%** |
| +1 | 3 | 4 | $38\%$ (cap) | **38.00%** |

**Example 2 (Pool size = 4):**
```
Item A: Magister’s Mace
 - +1 Strength
 - +1 Finesse
 - +10% Critical Chance
 - 10% chance to set Blinded

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
 - 10% chance to set Blinded
 - +1 Wits
 - +10% Cleave chance
```

Inputs for this example:
- **Shared stats (S):** 2
- **Pool size (P):** 4
- **Expected baseline (E):** ceil(P / 2) = 2

Before the rarity cap, the forged item ends up with between **2** and **6** stats (**2** shared + **0–4** from the pool).

| Luck adjustment<br>(A) | Stats from pool<br>(K) | Forged item Stats<br>(T) | Chance<br>(math) | Chance |
| :---: | :---: | :---: | :---: | :---: |
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
 - 10% chance to set Bleeding

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
 - 10% chance to set Bleeding
 - +1 Warfare
 - +1 Pyrokinetic
```

Inputs for this example:
- **Shared stats (S):** 2
- **Pool size (P):** 5
- **Expected baseline (E):** ceil(P / 2) = 3

Before the rarity cap, the forged item ends up with between **2** and **7** stats (**2** shared + **0–5** from the pool).

| Luck adjustment<br>(A) | Stats from pool<br>(K) | Forged item Stats<br>(T) | Chance<br>(math) | Chance |
| :---: | :---: | :---: | :---: | :---: |
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
 - 10% chance to set Silenced

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
 - 10% chance to set Silenced
 - +1 Warfare
 - +1 Pyrokinetic
 - +1 Hydrosophist
```

Inputs for this example:
- **Shared stats (S):** 2
- **Pool size (P):** 7
- **Expected baseline (E):** ceil(P / 2) = 4

Before the rarity cap, the forged item ends up with between **2** and **9** stats (**2** shared + **0–7** from the pool).

| Luck adjustment<br>(A) | Stats from pool<br>(K) | Forged item Stats<br>(T) | Chance<br>(math) | Chance |
| :---: | :---: | :---: | :---: | :---: |
| -4 | 0 | 2 | $28\% \times (28\%)^{3}$ (cap) | **0.61%** |
| -3 | 1 | 3 | $28\% \times (28\%)^{2} \times 72\%$ | **1.58%** |
| -2 | 2 | 4 | $28\% \times 28\% \times 72\%$ | **5.64%** |
| -1 | 3 | 5 | $28\% \times 72\%$ | **20.16%** |
| 0 | 4 | 6 | $50\%$ | **50.00%** |
| +1 | 5 | 7 | $22\% \times 70\%$ | **15.40%** |
| +2 | 6 | 8 | $22\% \times 30\% \times 70\%$ | **4.62%** |
| +3 | 7 | 9 | $22\% \times (30\%)^{2}$ (cap) | **1.98%** |

### Tier 4 (Pool size = 8+)

**Example 1 (Pool size = 1):**
```
Item A: Archmage’s Staff
 - +1 Strength
 - +1 Warfare
 - +10% Critical Chance
 - +20% Air Resistance
 - +2 Intelligence
 - +1 Two-Handed
 - +15% Accuracy

Item B: Battlemage’s Staff
 - +1 Strength
 - +1 Warfare
 - +10% Critical Chance
 - +20% Air Resistance
 - +2 Intelligence
 - +1 Two-Handed
 - +15% Accuracy
 - +1 Pyrokinetic
─────────────────────────────────────────
Shared stats:
 - +1 Strength
 - +1 Warfare
 - +10% Critical Chance
 - +20% Air Resistance
 - +2 Intelligence
 - +1 Two-Handed
 - +15% Accuracy
Pool stats:
 - +1 Pyrokinetic
```

Inputs for this example:
- **Shared stats (S):** 7
- **Pool size (P):** 1
- **Expected baseline (E):** 0  *(special case for P = 1)*

Before the rarity cap, the forged item ends up with between **7** and **8** stats (**7** shared + **0–1** from the pool).
  - This is “safer crafting” in practice: more shared stats means fewer “unknown” stats in the pool.

| Luck adjustment<br>(A) | Stats from pool<br>(K) | Forged item Stats<br>(T) | Chance<br>(math) | Chance |
| :---: | :---: | :---: | :---: | :---: |
| 0 | 0 | 7 | $50\%$ (cap) | **50.00%** |
| +1 | 1 | 8 | $50\%$ (cap) | **50.00%** |

**Example 2 (Pool size = 12):**
```
Item A: Champion’s Greatsword
 - +1 Strength
 - +1 Warfare
 - +10% Critical Chance
 - +15% Accuracy
 - +1 Two-Handed
 - +2 Strength
 - +1 Necromancer
 - 10% chance to set Bleeding

Item B: Assassin’s Greatsword
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
 - +15% Accuracy
 - +1 Two-Handed
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
- **Pool size (P):** 12
- **Expected baseline (E):** ceil(P / 2) = 6

Before the rarity cap, the forged item ends up with between **2** and **14** stats (**2** shared + **0–12** from the pool).
  - This is “riskier crafting” in practice: fewer shared stats means more “unknown” stats in the pool.

| Luck adjustment<br>(A) | Stats from pool<br>(K) | Forged item Stats<br>(T) | Chance<br>(math) | Chance |
| :---: | :---: | :---: | :---: | :---: |
| -6 | 0 | 2 | $45\% \times 0.45^{5}$ (cap) | **0.83%** |
| -5 | 1 | 3 | $45\% \times 0.45^{4} \times 0.55$ | **1.01%** |
| -4 | 2 | 4 | $45\% \times 0.45^{3} \times 0.55$ | **2.26%** |
| -3 | 3 | 5 | $45\% \times 0.45^{2} \times 0.55$ | **5.01%** |
| -2 | 4 | 6 | $45\% \times 0.45 \times 0.55$ | **11.14%** |
| -1 | 5 | 7 | $45\% \times 0.55$ | **24.75%** |
| 0 | 6 | 8 | $40\%$ | **40.00%** |
| +1 | 7 | 9 | $15\% \times 70\%$ | **10.50%** |
| +2 | 8 | 10 | $15\% \times 30\% \times 70\%$ | **3.15%** |
| +3 | 9 | 11 | $0.15 \times 0.30^{2} \times 0.70$ | **0.95%** |
| +4 | 10 | 12 | $0.15 \times 0.30^{3} \times 0.70$ | **0.28%** |
| +5 | 11 | 13 | $0.15 \times 0.30^{4} \times 0.70$ | **0.09%** |
| +6 | 12 | 14 | $15\% \times 0.30^{5}$ (cap) | **0.04%** |

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
    # Shared stats are defined by stat KEY (not exact string match).
    # If both parents have the same key but different values, roll a merged value (see section 3.1).
    poolStats = PoolByKey(Item_A.Stats, Item_B.Stats)  # keys that exist on only one parent
    poolCount = Length(poolStats)

    # Value merge volatility is global (see section 3.1), so it does not depend on Tier.
    sharedStats = SharedByKeyWithMergedValues(Item_A.Stats, Item_B.Stats)

    sharedCount = Length(sharedStats)
    # Expected baseline: round_up(poolCount / 2), except poolCount == 1 uses 0 (50/50 keep-or-lose)
    expectedPoolPicks = (poolCount + 1) // 2  # round_up(poolCount / 2)
    IF poolCount == 1:
        expectedPoolPicks = 0

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