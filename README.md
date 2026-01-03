# Forging System Mod

A comprehensive item (Weapon/Shield) forging system for Divinity: Original Sin 2 that implements a probability-based rarity inheritance system.

## Overview

This mod adds a sophisticated forging system that allows players to combine items with a balanced probability distribution system. The system prevents exploitation while maintaining the excitement of crafting through two main mechanisms:

- **Gravity Well (Different Rarity)**: When combining items of different rarity, the resulting rarity is pulled towards the average (with higher odds of landing near the middle rather than always upgrading).
- **Rarity Break (Same Rarity)**: When combining items of the same rarity, there is a chance to ascend to the next rarity (a “breakthrough” outcome).
- **Merging rule (shared stat values)**: If a shared stat exists on both items but with different numbers (e.g. `+10%` vs `+14%`), the new item rolls a merged value using a tight/wide RNG model.
- **Selection rule (shared vs pool stats)**: Stats that appear on both items are treated as shared (kept), while non-overlapping stats form a pool that is rolled from (risk/reward).
- **Rarity cap clean-up**: After inheritance, if the stat count exceeds the rarity’s max stat slots, excess stats are removed (pool-derived stats first).

## Mod Information

- **Mod UUID**: `d581d214-2dd4-4690-bb44-e371432f1bfc`
- **Mod Name**: `forging_system`
- **Type**: Add-on
- **Dependencies**:
  - Divinity: Original Sin 2 (Base Game)
  - Game Master

## Documentation

### System Documentation

See `Story/RawFiles/Docs/` for detailed system documentation:

- [`rarity_system.md`](Story/RawFiles/Docs/rarity_system.md) – Rarity inheritance and stability system specification
- [`forging_system.md`](Story/RawFiles/Docs/forging_system.md) – Inheritance rules (stats + granted skills)

### Functional Summary: Stat Inheritance System (v3.0)

#### 1. Core Philosophy
The system balances **predictability** (Safe Forging) with **volatility** (YOLO Forging) to create a thrilling RPG forging experience.

- **Safe Forging**: Combining items with matching stats allows players to "lock in" desired stats and merge numeric values safely.
- **YOLO Forging**: Combining mismatched items creates a large "Pool" of potential stats, introducing high variance where players might lose stats or hit a "Jackpot."

---

#### 2. The Forging Process (3-Step Flow)

##### Step 1: Rarity First (The Container)
Before stats are calculated, the **[Rarity System](Story/RawFiles/Docs/rarity_system.md)** determines the item's tier. This sets the **Max Stat Slots** (Cap), which serves as the hard limit for the item.

| Rarity | Common | Uncommon | Rare | Epic | Legendary | Divine | Unique |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Cap** | 1 | 4 | 5 | 6 | 7 | 8 | 10 |

##### Step 2: Stats Second (The Content)
The system sorts all stats from the parent items into two buckets: **Shared Stats** (guaranteed) and **Pool Stats** (gambled). For the full rules, see **[Forging System](Story/RawFiles/Docs/forging_system.md)**.

##### Step 3: Cap Last (The Cleanup)
If the total number of inherited stats exceeds the **Max Stat Slots** defined in Step 1, the system removes excess stats, strictly prioritising the removal of **Pool Stats** first to protect the **Shared Stats**.

---

#### 3. Inheritance Mechanics

##### A. Shared Stats (Guaranteed & Merged)

**Definition**: Stats present on **both** parents (matching stat key).
- **Outcome**: These are **100% guaranteed** to transfer to the new item.
- **Value merging**: If the numeric values differ (e.g. `+10%` vs `+14%`), the system calculates a new value based on the midpoint:
  - **Tight roll (50% chance)**: the value fluctuates slightly.
  - **Wide roll (50% chance)**: the value fluctuates significantly, allowing for higher highs or lower lows.

##### B. Pool Stats (The Dynamic Slope)

**Definition**: Stats unique to **one** parent. These are combined into a volatile pool.
- **Baseline**: You effectively start by keeping **half** of the pool (rounded up).
- **The luck chain**: The system rolls to adjust this baseline up or down.
  - **Tiers**: The pool size determines the risk profile (Tier 1–4). Larger pools allow for longer "chains" of good or bad luck.
  - **Chaining**: A "good" or "bad" roll triggers a recursive check.
    - **Ascension chain**: Successfully rolling "good" repeatedly adds more stats (Jackpot).
    - **Descension chain**: Rolling "bad" repeatedly removes stats (Collapse).

| Pool Size | Tier Name | Risk Profile |
| :--- | :--- | :--- |
| **1** | **Tier 1 (Safe)** | No chains. High stability. |
| **2–4** | **Tier 2 (Early)** | Low chain chance. |
| **5–7** | **Tier 3 (Mid)** | Moderate chain chance (30% Up / 28% Down). |
| **8+** | **Tier 4 (Risky)** | High chain chance (30% Up / 45% Down). |

---

#### 4. Final Calculation
1. **Calculate total**: `Shared Stats` + `Kept Pool Stats`.
2. **Apply cap**: compare total against **Max Stat Slots**.
3. **Result**: if `Total > Cap`, delete pool stats until the count matches the cap.

## Contributing

When contributing:

1. Only commit source files (`.lsx`, `.lsf`, `.txt`, `.md`)
2. Do not commit binary files (`.data`, `.bin`, `.lsb`)
3. Update documentation when adding new features
4. Test changes in-game before committing
5. Follow the existing code style and structure

### Setting Up for Development

See `SETUP_GITHUB.md` for instructions on setting up the GitHub repository and development workflow.

## License

[Specify your license here]

## Credits

[Add credits/attribution here]

