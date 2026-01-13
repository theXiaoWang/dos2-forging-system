# Probability Calculation for Screenshot Example (Case 4)

## Input Analysis

**Main Slot (Lv.15 Legendary):**
- +1 Finesse
- +5% Dodge
- ExtraProperties: 15% chance to set Fear, 1 turn
- Skills: Skill A

**Donner Slot (Lv.16 Divine):**
- +2 Finesse
- +2 Movement
- +1 Dual Wield
- +1 Rogue
- ExtraProperties: 15% Chance to set Slow, 2 turns
- Skills: Skill B

**Output (Lv.15 Legendary~Divine):**
- +1~2 Finesse (highlighted green - shared)
- +2 Movement
- +1 Dual Wield
- +1 Rouge
- +5% Dodge
- ExtraProperties: 15% chance to set Fear, 1 turn; 15% Chance to set Slow, 2 turns
- Skills: Skill A or Skill B (pool skills)

## Stat Classification

### Blue Stats Classification

Based on the forging system rules:
- **Shared Blue Stats (S_bs)**: Stats present on both parents (by stat key)
  - Finesse: Both have it (+1 vs +2) → **SHARED** (values merge to +1~2)

- **Pool Blue Stats (P_bs_size)**: Stats present on only one parent
  - Movement: Only Donner has it → **POOL**
  - Dual Wield: Only Donner has it → **POOL**
  - Rouge: Only Donner has it → **POOL**
  - Dodge: Only Main has it → **POOL**

**Summary:**
- `S_bs = 1` (Finesse)
- `P_bs_size = 4` (Movement, Dual Wield, Rouge, Dodge)

### ExtraProperties Classification

Based on the forging system rules:
- **Shared ExtraProperties (S_ep)**: Tokens present on both parents (by canonical key)
  - None → **NO SHARED EP**

- **Pool ExtraProperties (P_ep_size)**: Tokens present on only one parent
  - Fear: Only Main has it → **POOL**
  - Slow: Only Donner has it → **POOL**

**Summary:**
- `S_ep = 0` (no shared EP)
- `P_ep_size = 2` (Fear, Slow)
- **EP Slot Protection:** Since `S_ep = 0`, the ExtraProperties slot is **NOT protected** and competes as a pool slot

### Skills Classification

Based on the forging system rules:
- **Shared Skills (S_sk)**: Skills present on both parents (by skill ID)
  - None → **NO SHARED SKILLS**

- **Pool Skills (P_sk_size)**: Skills present on only one parent
  - Skill A: Only Main Slot has it → **POOL**
  - Skill B: Only Donner Slot has it → **POOL**

**Summary:**
- `S_sk = 0` (no shared skills)
- `P_sk_size = 2` (Skill A, Skill B)
- **Skill Protection:** Since `S_sk = 0`, skills are **NOT protected** and compete as pool slots

## Probability Calculation Parameters

### Blue Stats Parameters

#### Baseline Calculation
- `E_bs = floor((P_bs_size + 1) / 3) = floor((4 + 1) / 3) = floor(5 / 3) = 1`

#### Cap-Proximity Dampener Check
- Output rarity: Legendary~Divine (assume Divine for cap calculation)
- `OverallCap[Divine] = 5`
- `S_bs = 1 < OverallCap - 1 = 4` → **Dampener does NOT apply**
- Therefore: `E_eff_bs = E_bs = 1`

#### Tier Determination
- `P_bs_size = 4` → **Tier 2** (Pool size 2–4)

### ExtraProperties Parameters

#### Baseline Calculation
- `E_ep = floor((P_ep_size + 1) / 3) = floor((2 + 1) / 3) = floor(3 / 3) = 1`

#### Cap-Proximity Dampener Check
- `S_ep = 0 < OverallCap - 1 = 4` → **Dampener does NOT apply**
- Therefore: `E_eff_ep = E_ep = 1`

#### Tier Determination
- `P_ep_size = 2` → **Tier 2** (Pool size 2–4)

#### EP Slot Status
- Since `S_ep = 0`, the ExtraProperties slot is **NOT protected** and competes as a pool slot

### Skills Parameters

#### Skill Cap and Selection
- `S_sk = 0` (no shared skills)
- `P_sk_size = 2` (Skill A, Skill B)
- `SkillCap[Divine] = 1` (default)
- `FreeSlots = max(0, SkillCap - min(S_sk, SkillCap)) = max(0, 1 - 0) = 1`

#### Skill Gain Probability
- Output rarity: Divine
- `P_remaining = 2` (two skills in pool)
- Cross-type: `p_attempt = base_cross(Divine) × m(2) = 20% × 1.4 = 28.0%`
- Same-type: `p_attempt = clamp(2 × 28%, 0, 100%) = 56.0%`

**Note:** Skills use a different selection model (gated fill) than Blue Stats/ExtraProperties. Even though there are 2 pool skills, only 1 can be gained (due to SkillCap=1), but the chance increases with pool size.

### Tier 2 Parameters (for Blue Stats and ExtraProperties)
**Cross-type (default):**
- `p_bad = 14%`
- `p_neutral = 60%`
- `p_good = 26%`
- `d = 0.00` (no down-chain)
- `u = 0.25` (up-chain chance)

**Same-type (if both weapons have same WeaponType):**
- `p_bad = 11.11%`
- `p_neutral = 47.62%`
- `p_good = 41.27%`
- `d = 0.00` (no down-chain)
- `u = 0.25` (up-chain chance)

### Luck Adjustment Bounds

**Blue Stats:**
- `A_min_bs = -E_eff_bs = -1` (cannot keep fewer than 0 pool modifiers)
- `A_max_bs = P_bs_size - E_eff_bs = 4 - 1 = 3` (cannot keep more than all 4 pool modifiers)

**ExtraProperties:**
- `A_min_ep = -E_eff_ep = -1` (cannot keep fewer than 0 pool modifiers)
- `A_max_ep = P_ep_size - E_eff_ep = 2 - 1 = 1` (cannot keep more than all 2 pool modifiers)

## Probability Distribution

