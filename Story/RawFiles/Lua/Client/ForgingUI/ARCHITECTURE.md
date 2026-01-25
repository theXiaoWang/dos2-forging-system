# Forging UI Architecture

Goal: keep the Forging System UI easy to extend while staying **standalone** (no EpipEncounters install required).

## Module boundaries

- `Config/` – **tuning knobs** and UI constants. Intended to be edited often during UI iteration.
- `State/` – runtime state containers (no UI element creation).
- `Backend/` – pure logic/services (filtering, sorting, validation). Should not touch GenericUI elements.
- `UI/` – UI builders and widget wrappers (creates elements and wires events; should stay mostly "dumb").
- `Input/` – RawInput, shortcuts, focus/blur behaviors.

## Compatibility strategy

For safety, legacy entry files (e.g. `Main.lua`, `Layout.lua`, `Widgets.lua`) are kept as thin wrappers while functionality is migrated into the folders above. This avoids breaking `Ext.Require(...)` paths while refactoring.

