# Epip Migration Rules

Use this when any Epip asset or code is referenced by the Forging System mod.
Goal: keep the mod self-contained (no Epip dependency) and make future updates predictable.

## When To Migrate
- If a UI texture, icon, panel, or sliced asset is used by Forge UI, copy it into this mod.
- If a utility/module from Epip is required at runtime, copy only the minimal subset needed.
- Do not reference Epip globals or expect Epip to be installed.

## Assets (Textures, Panels, Sliced)
1) Copy the asset files into this mod's `Public` assets folder (use a clear Epip-derived subfolder).
2) Register the asset in the local texture registry used by Forge UI (do not edit Epip tables).
3) Keep asset names stable; prefer names that match Epip's original identifiers.
4) If the asset is sliced, copy all required data (atlas + slice metadata).
5) Update any in-mod index mappings or lookup helpers so indices resolve to the new local names.

## Code (UI Framework, Helpers)
1) Copy only the modules you use; do not copy unused files.
2) Re-namespace all migrated code to this mod (no `Epip.*` references).
3) Add a short header comment in migrated files:
   - Source path, original mod name, and date migrated.
4) Avoid hard-coding Epip-specific paths, globals, or console commands.

## Updating / Adding New Assets
1) Add the asset files to this mod.
2) Add/extend a local registry entry (name -> asset ID).
3) If an index-based test UI exists, update it to include the new entries.
4) Validate in game: open Forge UI and confirm the asset renders correctly.

## Removing Assets
1) Remove only after confirming no code references remain.
2) Keep a short note in the commit or changelog if removing shared assets.

## Sanity Checks
- Forge UI works with Epip disabled/uninstalled.
- No Epip global access errors in console.
- All referenced assets exist under this mod.