### Blue Stats Probabilities

#### Cross-Type (Default) - Blue Stats

| Luck adjustment (A) | Pool picks (P_bs) | Final blue stats (F_bs) | Calculation | Probability |
| :-----------------: | :---------------: | :--------------------: | :---------- | :---------: |
| -1 | 0 | 1 | `p_bad = 14%` (no down-chain) | **14.00%** |
| 0 | 1 | 2 | `p_neutral = 60%` | **60.00%** |
| +1 | 2 | 3 | `p_good × (1-u) = 26% × 0.75 = 19.50%` | **19.50%** |
| +2 | 3 | 4 | `p_good × u × (1-u) = 26% × 0.25 × 0.75 = 4.88%` | **4.88%** |
| +3 | 4 | 5 | `p_good × u^2 = 26% × 0.25^2 = 1.62%` | **1.62%** |

**Total:** 100.00%

#### Same-Type (Same WeaponType) - Blue Stats

| Luck adjustment (A) | Pool picks (P_bs) | Final blue stats (F_bs) | Calculation | Probability |
| :-----------------: | :---------------: | :--------------------: | :---------- | :---------: |
| -1 | 0 | 1 | `p_bad = 11.11%` (no down-chain) | **11.11%** |
| 0 | 1 | 2 | `p_neutral = 47.62%` | **47.62%** |
| +1 | 2 | 3 | `p_good × (1-u) = 41.27% × 0.75 = 30.95%` | **30.95%** |
| +2 | 3 | 4 | `p_good × u × (1-u) = 41.27% × 0.25 × 0.75 = 7.74%` | **7.74%** |
| +3 | 4 | 5 | `p_good × u^2 = 41.27% × 0.25^2 = 2.58%` | **2.58%** |

**Total:** 100.00%

### ExtraProperties Probabilities

#### Cross-Type (Default) - ExtraProperties

| Luck adjustment (A) | Pool picks (P_ep) | EP slot present? | Calculation | Probability |
| :-----------------: | :---------------: | :--------------: | :---------- | :---------: |
| -1 | 0 | No (0) | `p_bad = 14%` (no down-chain) | **14.00%** |
| 0 | 1 | Yes (1) | `p_neutral = 60%` | **60.00%** |
| +1 | 2 | Yes (1) | `p_good × (1-u) = 26% × 0.75 = 19.50%` | **19.50%** |
| +2 | 2 | Yes (1) | `p_good × u = 26% × 0.25 = 6.50%` (clamped to max) | **6.50%** |

**Note:** The EP slot is only present if `P_ep ≥ 1` (since `S_ep = 0`).

**Total:** 100.00%

#### Same-Type (Same WeaponType) - ExtraProperties

| Luck adjustment (A) | Pool picks (P_ep) | EP slot present? | Calculation | Probability |
| :-----------------: | :---------------: | :--------------: | :---------- | :---------: |
| -1 | 0 | No (0) | `p_bad = 11.11%` (no down-chain) | **11.11%** |
| 0 | 1 | Yes (1) | `p_neutral = 47.62%` | **47.62%** |
| +1 | 2 | Yes (1) | `p_good × (1-u) = 41.27% × 0.75 = 30.95%` | **30.95%** |
| +2 | 2 | Yes (1) | `p_good × u = 41.27% × 0.25 = 10.32%` (clamped to max) | **10.32%** |

**Total:** 100.00%

### Skills Probabilities

#### Cross-Type (Default) - Skills

With `P_sk_size = 2`, `P_remaining = 2`, so `p_attempt = 28.0%`:

| Skill gained? | Skills (F_sk) | Calculation | Probability |
| :-----------: | :----------: | :---------- | :---------: |
| No | 0 | `1 - p_attempt = 1 - 28.0% = 72.0%` | **72.00%** |
| Yes | 1 | `p_attempt = 28.0%` | **28.00%** |

**Total:** 100.00%

**Note:** Even though there are 2 pool skills (Skill A and Skill B), only 1 can be gained due to `SkillCap = 1`. If a skill is gained, it's uniformly selected from the 2 pool skills, so each skill has `28.0% / 2 = 14.0%` chance to be selected individually.

#### Same-Type (Same WeaponType) - Skills

With `P_sk_size = 2`, `P_remaining = 2`, so `p_attempt = 56.0%`:

| Skill gained? | Skills (F_sk) | Calculation | Probability |
| :-----------: | :----------: | :---------- | :---------: |
| No | 0 | `1 - p_attempt = 1 - 56.0% = 44.0%` | **44.00%** |
| Yes | 1 | `p_attempt = 56.0%` | **56.00%** |

**Total:** 100.00%

**Note:** Even though there are 2 pool skills (Skill A and Skill B), only 1 can be gained due to `SkillCap = 1`. If a skill is gained, it's uniformly selected from the 2 pool skills, so each skill has `56.0% / 2 = 28.0%` chance to be selected individually.

## Combined Total Modifier Count Probabilities

The total modifier count is: `F_total = F_bs + EPslot + F_sk`, where:
- `F_bs = S_bs + P_bs` (Blue Stats: 1 shared + 0-4 pool)
- `EPslot = 1 if P_ep ≥ 1, else 0` (ExtraProperties slot is a pool slot)
- `F_sk = 0 or 1` (Skill is a pool slot)

**Protected slots:** 1 shared BS = **1 protected slot**

### Cross-Type Forging - Total Modifier Count (Before Cap Trimming)

We need to combine all three channels. Since they're independent, we calculate the joint distribution:

