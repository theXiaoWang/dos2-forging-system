## Forging System (SE Required) — Implementation Blueprint

## Scope and hard rules
- **Script Extender is required**.
- **Slot 1 decides base weapon type**: the item placed in the first slot is the “base identity” (template/stats entry) for the forged result.
- **Rarity is decided first** (per `rarity_system.md`).
- Only **rollable modifiers** are merged/rolled. **Innate/base weapon properties** are preserved by choosing the base weapon from slot 1.

## Recommended architecture
- **Crafting recipe (data)**: a single “forge” recipe that triggers your system via the vanilla crafting UI.
- **Story/Osiris hook (control plane)**: detects that your forge recipe was executed and passes GUIDs to Lua.
- **Lua (Script Extender) logic (data plane)**: reads both parent items, computes rarity + inherited rolls, spawns/updates the result item, and consumes parents.

## Determinism, authority, and seeding (multiplayer + save/load)

This is the core consistency rule for a robust RPG forging system:

- **Host-authoritative**: the host/server is the only place that rolls randomness for forging.
  - Clients must not roll stats/skills locally.
  - The host replicates the **final forged item** (rarity, rolled stats, granted skills) to all clients.
- **Deterministic RNG on the host**: all randomness is driven by a deterministic PRNG seeded once per forge:
  - rarity selection (sampling from `rarity_system.md` distributions, if you sample at runtime),
  - shared-stat value merge rolls (Section 3.1 logic in `inheritance_system.md`),
  - pool stat selection + trimming under the rarity cap,
  - granted-skill gated fill + trimming under the skill cap.

### Save/load fishing (player behaviour)
If **forgeSeed changes per attempt** (for example, based on time, a volatile RNG state, or a per-attempt random seed that is not preserved across reload), players can save before forging and reload to try again for different results.

This blueprint assumes:
- seeded RNG is used for **multiplayer consistency** and **debug reproducibility**;
- save/load fishing may still be possible unless you deliberately make `forgeSeed` stable across reload for the same pre-forge state.

## Core concepts you must keep distinct

### Innate (non-rollable) weapon identity
These come from the weapon’s base stat entry + its inheritance chain in `Weapon.stats` (e.g. `WPN_Staff_Fire` → `_Staffs_Fire` → `_Staffs`).
Typical innate examples:
- Base damage line (e.g. `311–381 Fire`)
- Base `CriticalDamage` (often `150%`)
- Range / durability / requirements
- Granted skills (e.g. Staff of Magus)
- Elemental wand/staff behaviour shown as blue lines (e.g. “Creates an Ice surface…”, “Ignite;Melt”) — these are commonly archetype `ExtraProperties`

These should **not** enter your forgeable pool.

### Rollable modifiers (“blue stat rolls”)
These are implemented as **boosts/affixes** (commonly `_Boost_*`) selected from roll tables.
Typical rollable examples:
- Attribute bonuses (`+Intelligence`, `+Finesse`, etc.)
- Accuracy, Critical Chance, Life Steal, etc.
- “Set X for 1 turn(s). Y% chance…” effects (status-chance lines)

In vanilla data, many “Set status” lines are boosts whose payload is encoded via `ExtraProperties` on the boost definition (e.g. `BLIND,20,1`, `MUTED,10,1`).

## Canonical base-game data sources (editor data)
You will not read these `.stats` files at runtime via Story. Use Script Extender to read item instance data and/or ship precompiled lookup tables derived from these files.

### Roll tables / eligibility (what can roll, and constraints)
- `DefEd/Data/Editor/Mods/Shared/Stats/DeltaModifier/DeltaModifier.stats`
  - Contains weapon roll candidates (`Boost_*`) and constraints such as:
    - `ModifierType = Weapon`
    - `WeaponType` (Knife/Sword/Bow/etc.)
    - `Handedness` (1H vs 2H)

### Boost definitions (what the roll actually does)
- `DefEd/Data/Editor/Mods/Shared/Stats/Stats/Weapon.stats`
  - Contains `_Boost_Weapon_*` definitions.
  - Status-chance boosts live here, e.g. `_Boost_Weapon_Status_Set_Blind` with `ExtraProperties = BLIND,10,1`.

## Implementation blueprint (step-by-step)

## Step 0: Ingredient eligibility
Hard rule: **weapons with socketed runes must not be accepted as forging ingredients**.

