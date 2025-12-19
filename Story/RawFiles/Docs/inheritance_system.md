# Inheritance System

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
### 2.0. Ingredient eligibility (hard rule)
Weapons with **socketed runes** must **not** be accepted as forging ingredients.

Reject an ingredient if it has:
- Any **runes inserted** into sockets, and/or
- Any **stats modifiers or granted skills originating from rune sockets**.

Empty rune slots are allowed.

1. **Rarity first**: run the **[Rarity System](rarity_system.md)** to decide the forged item's rarity and get the item’s **max stat slots**.
2. **Stats second**: work out which stats carry over and what are the numbers (shared + rolled from pool).
3. **Cap last**: if the result has more stats than the **max stat slots**, remove extra stats (pool-derived ones first).
4. **Granted skills (separate cap)**: granted skills are inherited using a **separate, vanilla-aligned cap**. See **[Section 5](#5-granted-skill-inheritance)**.

### 2.1. The two stat lists
- **Shared stats (S)**: stats on **both** parents (guaranteed).
- **Pool stats (P)**: stats that are **not shared** (unique to either parent). This is the combined pool from both parents.

### 2.2. The rarity cap (max stat lines for each rarity)
**Example**:  
A "Two-Handed Greatsword" could appear at different rarities.  
- If the sword is **Rare** (Rarity ID 3), it can have up to **5 blue stats** (for example: +12% Critical Chance, +2 Strength, +1 Warfare, 10% chance to set Bleeding, +1 Two-Handed).
- If the same sword is **Epic** (Rarity ID 4), it can have up to **6 blue stats**.  

### 2.3. Rune slots (simple inheritance rule)
Rune slots are inherited separately from blue stats and granted skills.

If both parents have **empty** rune slots (no runes socketed), the forged item’s rune slots are:

Take the average of the two parents’ rune slot counts, then **round up**.

$$RuneSlots_{out} = \lceil (RuneSlots_A + RuneSlots_B) / 2 \rceil$$

Examples:

| Parent A slots | Parent B slots | Forged slots |
| :---: | :---: | :---: |
| 1 | 2 | 2 |
| 2 | 3 | 3 |
| 1 | 3 | 2 |

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

Multiplayer note:
- This luck roll (and the later random selection of which pool stats you actually take) should be rolled **host-authoritatively** and driven by the forge’s deterministic seed (`forgeSeed`), for consistency.

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
- Assume the rarity system gives the new item **Rare** → **Cap = 5**
- Final total: **Final = min(T, Cap) = min(5, 5) = 5**

So you end up with:
- The 2 shared stats (always)
- Plus 3 of the pool stats (no trimming needed in this example)

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

## 4. Implementation reference
- [forging_system_implementation_blueprint_se.md → Appendix: Pseudocode reference](forging_system_implementation_blueprint_se.md#appendix-pseudocode-reference)

---
## 5. Granted skill inheritance
This section adds **granted skills** as a **separate inheritance channel** from normal “blue stats”.

- **Vanilla-aligned caps**: skills are tightly capped by rarity (Epic 1, Legendary 1, Divine 2).
- **Separate from stat slots**: granted skills do **not** consume your normal **Max stat slots (this mod)**.
- **Stable randomness**: selection/trimming is **random but seeded per forge**, so it is stable for that forge.
- **Multiplayer consistency**: use the same `forgeSeed` approach as stats, and roll skills **host-authoritatively** (clients receive the final result).

### 5.1. What counts as a “granted skill”

- **Granted skill (rollable)**: any rollable boost/stat line that grants entries via a `Skills` field in its boost definition.
  - Weapon example: `_Boost_Weapon_Skill_Whirlwind` → `Shout_Whirlwind`
  - Shield example: `_Boost_Shield_Skill_BouncingShield` → `Projectile_BouncingShield`
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

### 5.2. Skill caps (vanilla rules + this mod’s Unique override)

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

### 5.3. The two skill lists (mirrors the stat system)

Split granted skills into two lists:

- **Shared skills (Sₛ)**: granted skills present on **both** parents (kept unless we must trim due to cap overflow).
- **Pool skills (Pₛ)**: granted skills present on **only one** parent (rolled).

#### Skill identity (dedupe key)
Use the **skill ID** as the identity key (e.g. `Shout_Whirlwind`, `Projectile_BouncingShield`), not the boost name.

### 5.4. Selection rule (shared + pool + cap), with seeded RNG

Skills are **more precious than stats**, so the skill channel does **not** use the stat-style “keep half the pool” baseline.

Instead, skills use a **cap + gated fill** model:
- **Shared skills are protected** (kept first).
- You only try to gain skills for **free skill slots** (up to the rarity skill cap).
- The chance to gain a skill **increases with pool size** (`P_remaining`).

#### Key values (skills)
- **Sₛ**: number of shared rollable skills (present on both parents).
- **Pₛ**: number of pool rollable skills (present on only one parent).
- **SkillCap**: from Section 5.2.
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

### 5.5. Applying the cap (including overflow handling)

1. Build `sharedSkills` (deduped) and `poolSkills` (deduped).
2. Keep shared first:
   - `finalSkills = sharedSkills` (trim down to `SkillCap` only if shared exceeds cap; use seeded trimming).
3. Compute `freeSlots = SkillCap - len(finalSkills)`.
4. Fill free slots with gated gain rolls (seeded):
   - For each free slot (at most `freeSlots` attempts):
     - Let `P_remaining = len(poolSkills)`
     - Roll a seeded random number; success chance is `p_attempt = base(rarity) * m(P_remaining)` (Section 5.4).
     - If success: pick 1 random skill from `poolSkills` (seeded), add to `finalSkills`, remove it from `poolSkills`, and decrement `freeSlots`.
     - If failure: do nothing for that slot (skills are precious; you do not retry the same slot).
5. Optional “replace” roll (seeded): **5% chance**
   - If `poolSkills` is not empty and `finalSkills` is not empty:
     - With 5% chance, replace 1 random skill in `finalSkills` with 1 random skill from remaining `poolSkills` (both seeded).

### 5.6. Scenario tables (common cases)

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

### 5.7. Worked example (Divine output)

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

### 5.8. Implementation reference
- [forging_system_implementation_blueprint_se.md → Appendix: Pseudocode reference](forging_system_implementation_blueprint_se.md#appendix-pseudocode-reference)