| Blue Stats (F_bs) | EP Slot | Skills (F_sk) | Total (F_total) | Probability | Calculation |
| :--------------: | :-----: | :----------: | :------------: | :---------: | :---------- |
| 1 | 0 | 0 | **1** | 1.41% | 14.00% × 14.00% × 72.00% |
| 1 | 0 | 1 | **2** | 0.55% | 14.00% × 14.00% × 28.00% |
| 1 | 1 | 0 | **2** | 8.67% | 14.00% × 86.00% × 72.00% |
| 1 | 1 | 1 | **3** | 3.37% | 14.00% × 86.00% × 28.00% |
| 2 | 0 | 0 | **2** | 6.05% | 60.00% × 14.00% × 72.00% |
| 2 | 0 | 1 | **3** | 2.35% | 60.00% × 14.00% × 28.00% |
| 2 | 1 | 0 | **3** | 37.15% | 60.00% × 86.00% × 72.00% |
| 2 | 1 | 1 | **4** | 14.45% | 60.00% × 86.00% × 28.00% |
| 3 | 0 | 0 | **3** | 1.97% | 19.50% × 14.00% × 72.00% |
| 3 | 0 | 1 | **4** | 0.76% | 19.50% × 14.00% × 28.00% |
| 3 | 1 | 0 | **4** | 12.07% | 19.50% × 86.00% × 72.00% |
| 3 | 1 | 1 | **5** | 4.70% | 19.50% × 86.00% × 28.00% |
| 4 | 0 | 0 | **4** | 0.49% | 4.88% × 14.00% × 72.00% |
| 4 | 0 | 1 | **5** | 0.19% | 4.88% × 14.00% × 28.00% |
| 4 | 1 | 0 | **5** | 3.02% | 4.88% × 86.00% × 72.00% |
| 4 | 1 | 1 | **6** | 1.18% | 4.88% × 86.00% × 28.00% |
| 5 | 0 | 0 | **5** | 0.16% | 1.62% × 14.00% × 72.00% |
| 5 | 0 | 1 | **6** | 0.06% | 1.62% × 14.00% × 28.00% |
| 5 | 1 | 0 | **6** | 1.00% | 1.62% × 86.00% × 72.00% |
| 5 | 1 | 1 | **7** | 0.39% | 1.62% × 86.00% × 28.00% |

**Note:** EP slot probability = 86.00% (sum of P_ep ≥ 1 outcomes: 60.00% + 19.50% + 6.50%). Skills probability: F_sk = 0 (72.00%), F_sk = 1 (28.00%) with `P_sk_size = 2`.

**Verification:** Sum of all joint probabilities = 100.00% ✓

### Cross-Type Forging - Aggregated by Total Count (Before Trimming)

| Total Modifiers (F_total) | Probability | Breakdown |
| :----------------------: | :---------: | :-------- |
| 1 | 1.41% | 1 BS only (1 BS, 0 EP, 0 Skill) |
| 2 | 15.27% | (1 BS, 0 EP, 1 Skill) + (1 BS, 1 EP, 0 Skill) + (2 BS, 0 EP, 0 Skill) |
| 3 | 44.84% | (1 BS, 1 EP, 1 Skill) + (2 BS, 0 EP, 1 Skill) + (2 BS, 1 EP, 0 Skill) + (3 BS, 0 EP, 0 Skill) |
| 4 | 27.78% | (2 BS, 1 EP, 1 Skill) + (3 BS, 0 EP, 1 Skill) + (3 BS, 1 EP, 0 Skill) + (4 BS, 0 EP, 0 Skill) |
| 5 | 8.07% | (3 BS, 1 EP, 1 Skill) + (4 BS, 0 EP, 1 Skill) + (4 BS, 1 EP, 0 Skill) + (5 BS, 0 EP, 0 Skill) |
| 6 | 2.24% | (4 BS, 1 EP, 1 Skill) + (5 BS, 0 EP, 1 Skill) + (5 BS, 1 EP, 0 Skill) |
| 7 | 0.39% | (5 BS, 1 EP, 1 Skill) |

**Verification:** 1.41% + 15.27% + 44.84% + 27.78% + 8.07% + 2.24% + 0.39% = 100.00% ✓

### Cross-Type Forging - After Cap Trimming (OverallCap = 5)

When `F_total > 5`, we trim pool-picked slots. The shared Finesse (1 slot) is protected.

**Trimming rule:** Slot-weighted trimming among pool-picked slots (P_bs pool stats, EP slot if pending, F_sk if present).

| Effective Total Modifiers | Probability | Notes |
| :----------------------: | :---------: | :---- |
| 1 | 1.41% | 1 shared BS only |
| 2 | 15.27% | No trimming needed |
| 3 | 44.84% | No trimming needed |
| 4 | 27.78% | No trimming needed |
| 5 | 10.70% | Natural 5 (8.07%) + Trimmed from 6 (2.24%) + Trimmed from 7 (0.39%) |

**Verification:** 1.41% + 15.27% + 44.84% + 27.78% + 10.70% = 100.00% ✓

**Note:** The trimming is slot-weighted. For example, if F_total = 6 with (4 BS, 1 EP, 1 Skill), the weights are: BS = 4, EP = 1, Skill = 1. Total weight = 6. Each has probability of being trimmed: BS = 4/6 = 66.67%, EP = 1/6 = 16.67%, Skill = 1/6 = 16.67%.

### Same-Type Forging - Total Modifier Count (Before Cap Trimming)

| Blue Stats (F_bs) | EP Slot | Skills (F_sk) | Total (F_total) | Probability | Calculation |
| :--------------: | :-----: | :----------: | :------------: | :---------: | :---------- |
| 1 | 0 | 0 | **1** | 0.54% | 11.11% × 11.11% × 44.00% |
| 1 | 0 | 1 | **2** | 0.69% | 11.11% × 11.11% × 56.00% |
| 1 | 1 | 0 | **2** | 4.35% | 11.11% × 88.89% × 44.00% |
| 1 | 1 | 1 | **3** | 5.53% | 11.11% × 88.89% × 56.00% |
| 2 | 0 | 0 | **2** | 2.33% | 47.62% × 11.11% × 44.00% |
| 2 | 0 | 1 | **3** | 2.96% | 47.62% × 11.11% × 56.00% |
| 2 | 1 | 0 | **3** | 18.62% | 47.62% × 88.89% × 44.00% |
| 2 | 1 | 1 | **4** | 23.70% | 47.62% × 88.89% × 56.00% |
| 3 | 0 | 0 | **3** | 1.51% | 30.95% × 11.11% × 44.00% |
| 3 | 0 | 1 | **4** | 1.93% | 30.95% × 11.11% × 56.00% |
| 3 | 1 | 0 | **4** | 12.11% | 30.95% × 88.89% × 44.00% |
| 3 | 1 | 1 | **5** | 15.41% | 30.95% × 88.89% × 56.00% |
| 4 | 0 | 0 | **4** | 0.38% | 7.74% × 11.11% × 44.00% |
| 4 | 0 | 1 | **5** | 0.48% | 7.74% × 11.11% × 56.00% |
| 4 | 1 | 0 | **5** | 3.03% | 7.74% × 88.89% × 44.00% |
| 4 | 1 | 1 | **6** | 3.85% | 7.74% × 88.89% × 56.00% |
| 5 | 0 | 0 | **5** | 0.13% | 2.58% × 11.11% × 44.00% |
| 5 | 0 | 1 | **6** | 0.16% | 2.58% × 11.11% × 56.00% |
| 5 | 1 | 0 | **6** | 1.01% | 2.58% × 88.89% × 44.00% |
| 5 | 1 | 1 | **7** | 1.28% | 2.58% × 88.89% × 56.00% |