Reject an ingredient if **either** is true:
- **Runes are inserted** into any socket (even if the rune only grants “utility” effects).
- The weapon has **any stats modifiers and/or granted skills originating from rune sockets**.

Empty rune slots are allowed. The forged item’s rune slot count should be inherited separately:
- Take the average of the two parents’ rune slot counts, then **round up**: `ceil((A + B) / 2)`

| Parent A slots | Parent B slots | Forged slots |
| :---: | :---: | :---: |
| 1 | 2 | 2 |
| 2 | 3 | 3 |
| 1 | 3 | 2 |

Implementation notes (SE):
- Treat this as an early guard (before rarity and stat processing). If invalid, abort the craft and return items unchanged.
- Prefer a robust check that does not rely on tooltip text. Options:
  - **Socket-content check**: enumerate socketed rune items on the weapon (if any present → reject).
  - **Rune-effect check**: inspect the weapon’s generated stats/properties for rune-origin boosts/skills and reject if found.

## Step 1: Create a deterministic “forge” crafting recipe
Goal: trigger your logic reliably and preserve slot ordering.

Recommended:
- Create a recipe that requires **exactly two weapons** (or a strict weapon-tag filter).
- Recipe output should be a **dummy token item** (e.g. `FORGE_ResultToken`) that Lua deletes/replaces.

Why a token output?
- Crafting outputs are otherwise static; you need a dynamic output based on **slot 1**.
- A token makes it obvious which craft results belong to your system.

Critical validation:
- Confirm whether the engine preserves slot ordering for your recipe callback (slot 1 vs slot 2).
  - If ordering is not stable, introduce a workaround (e.g. a “base selector” catalyst item) and treat that as a must-fix risk before implementing stat logic.

## Step 2: Hook recipe completion and capture GUIDs
Goal: detect “forge craft happened” and capture:
- Crafter character GUID
- Slot 1 ingredient item GUID (base)
- Slot 2 ingredient item GUID (feed)
- Crafted output token GUID

Guidance:
- Filter on your specific recipe/result template/tag so you do not affect normal crafting.
- Pass GUIDs into Lua via the Script Extender bridge.

## Step 3: In Lua, determine base weapon identity (slot 1 hard rule)
Inputs:
- `baseItem` = slot 1 ingredient
- `feedItem` = slot 2 ingredient

Output:
- `baseStatsId` and/or `baseTemplateId` used to spawn the forged item.

Rule:
- The forged item’s innate behaviour comes from `baseItem`’s identity.
- The feed item contributes only rollable modifiers and rarity influence.

## Step 4: Decide rarity (your `rarity_system.md`)
Inputs:
- `rarityA`, `rarityB` (from the parent items)

Outputs:
- `rarityOut`
- `maxAllowed` (your rarity cap, if you keep your cap table)

Notes:
- Unique (ID 8) should follow your “Unique dominance” rule.
- Do not mix in rollable stats yet; just compute rarity/cap.

## Step 5: Extract each parent’s rollable modifiers from the item instance
Goal: build the two modifier lists you will feed into the inheritance algorithm.

You need a normalised representation per modifier, such as:
- `key`: stat identity (e.g. `Intelligence`, `Accuracy`, `LifeSteal`, `StatusSet:BLIND`)
- `value`: magnitude payload (e.g. `+4`, `+10%`, or `{chance=10, turns=1}`)
- `source`: the underlying boost/affix identifier(s) so you can reapply cleanly

### How to classify a tooltip line reliably
Do not rely on colour. Use provenance:
- **Innate**: originates from base stat entry/archetype fields (damage/range/skills/archetype `ExtraProperties`).
- **Rollable**: originates from generated boosts/affixes on the item instance.

Practical classifier:
- If the effect is represented by a `_Boost_*` on the item (or in its generated stats container), treat it as rollable.
- If it only exists in the base stat entry inheritance chain, treat it as innate.

### Status-chance lines are rollable (even though they use `ExtraProperties`)
In vanilla, they are boosts whose **boost definition** carries an `ExtraProperties` payload, e.g.:
- `BLIND,10,1`
- `MUTED,10,1` (Silence family)
- `CRIPPLED,10,1`
- etc.

Normalise them into keys like:
- `StatusSet:BLIND` with value `{chance=10, turns=1}`

### Caveat: re-forging previously forged weapons
If a forged weapon is used as an ingredient in a later forge, **the rollable-stat retrieval logic should be the same** as for any other weapon:
- Extract rollable modifiers from the item instance (boosts/affixes).
- Treat innate/base weapon identity as non-rollable (slot 1 still decides the output base identity).