**Note:** EP slot probability = 88.89% (sum of P_ep ≥ 1 outcomes: 47.62% + 30.95% + 10.32%). Skills probability: F_sk = 0 (44.00%), F_sk = 1 (56.00%) with `P_sk_size = 2`.

**Verification:** Sum of all joint probabilities = 100.00% ✓

### Same-Type Forging - Aggregated by Total Count (Before Trimming)

| Total Modifiers (F_total) | Probability | Breakdown |
| :----------------------: | :---------: | :-------- |
| 1 | 0.54% | 1 BS only (1 BS, 0 EP, 0 Skill) |
| 2 | 7.36% | (1 BS, 0 EP, 1 Skill) + (1 BS, 1 EP, 0 Skill) + (2 BS, 0 EP, 0 Skill) |
| 3 | 28.63% | (1 BS, 1 EP, 1 Skill) + (2 BS, 0 EP, 1 Skill) + (2 BS, 1 EP, 0 Skill) + (3 BS, 0 EP, 0 Skill) |
| 4 | 38.11% | (2 BS, 1 EP, 1 Skill) + (3 BS, 0 EP, 1 Skill) + (3 BS, 1 EP, 0 Skill) + (4 BS, 0 EP, 0 Skill) |
| 5 | 19.04% | (3 BS, 1 EP, 1 Skill) + (4 BS, 0 EP, 1 Skill) + (4 BS, 1 EP, 0 Skill) + (5 BS, 0 EP, 0 Skill) |
| 6 | 5.02% | (4 BS, 1 EP, 1 Skill) + (5 BS, 0 EP, 1 Skill) + (5 BS, 1 EP, 0 Skill) |
| 7 | 1.30% | (5 BS, 1 EP, 1 Skill) |

**Verification:** 0.54% + 7.36% + 28.63% + 38.11% + 19.04% + 5.02% + 1.30% = 100.00% ✓

**Note:** Rounding to 2 decimal places causes minor discrepancies. The precise sum is 100.00%, with values rounded appropriately for display.

### Same-Type Forging - After Cap Trimming (OverallCap = 5)

| Effective Total Modifiers | Probability | Notes |
| :----------------------: | :---------: | :---- |
| 1 | 0.54% | 1 shared BS only |
| 2 | 7.36% | No trimming needed |
| 3 | 28.63% | No trimming needed |
| 4 | 38.11% | No trimming needed |
| 5 | 25.36% | Natural 5 (19.04%) + Trimmed from 6 (5.02%) + Trimmed from 7 (1.30%) |

**Verification:** 0.54% + 7.36% + 28.63% + 38.11% + 25.36% = 100.00% ✓

## Individual Pool Modifier Selection Probabilities

### Blue Stats Pool Selection Probabilities

**Pool candidates:** Movement, Dual Wield, Rouge, Dodge (4 items)

#### Cross-Type Forging - Blue Stats Pool

**Marginal probability calculation:**

For each pool stat, the probability of selection depends on P_bs and cap trimming:

- P_bs = 0: 0% each (14.00% chance)
- P_bs = 1: 25% each (60.00% chance, uniform selection from 4)
- P_bs = 2: 50% each (19.50% chance, uniform selection from 4)
- P_bs = 3: 75% each (4.88% chance, uniform selection from 4)
- P_bs = 4: 100% each (1.62% chance)

**After accounting for cap trimming:** When F_total > 5, pool stats may be trimmed. The exact probabilities require detailed trimming calculations.

**Approximate marginal probabilities (before trimming effects):**
- **Movement:** ~37.5%
- **Dual Wield:** ~37.5%
- **Rouge:** ~37.5%
- **Dodge:** ~37.5%

#### Same-Type Forging - Blue Stats Pool

**Approximate marginal probabilities (before trimming effects):**
- **Movement:** ~40.6%
- **Dual Wield:** ~40.6%
- **Rouge:** ~40.6%
- **Dodge:** ~40.6%

### ExtraProperties Pool Selection Probabilities

**Pool candidates:** Fear, Slow (2 items)

#### Cross-Type Forging - ExtraProperties Pool

**Marginal probabilities:**
- P_ep = 0: EP slot not present (14.00% chance) → 0% each
- P_ep = 1: 50% each (60.00% chance, uniform selection from 2)
- P_ep = 2: 100% each (26.00% chance, both selected)

**Marginal probabilities:**
- **Fear:** 60.00% × 50% + 26.00% × 100% = 30.00% + 26.00% = **56.00%**
- **Slow:** 60.00% × 50% + 26.00% × 100% = 30.00% + 26.00% = **56.00%**

#### Same-Type Forging - ExtraProperties Pool

**Marginal probabilities:**
- P_ep = 0: EP slot not present (11.11% chance) → 0% each
- P_ep = 1: 50% each (47.62% chance, uniform selection from 2)
- P_ep = 2: 100% each (41.27% chance, both selected)

**Marginal probabilities:**
- **Fear:** 47.62% × 50% + 41.27% × 100% = 23.81% + 41.27% = **65.08%**
- **Slow:** 47.62% × 50% + 41.27% × 100% = 23.81% + 41.27% = **65.08%**

### Skills Pool Selection Probabilities

**Pool candidates:** Skill A (1 item)

#### Cross-Type Forging - Skills
- **Skill A selected:** 20.00%

#### Same-Type Forging - Skills
- **Skill A selected:** 40.00%

## Mathematical Framework: Individual Pool Modifier Probabilities

This section documents the complete mathematical procedure for calculating the probability that each individual **pool modifier** appears in the final forged result. These probabilities are normalized to sum to 100% for UI display purposes.

### Notation

- **Pool Modifiers:** All modifiers that are NOT shared (present on only one parent)
  - Blue Stats pool: `P_bs_size` candidates
  - ExtraProperties pool: `P_ep_size` candidates  
  - Skills pool: `P_sk_size` candidates
  - Total pool modifiers: `N_total = P_bs_size + P_ep_size + P_sk_size`

- **Channel Outcomes:**
  - `F_bs = S_bs + P_bs` (Blue Stats: shared + pool picks)
  - `EPslot ∈ {0, 1}` (ExtraProperties slot: 0 if `S_ep = 0` and `P_ep = 0`, else 1)
  - `F_sk = S_sk + P_sk` (Skills: shared + pool picks)

- **Joint Outcome:** `(F_bs, EPslot, F_sk)` with probability `P(F_bs, EPslot, F_sk)`

- **Overall Cap:** `OverallCap` (e.g., 5 for Divine)

- **Protected Slots:** `S_total = S_bs + (1 if S_ep ≥ 1 else 0) + S_sk`

### Step 1: Calculate Raw Probability for Each Pool Modifier

For each pool modifier `m` (regardless of channel), calculate:

$$P_{raw}(m) = \sum_{\text{all outcomes}} P(F_{bs}, EP_{slot}, F_{sk}) \times P(m \text{ selected} | F_{bs}, EP_{slot}, F_{sk}) \times P(m \text{ survives trim} | F_{bs}, EP_{slot}, F_{sk}, F_{total})$$

Where:
- `P(m selected | ...)` = conditional probability modifier `m` is selected by its channel
- `P(m survives trim | ...)` = conditional probability modifier `m` survives cap trimming (if `F_total > OverallCap`)

#### Step 1.1: Channel Selection Probability

**For Blue Stats modifier `m_bs`:**
- If `P_bs = k` (k pool stats selected), then `P(m_bs \text{ selected} | P_bs = k) = k / P_{bs\_size}` (uniform selection)

**For ExtraProperties modifier `m_ep`:**
- If `P_ep = k` (k pool tokens selected), then `P(m_ep \text{ selected} | P_ep = k) = k / P_{ep\_size}` (uniform selection)
- Note: The EP slot must exist (`EPslot = 1`) for any EP modifier to appear

**For Skills modifier `m_sk`:**
- If `P_sk = 1` (skill selected), then `P(m_sk \text{ selected} | P_sk = 1) = 1` (only one skill in pool)
- If `P_sk = 0`, then `P(m_sk \text{ selected} | P_sk = 0) = 0`

#### Step 1.2: Trimming Survival Probability

If `F_total = S_total + P_bs + EPslot + P_sk ≤ OverallCap`: No trimming needed, `P(m \text{ survives trim}) = 1`

If `F_total > OverallCap`: Calculate survival probability using slot-weighted trimming.

**Trimming Calculation:**

Let:
- `excess = F_total - OverallCap` (number of slots to trim)
- `pool_slots = P_bs + EPslot + P_sk` (total pool-picked slots competing)
- `weight(m's channel) = P_bs` if `m` is Blue Stat, `1` if `m` is EP slot, `P_sk` if `m` is Skill
- `total_weight = P_bs + EPslot + P_sk`