However, ensure you **exclude any forge metadata/markers** you add for bookkeeping (tags, debug boosts, “forged-by-system” flags, etc.):
- These must not be counted as rollable stats.
- They must not enter shared/pool/cap calculations.

## Step 6: Compute forged rollable modifiers (your `inheritance_system.md`)
Inputs:
- `parentA_rollable[]`
- `parentB_rollable[]`
- `rarityOut` → `maxAllowed`

Outputs:
- `forged_rollable[]` (the list you will apply)

Algorithm (as per your doc):
- Split into `sharedStats` by key and `poolStats` for non-shared.
- Merge values for shared stats where values differ (your merge formula).
- Roll how many pool stats to keep (tiered luck shift).
- Apply cap last; if over cap, remove pool-picked entries first.

Important implementation detail:
- Many vanilla rolls are **tier-based boosts** (Small/Medium/Large) rather than continuous numbers.
  - Decide early whether you:
    - keep continuous merging and map to the nearest tier on apply, or
    - merge by tier index (simpler and closer to vanilla).

## Step 7: Create the forged item (spawn, then replace token)
Recommended:
- Delete the crafted output token item.
- Spawn a new item that matches slot 1’s base identity:
  - same base template/stats entry
  - appropriate level (commonly base item’s level; or define a level rule)
  - set rarity to `rarityOut`

Why spawn instead of mutating the token?
- It ensures innate/base properties are correct by construction.
- It avoids “leftover” generated stats from the token.

## Step 8: Apply rollable modifiers to the forged item
This is the key SE-only step.

Pick one strategy and keep it consistent.

### Strategy A (recommended): apply by boost ids / affixes
- Clear any existing generated boosts on the forged item.
- Apply the exact boost ids corresponding to your computed `forged_rollable[]`.

Pros:
- Matches vanilla structure.
- Tooltip lines should match expectations.

Cons:
- Requires you to manipulate the item’s generated stats container correctly.

### Strategy B: apply as permanent stat changes
- Apply the computed effects directly (attributes, crit chance, life steal, status-chance procs).

Pros:
- Often simpler.

Cons:
- Can diverge from vanilla serialisation and tooltip formatting.
- Harder to keep parity with roll tables.

Recommendation:
- Start with Strategy A; fall back to B only if the API surface blocks you.

## Step 9: Consume parents and deliver result
Decide explicitly whether you mutate-in-place or replace.

Recommended behaviour:
- Destroy both parents.
- Add forged item to the crafter’s inventory (or drop at feet if inventory is full).

## Step 10: Debugging and observability (must-have)
Add a debug toggle (global variable or mod setting) that logs:
- ingredient GUIDs and base stats/template ids
- extracted rollable list per parent (normalised + source boost ids)
- rarity decision output
- final forged rollable list
- confirmation of spawned item and parent deletion

Also add a “dump item” dev command that prints:
- base stats id/template id
- current applied boosts/affixes
- any dynamic/generated stat entries used to drive the tooltip

## Classification quick reference

### Common tooltip lines and classification
| Tooltip line type | Example | Rollable? | Why |
| --- | --- | --- | --- |
| Base damage line | `311–381 Fire` | No | Base stat entry + level scaling |
| Base crit damage | `150% Critical Damage` | No | Weapon archetype field |
| Attribute bonus | `+4 Intelligence` | Yes | Boost/affix |
| Accuracy / crit chance | `+10% Accuracy` | Yes | Boost/affix |
| Life steal | `+14% Life Steal` | Yes | Boost/affix |
| Status-chance proc | `Set Blinded… 20%…` | Yes | Boost; payload encoded via boost `ExtraProperties` |
| Elemental wand/staff surface behaviour | “Creates Ice surface…” / “Ignite;Melt” | No | Archetype `ExtraProperties` (weapon identity) |
| Granted skill | `Staff of Magus` | No | Archetype `Skills` |
| Rune slot lines | “Empty slot” | Yes (separate rule) | Not a blue stat; inherit rune slot count as `ceil((A + B) / 2)` if both parents have empty sockets |

## Example walk-through (slot 1 staff, slot 2 wand)
Slot 1: Fire staff (base identity; keep Ignite/Melt + Staff of Magus)
Slot 2: Water wand (feed; contributes rollable modifiers and rarity influence)