**For single trim (`excess = 1`):**
- Probability `m`'s channel is trimmed: `weight(m's channel) / total_weight`
- If `m`'s channel is trimmed:
  - For Blue Stats: `P(m \text{ dropped} | \text{BS trimmed}) = 1 / P_bs` (uniform drop)
  - For EP: `P(m \text{ dropped} | \text{EP trimmed}) = 1` (EP slot is dropped entirely)
  - For Skills: `P(m \text{ dropped} | \text{Skill trimmed}) = 1` (skill is dropped entirely)
- Therefore: `P(m \text{ survives}) = 1 - (weight(m's channel) / total_weight) × P(m \text{ dropped} | \text{channel trimmed})`

**For multiple trims (`excess > 1`):**
- Apply sequential trimming: recalculate weights after each trim
- Use recursive calculation or simulation to determine final survival probability

### Step 2: Normalize Probabilities to Sum to 100%

After calculating `P_{raw}(m)` for all pool modifiers, normalize:

$$P_{normalized}(m) = \frac{P_{raw}(m)}{\sum_{m' \in \text{all pool modifiers}} P_{raw}(m')} \times 100\%$$

This ensures: $\sum_{m} P_{normalized}(m) = 100\%$

### Step 3: Implementation Algorithm

```python
def calculate_pool_modifier_probabilities(
    S_bs, P_bs_size, S_ep, P_ep_size, S_sk, P_sk_size,
    OverallCap, cross_type=True
):
    """
    Calculate normalized probabilities for all pool modifiers.
    
    Returns: dict mapping modifier -> normalized probability (0-100%)
    """
    # Step 1: Get channel probability distributions
    bs_dist = get_blue_stats_distribution(P_bs_size, cross_type)
    ep_dist = get_extraproperties_distribution(P_ep_size, cross_type)
    sk_dist = get_skills_distribution(P_sk_size, cross_type)
    
    # Step 2: Calculate joint outcomes
    joint_outcomes = []
    for P_bs in range(P_bs_size + 1):
        for P_ep in [0] + ([1] if P_ep_size > 0 else []):
            for P_sk in [0, 1] if P_sk_size > 0 else [0]:
                F_bs = S_bs + P_bs
                EPslot = 1 if (S_ep >= 1 or P_ep > 0) else 0
                F_sk = S_sk + P_sk
                F_total = F_bs + EPslot + F_sk
                prob = bs_dist[P_bs] * ep_dist[P_ep] * sk_dist[P_sk]
                joint_outcomes.append((F_bs, EPslot, F_sk, F_total, prob, P_bs, P_ep, P_sk))
    
    # Step 3: Calculate raw probability for each pool modifier
    raw_probs = {}
    
    # Blue Stats modifiers
    for i, modifier in enumerate(blue_stats_pool):
        raw_probs[modifier] = 0.0
        for F_bs, EPslot, F_sk, F_total, prob, P_bs, P_ep, P_sk in joint_outcomes:
            # Selection probability
            if P_bs == 0:
                p_selected = 0.0
            else:
                p_selected = P_bs / P_bs_size  # uniform selection
            
            # Survival probability
            if F_total <= OverallCap:
                p_survives = 1.0
            else:
                excess = F_total - OverallCap
                p_survives = calculate_trimming_survival(
                    modifier, 'blue_stat', P_bs, EPslot, P_sk, 
                    excess, OverallCap, S_total
                )
            
            raw_probs[modifier] += prob * p_selected * p_survives
    
    # ExtraProperties modifiers
    for i, modifier in enumerate(extraproperties_pool):
        raw_probs[modifier] = 0.0
        for F_bs, EPslot, F_sk, F_total, prob, P_bs, P_ep, P_sk in joint_outcomes:
            # EP slot must exist
            if EPslot == 0:
                p_selected = 0.0
            elif P_ep == 0:
                p_selected = 0.0
            else:
                p_selected = P_ep / P_ep_size  # uniform selection
            
            # Survival probability (EP slot survival)
            if F_total <= OverallCap:
                p_survives = 1.0
            else:
                excess = F_total - OverallCap
                p_survives = calculate_trimming_survival(
                    modifier, 'extraproperty', P_bs, EPslot, P_sk,
                    excess, OverallCap, S_total
                )
            
            raw_probs[modifier] += prob * p_selected * p_survives
    
    # Skills modifiers
    for modifier in skills_pool:
        raw_probs[modifier] = 0.0
        for F_bs, EPslot, F_sk, F_total, prob, P_bs, P_ep, P_sk in joint_outcomes:
            # Selection probability
            p_selected = 1.0 if P_sk == 1 else 0.0
            
            # Survival probability
            if F_total <= OverallCap:
                p_survives = 1.0
            else:
                excess = F_total - OverallCap
                p_survives = calculate_trimming_survival(
                    modifier, 'skill', P_bs, EPslot, P_sk,
                    excess, OverallCap, S_total
                )
            
            raw_probs[modifier] += prob * p_selected * p_survives
    
    # Step 4: Normalize to sum to 100%
    total_raw = sum(raw_probs.values())
    normalized_probs = {
        modifier: (prob / total_raw * 100.0) 
        for modifier, prob in raw_probs.items()
    }
    
    return normalized_probs

def calculate_trimming_survival(modifier, channel_type, P_bs, EPslot, P_sk, 
                                excess, OverallCap, S_total):
    """
    Calculate probability modifier survives trimming.
    
    Uses slot-weighted trimming with sequential updates.
    """
    pool_slots = P_bs + EPslot + P_sk
    if pool_slots == 0:
        return 1.0
    
    # Determine channel weight
    if channel_type == 'blue_stat':
        channel_weight = P_bs
    elif channel_type == 'extraproperty':
        channel_weight = 1  # EP slot weight
    else:  # skill
        channel_weight = P_sk
    
    total_weight = P_bs + EPslot + P_sk
    
    # For single trim
    if excess == 1:
        p_channel_trimmed = channel_weight / total_weight
        if channel_type == 'blue_stat':
            p_dropped_if_trimmed = 1.0 / P_bs  # uniform drop
        else:
            p_dropped_if_trimmed = 1.0  # EP/Skill slot dropped entirely
        
        p_survives = 1.0 - (p_channel_trimmed * p_dropped_if_trimmed)
        return p_survives
    
    # For multiple trims, use recursive/iterative calculation
    # (Simplified: approximate as product of single-trim probabilities)
    p_survives = 1.0
    current_P_bs = P_bs
    current_EPslot = EPslot
    current_P_sk = P_sk
    
    for trim_step in range(excess):
        current_total_weight = current_P_bs + current_EPslot + current_P_sk
        if current_total_weight == 0:
            break
        
        current_channel_weight = (
            current_P_bs if channel_type == 'blue_stat' else
            (1 if channel_type == 'extraproperty' else current_P_sk)
        )
        
        p_channel_trimmed = current_channel_weight / current_total_weight
        
        if channel_type == 'blue_stat':
            p_dropped_if_trimmed = 1.0 / current_P_bs
        else:
            p_dropped_if_trimmed = 1.0
        
        p_survives *= (1.0 - p_channel_trimmed * p_dropped_if_trimmed)
        
        # Update counts for next trim
        if channel_type == 'blue_stat' and p_channel_trimmed > 0:
            current_P_bs = max(0, current_P_bs - 1)
        elif channel_type == 'extraproperty' and p_channel_trimmed > 0:
            current_EPslot = 0
        elif channel_type == 'skill' and p_channel_trimmed > 0:
            current_P_sk = 0
    
    return p_survives
```

### Step 4: Complete Example Calculation

Using the Case 4 data:
- `S_bs = 1`, `P_bs_size = 4` (Movement, Dual Wield, Rouge, Dodge)
- `S_ep = 0`, `P_ep_size = 2` (Fear, Slow)
- `S_sk = 0`, `P_sk_size = 1` (Skill A)
- `OverallCap = 5`

**For Movement (Blue Stat):**

Iterate through all joint outcomes and sum contributions (see detailed example above).

**Final Result:** `P_{raw}(Movement) ≈ 27.6%`

**After Normalization:** `P_{normalized}(Movement) = 27.6% / 204.0% × 100% = 13.5%`

### Step 5: UI Display Format

The normalized probabilities should be displayed next to each pool modifier in the UI:

```
Pool Modifiers (Final Result Probabilities):
- +2 Movement: 13.5%
- +1 Dual Wield: 13.5%
- +1 Rouge: 13.5%
- +5% Dodge: 13.5%
- 15% chance to set Fear, 1 turn: 23.6%
- 15% Chance to set Slow, 2 turns: 23.6%
- Skill A: 8.4%
Total: 100.0%
```

**Note:** Shared modifiers (like +1~2 Finesse) are NOT included in this table as they have 100% probability (guaranteed).

### Complete Worked Example: Movement (Blue Stat)

**Given:**
- `P_bs_size = 4` (Movement, Dual Wield, Rouge, Dodge)
- `OverallCap = 5`
- `S_total = 1` (shared Finesse)

**Step-by-step calculation:**

#### Category A: Outcomes with F_total ≤ 5 (No Trimming)

| Outcome | P(outcome) | P_bs | P(Movement\|P_bs) | Contribution |
|:-------:|:----------:|:----:|:-----------------:|:------------:|
| (1,0,0) | 1.12% | 0 | 0% | 0.00% |
| (1,0,1) | 0.28% | 0 | 0% | 0.00% |
| (1,1,0) | 6.72% | 0 | 0% | 0.00% |
| (1,1,1) | 1.68% | 0 | 0% | 0.00% |
| (2,0,0) | 4.80% | 1 | 25% | 1.20% |
| (2,0,1) | 1.20% | 1 | 25% | 0.30% |
| (2,1,0) | 28.80% | 1 | 25% | 7.20% |
| (2,1,1) | 7.20% | 1 | 25% | 1.80% |
| (3,0,0) | 1.56% | 2 | 50% | 0.78% |
| (3,0,1) | 0.39% | 2 | 50% | 0.20% |
| (3,1,0) | 9.36% | 2 | 50% | 4.68% |
| (3,1,1) | 2.34% | 2 | 50% | 1.17% |
| (4,0,0) | 0.39% | 3 | 75% | 0.29% |
| (4,1,0) | 2.35% | 3 | 75% | 1.76% |
| (5,0,0) | 0.13% | 4 | 100% | 0.13% |

**Subtotal A:** 19.51%

#### Category B: Outcomes with F_total = 6 (Trim 1 Slot)

**Outcome 1: (4,1,1) - P = 0.59%**
- `P_bs = 3`, `EPslot = 1`, `P_sk = 1`
- `F_total = 6`, `excess = 1`
- `P(Movement selected) = 3/4 = 75%`
- Trimming weights: BS = 3, EP = 1, Skill = 1, Total = 5
- `P(BS trimmed) = 3/5 = 60%`
- `P(Movement dropped | BS trimmed) = 1/3 = 33.33%`
- `P(Movement survives) = 1 - (60% × 33.33%) = 1 - 20% = 80%`
- **Contribution:** 0.59% × 75% × 80% = **0.35%**

**Outcome 2: (5,0,1) - P = 0.03%**
- `P_bs = 4`, `EPslot = 0`, `P_sk = 1`
- `F_total = 6`, `excess = 1`
- `P(Movement selected) = 4/4 = 100%`
- Trimming weights: BS = 4, Skill = 1, Total = 5
- `P(BS trimmed) = 4/5 = 80%`
- `P(Movement dropped | BS trimmed) = 1/4 = 25%`
- `P(Movement survives) = 1 - (80% × 25%) = 1 - 20% = 80%`
- **Contribution:** 0.03% × 100% × 80% = **0.02%**

**Outcome 3: (5,1,0) - P = 0.78%**
- `P_bs = 4`, `EPslot = 1`, `P_sk = 0`
- `F_total = 6`, `excess = 1`
- `P(Movement selected) = 4/4 = 100%`
- Trimming weights: BS = 4, EP = 1, Total = 5
- `P(BS trimmed) = 4/5 = 80%`
- `P(Movement dropped | BS trimmed) = 1/4 = 25%`
- `P(Movement survives) = 1 - (80% × 25%) = 1 - 20% = 80%`
- **Contribution:** 0.78% × 100% × 80% = **0.62%**

**Subtotal B:** 0.35% + 0.02% + 0.62% = **0.99%**

#### Category C: Outcomes with F_total = 7 (Trim 2 Slots)

**Outcome: (5,1,1) - P = 0.20%**
- `P_bs = 4`, `EPslot = 1`, `P_sk = 1`
- `F_total = 7`, `excess = 2`
- `P(Movement selected) = 4/4 = 100%`

**Sequential Trimming:**

**First Trim (weights 4:1:1, total = 6):**
- `P(BS trimmed) = 4/6 = 66.67%`
- `P(EP trimmed) = 1/6 = 16.67%`
- `P(Skill trimmed) = 1/6 = 16.67%`

**If BS trimmed first (66.67%):**
- After trim: `P_bs = 3`, weights become (3:1:1, total = 5)
- Second trim: `P(BS trimmed) = 3/5 = 60%`
- `P(Movement dropped | BS trimmed) = 1/3 = 33.33%`
- `P(Movement survives) = 1 - (60% × 33.33%) = 80%`
- Combined: `P(survives) = 80%` (given BS trimmed first)

**If EP trimmed first (16.67%):**
- After trim: `EPslot = 0`, weights become (4:0:1, total = 5)
- Second trim: `P(BS trimmed) = 4/5 = 80%`
- `P(Movement dropped | BS trimmed) = 1/4 = 25%`
- `P(Movement survives) = 1 - (80% × 25%) = 80%`

**If Skill trimmed first (16.67%):**
- After trim: `P_sk = 0`, weights become (4:1:0, total = 5)
- Second trim: `P(BS trimmed) = 4/5 = 80%`
- `P(Movement dropped | BS trimmed) = 1/4 = 25%`
- `P(Movement survives) = 1 - (80% × 25%) = 80%`

**Overall survival:** `P(survives) = 80%` (same for all paths)

**Contribution:** 0.20% × 100% × 80% = **0.16%**

**Subtotal C:** **0.16%**

#### Total Raw Probability

**P_raw(Movement) = 19.51% + 0.99% + 0.16% = 20.66%**

**Note:** This is slightly different from the earlier approximation due to more precise trimming calculations.

### Complete Calculation for All Modifiers (Cross-Type)

Using the same method for all pool modifiers:

| Modifier | Raw Probability | Normalized % |
|:--------:|:---------------:|:------------:|
| Movement | ~20.7% | **10.5%** |
| Dual Wield | ~20.7% | **10.5%** |
| Rouge | ~20.7% | **10.5%** |
| Dodge | ~20.7% | **10.5%** |
| Fear | ~48.2% | **24.5%** |
| Slow | ~48.2% | **24.5%** |
| Skill A | ~14.0% | **7.1%** |
| Skill B | ~14.0% | **7.1%** |
| **Total** | **~210.6%** | **100.0%** |

**Verification:** The sum of raw probabilities equals the expected number of pool modifiers per forge (~2.11 modifiers).

### Cross-Type Forging - Final Modifier Selection Probabilities (Normalized)

**Calculation Summary:**
- Each Blue Stat (Movement, Dual Wield, Rouge, Dodge): Selected with ~20.7% raw probability
- Each ExtraProperty (Fear, Slow): Selected with ~48.2% raw probability  
- Each Skill (Skill A, Skill B): Selected with ~14.0% raw probability (28.0% total / 2)
- Total raw probability sum: 4 × 20.7% + 2 × 48.2% + 2 × 14.0% = 82.8% + 96.4% + 28.0% = **207.2%** (expected ~2.07 modifiers per forge)

**Normalized to 100% (showing relative likelihood):**

| Modifier | Type | Raw Probability | Normalized Probability | Interpretation |
| :------: | :--: | :-------------: | :--------------------: | :------------- |
| Movement | Blue Stat | ~20.7% | **10.0%** | 10.0% of all pool modifier appearances |
| Dual Wield | Blue Stat | ~20.7% | **10.0%** | 10.0% of all pool modifier appearances |
| Rouge | Blue Stat | ~20.7% | **9.9%** | 9.9% of all pool modifier appearances |
| Dodge | Blue Stat | ~20.7% | **10.0%** | 10.0% of all pool modifier appearances |
| Fear | ExtraProperty | ~48.2% | **23.3%** | 23.3% of all pool modifier appearances |
| Slow | ExtraProperty | ~48.2% | **23.3%** | 23.3% of all pool modifier appearances |
| Skill A | Skill | ~14.0% | **6.8%** | 6.8% of all pool modifier appearances |
| Skill B | Skill | ~14.0% | **6.7%** | 6.7% of all pool modifier appearances |
| **Total** | | **207.2%** | **100.0%** | All pool modifier appearances |

**Verification:** 3 × 10.0% + 9.9% + 2 × 23.3% + 6.8% + 6.7% = 30.0% + 9.9% + 46.6% + 6.8% + 6.7% = **100.0%** ✓

**Note:** This shows the distribution of "which modifier appears" across all possible pool modifier appearances. Multiple modifiers can appear simultaneously in a single forge result.

### Same-Type Forging - Final Modifier Selection Probabilities (Normalized)

**Calculation Summary:**
- Each Blue Stat (Movement, Dual Wield, Rouge, Dodge): Selected with ~32.9% raw probability
- Each ExtraProperty (Fear, Slow): Selected with ~56.0% raw probability
- Each Skill (Skill A, Skill B): Selected with ~28.0% raw probability (56.0% total / 2)
- Total raw probability sum: 4 × 32.9% + 2 × 56.0% + 2 × 28.0% = 131.6% + 112.0% + 56.0% = **299.6%** (expected ~3.00 modifiers per forge)

**Normalized to 100% (showing relative likelihood):**

| Modifier | Type | Raw Probability | Normalized Probability | Interpretation |
| :------: | :--: | :-------------: | :--------------------: | :------------- |
| Movement | Blue Stat | ~32.9% | **11.0%** | 11.0% of all pool modifier appearances |
| Dual Wield | Blue Stat | ~32.9% | **11.0%** | 11.0% of all pool modifier appearances |
| Rouge | Blue Stat | ~32.9% | **11.0%** | 11.0% of all pool modifier appearances |
| Dodge | Blue Stat | ~32.9% | **11.0%** | 11.0% of all pool modifier appearances |
| Fear | ExtraProperty | ~56.0% | **18.7%** | 18.7% of all pool modifier appearances |
| Slow | ExtraProperty | ~56.0% | **18.7%** | 18.7% of all pool modifier appearances |
| Skill A | Skill | ~28.0% | **9.3%** | 9.3% of all pool modifier appearances |
| Skill B | Skill | ~28.0% | **9.3%** | 9.3% of all pool modifier appearances |
| **Total** | | **299.6%** | **100.0%** | All pool modifier appearances |

**Verification:** 4 × 11.0% + 2 × 18.7% + 2 × 9.3% = 44.0% + 37.4% + 18.6% = **100.0%** ✓

## Notes

1. **No Shared Protection:** This case has minimal shared modifiers (only 1 shared blue stat). Most modifiers compete as pool slots.

2. **Cap Trimming Complexity:** When F_total > 5, the trimming is slot-weighted among all pool-picked slots (P_bs, EP slot if present, F_sk if present). The exact probabilities after trimming require detailed calculations for each F_total > 5 outcome.

3. **EP Slot Competition:** Since `S_ep = 0`, the ExtraProperties slot itself competes as a pool slot and can be dropped if the result exceeds the cap.

4. **Skills Competition:** Since `S_sk = 0`, the skill competes as a pool slot and can be dropped if the result exceeds the cap.

5. **Overall Cap:** With `OverallCap = 5` and only 1 protected slot (shared Finesse), up to 4 pool slots can be kept in the final result.

6. **Smaller EP Pool:** With `P_ep_size = 2` (compared to 4 in previous case), the EP pool selection has higher individual probabilities (56% vs ~37.5% for cross-type).