Output:
- Base weapon remains a Fire staff.
- Rarity is calculated from both items.
- Rollable pool is the union of both items’ rollable boosts.
- Staff innate effects remain regardless of roll outcomes.
- Rollable status lines (Blind/Muted/etc.) are candidates if present on either parent.

## Acceptance checklist
- Forge recipe triggers reliably and captures **slot ordering**.
- Output item identity always matches slot 1.
- Innate behaviours (elemental surfaces, granted skills, base damage/range) are preserved automatically.
- Rollable modifiers are:
  - extracted from parents correctly,
  - merged/rolled per your docs,
  - applied so tooltips match expectations.
- Parents are removed; output is delivered.
- Debug mode produces a complete before/after audit for a single forge.

## Known risks (track explicitly)
- Slot ordering may not be stable: validate early.
- Mapping merged continuous values to tiered boosts must be defined.
- Unique items (rarity 8) require special handling per your doc (identity preservation + “fuel” behaviour).

---

## Appendix: Pseudocode reference

This appendix consolidates all forging-related pseudocode in one place.

### Rarity system pseudocode (distribution weights)

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
```

### Stat inheritance pseudocode (doc term mapping + core routine)

#### Name mapping (doc terms → pseudocode variables)

| Doc term | Pseudocode name | Meaning |
| :--- | :--- | :--- |
| Shared stats | `sharedStats` | Stats present on both parents |
| Pool stats | `poolStats` | Stats that are not shared (unique to either parent) |
| Pool size | `poolCount` | How many stats are in the pool |
| Shared count | `sharedCount` | How many shared stats you have |
| Expected baseline | `expectedPoolPicks` | Half the pool, rounded up |
| Luck adjustment | `luckShift` | Luck adding/removing pool picks (can chain) |
| Max stat slots | `maxAllowed` | Max stat slots allowed by rarity |

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

### Granted skills pseudocode (skills channel plug-in)

```python
# GRANTED SKILLS (SEPARATE CHANNEL, VANILLA-ALIGNED)
# - Identify granted skills by skill ID (from boost definitions with a Skills field).
# - Only include vanilla rarity-roll skill boosts (BoostType == "Legendary").
# - Use seeded randomness per forge so results are stable for that forge.

skillCap = GetSkillCap(rarityId)  # Section 5.2 table

sharedSkills = SharedSkillsById(Item_A.GrantedSkills, Item_B.GrantedSkills)
poolSkills = PoolSkillsById(Item_A.GrantedSkills, Item_B.GrantedSkills)

finalSkills = Dedup(sharedSkills)

# If shared skills exceed cap (rare; typically from previous forging chains), trim seeded.
IF Length(finalSkills) > skillCap:
    finalSkills = TrimToCapSeeded(finalSkills, skillCap, forgeSeed)

freeSlots = skillCap - Length(finalSkills)

# Fill free slots with gated gain rolls (skills are precious).
WHILE (freeSlots > 0 AND Length(poolSkills) > 0):
    P_remaining = Length(poolSkills)
    p_attempt = SkillGainChance(rarityId, P_remaining)  # base(rarity) * m(P_remaining), Section 5.4
    IF RollPercentSeeded(forgeSeed, p_attempt):
        gained = PickOneSeeded(poolSkills, forgeSeed)
        finalSkills.Add(gained)
        poolSkills.Remove(gained)
    freeSlots -= 1

# Optional replace roll (seeded): 5%
IF (Length(poolSkills) > 0 AND Length(finalSkills) > 0 AND RollPercentSeeded(forgeSeed, 5)):
    removed = PickOneSeeded(finalSkills, forgeSeed)
    added = PickOneSeeded(poolSkills, forgeSeed)
    finalSkills.Remove(removed)
    finalSkills.Add(added)

ApplyGrantedSkillsToForgedItem(finalSkills)
```

### Weapon boost inheritance pseudocode

```python
# WEAPON BOOST INHERITANCE (WEAPONS ONLY; SAME `WeaponType` ONLY)
# - Weapon boosts are discrete boost entries (elemental damage, armour-piercing, etc.)
# - Uses a score-and-select model: score all boost kinds (after bias), then keep the largest ones under the weapon cap.

def max_boost_slots(weapon_type_out: str) -> int:
    # Vanilla-aligned caps:
    # - Wands: 0
    # - Staffs: 1
    # - Other weapons: 2
    if weapon_type_out == "Wand":
        return 0
    if weapon_type_out == "Staff":
        return 1
    return 2

def tier_name_to_score(tier_name: str) -> int:
    # Universal scale:
    # None=0, Small=1, Untiered=2, Medium=3, Large=4
    if tier_name == "None":
        return 0
    if tier_name == "Small":
        return 1
    if tier_name == "Untiered":
        return 2
    if tier_name == "Medium":
        return 3
    if tier_name == "Large":
        return 4
    raise ValueError("unknown tier")

def round_half_up(x: float) -> int:
    return int(floor(x + 0.5))

def score_to_tier_name_clamped(boost_kind: str, score: float) -> str:
    # Convert numeric score -> tier name (then clamp to tiers that exist for that boost kind).
    t = max(0, min(4, round_half_up(score)))
    if t == 0:
        return "None"
    if t == 1:
        tier = "Small"
    elif t == 2:
        tier = "Untiered"
    elif t == 3:
        tier = "Medium"
    else:
        tier = "Large"

    # Clamp for special boost kinds (examples; implement with a lookup table):
    # - 3-tier boosts (no Small): Small -> Untiered
    # - 1-tier boosts (only Untiered): any -> Untiered
    if boost_kind in ["Vampiric", "MagicArmourRefill"]:
        if tier == "Small":
            tier = "Untiered"
    if boost_kind in ["Chill"]:
        tier = "Untiered"
    return tier

def weapon_boost_inheritance(slot1_item, slot2_item, forgeSeed):
    weapon_type_out = slot1_item.weapon_type  # slot 1 identity rule
    cap = max_boost_slots(weapon_type_out)
    if cap == 0:
        return []

    # Same `WeaponType` only
    TypeMatch = (slot1_item.weapon_type == slot2_item.weapon_type)
    if not TypeMatch:
        return []

    # Parse + filter boost lists; clamp list length to cap (keep first cap entries)
    list1 = ParseBoosts(slot1_item.boosts)  # split by ';'
    list2 = ParseBoosts(slot2_item.boosts)
    list1 = FilterOutDamageBoostBonus(list1)
    list2 = FilterOutDamageBoostBonus(list2)
    list1 = list1[:cap]
    list2 = list2[:cap]

    # Build per-kind inputs (score 0..4 per parent, after tier parsing)
    kinds = UnionBoostKinds(list1, list2)
    s_main = {}  # kind -> score (0..4)
    s_sec = {}
    sec_index = {}  # kind -> earliest index in secondary list (tie-break)
    for k in kinds:
        s_main[k] = TierScoreForKind(list1, k)  # 0 if absent
        s_sec[k] = TierScoreForKind(list2, k)
        sec_index[k] = EarliestIndexOfKind(list2, k)  # None if absent

    # Step: compute scores AFTER bias
    score = {}
    for k in kinds:
        base = 0.6 * s_main[k] + 0.4 * s_sec[k]
        bias = RollUniformSeeded(forgeSeed, 0.0, 0.7)  # one roll per kind
        score[k] = clamp(base + bias, 0.0, 4.0)

    picked = []

    # Primary pick: score >= 1
    c1 = [k for k in kinds if score[k] >= 1.0]
    c1.sort(key=lambda k: (
        -score[k],
        -s_main[k],                         # main-slot dominance
        # Only use secondary list order to break ties when the kind is secondary-only (doc rule).
        (sec_index[k] if (s_main[k] == 0 and sec_index[k] is not None) else 9999),
    ))
    picked.extend(c1[:cap])

    # Fallback fill: only if cap not filled AND all remaining scores are < 1
    if len(picked) < cap:
        remaining = [k for k in kinds if k not in picked]
        if remaining and max([score[k] for k in remaining], default=0.0) < 1.0:
            # fillScore = 1 + score/2 (only here)
            c2 = [k for k in remaining if 0.0 < score[k] < 1.0]
            c2.sort(key=lambda k: (
                -(1.0 + score[k] / 2.0),
                -s_main[k],
                (sec_index[k] if (s_main[k] == 0 and sec_index[k] is not None) else 9999),
            ))
            needed = cap - len(picked)
            picked.extend(c2[:needed])

    # Convert selected kinds back to concrete boosts
    out = []
    for k in picked:
        tier_name = score_to_tier_name_clamped(k, score[k] if score[k] >= 1.0 else (1.0 + score[k] / 2.0))
        if tier_name == "None":
            continue
        out.append(MakeBoostName(k, tier_name))

    return out
```

