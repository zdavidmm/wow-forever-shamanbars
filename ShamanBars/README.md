# ShamanBars 1.1.0 - WoW Forever 1.60.1

A manual layout installer for the default Blizzard action bars. It does not cast
spells, run on login, or queue changes for leaving combat.

## What was corrected

The old version assumed the Shift bar was MultiBarBottomLeft (normally slots
61-72). The affected setup already used that bar for utility and bound Shift+1-6
to **MultiBar7**, normally slots **169-180**. Those are different bars even when
Edit Mode puts them next to each other. MainActionBar is the bottom combat bar.

The corrected version reads each button's secure `CalculateAction()` result,
checks its cached slot, owning frame and binding command, and refuses ambiguous
mapping, paging, overrides, hidden bars or multirow/reversed layouts. It does not
blindly assume the example slot numbers above.

The old version also left numeric keys as primary hotkeys, skipped some occupied
targets and relied on spellbook iteration order. This version sets the requested
primary keys, preserves secondary shortcuts where possible, selects the highest
learned rank deterministically and preserves unrelated target actions by moving
them only into verified empty visible utility buttons.

## Install and recover from 1.0.x

Keep both your pre-install and current-state backups. Do not copy actual WTF,
SavedVariables, diagnostics, screenshots or backups into the source repository.

1. Copy the `ShamanBars` folder into the Forever client's
   `_forever_\Interface\AddOns` directory. Do not copy the repository root.
2. Restart the client, or `/reload` if ShamanBars is already loaded. Enable
   **ShamanBars - Enhancement Leveling Setup** in the AddOns list if necessary.
3. Use the default main bar on page 1. Keep **MultiBar7 / Action Bar 8** enabled,
   with at least ten buttons in one left-to-right horizontal row. The intended
   Shift bar is not selected by its apparent screen row.
4. When upgrading an already-applied 1.0.x configuration, outside combat and with
   an empty cursor, run:

```text
/shamanbars restore
/reload
```

Legacy recovery restores only the original spell slots and keys that the old
snapshot actually captured. It preserves an original archive and refuses unsafe
replacements. The old snapshot cannot reconstruct primary-key order it did not
record. Do not replace it with a new snapshot of the broken bars.

5. Prepare the corrected layout:

```text
/shamanbars debug
/shamanbars preview
/shamanbars prepare
/reload
/shamanbars preview
/shamanbars apply
/shamanbars debug
/reload
```

Read both previews. The explicit reload after **prepare** persists the original
snapshot before server-stored actions are changed. Nothing applies on reload.
Calling apply without a prepared backup only prepares one; calling it again in
that same UI session refuses changes until the backup has been saved by reload.

## Exact layout

| Main key | Ability |
| --- | --- |
| 1 | Auto Attack |
| 2 | Flame Shock |
| 3 | Lightning Bolt |
| 4 | Frost Shock |
| 5 | Fire Nova / learned client variant |
| Q | Earth Shock |
| E | Lesser Healing Wave |
| R | Ghost Wolf |
| F | Searing Totem |
| G | Purge |

| Secondary key | Ability |
| --- | --- |
| Shift+1 | Strength of Earth Totem |
| Shift+2 | Searing Totem |
| Shift+3 | Earthbind Totem |
| Shift+4 | Stoneclaw Totem |
| Shift+5 | Healing Stream Totem |
| Shift+6 | Tremor Totem |
| Shift+Q | Lightning Shield |
| Shift+E | Healing Wave |
| Shift+R | Weapon imbue: Windfury when learned, otherwise Rockbiter, then Flametongue |
| Shift+F | Stoneskin Totem |

Searing Totem on **F** and **Shift+2** is intentional. Stormstrike does not replace
Fire Nova. Unlearned abilities leave their original position and bindings alone;
other spells never shift to fill a gap. Family anchor IDs resolve client-localized
names; only learned, active spellbook entries are picked up. Future, passive and
off-spec entries are excluded. Rank choice does not depend on book traversal order.

## Safety and rollback

- Only the first ten actual MainActionBar and MultiBar7 buttons are layout
  targets. Buttons 11-12, hidden pages, professions and consumable bars are not
  swept or cleared. Pre-existing shortcuts outside the managed layout remain.
- If an unrelated spell, item or macro occupies a target, preview names its move
  to an **empty, visible** MultiBarBottomLeft/BottomRight utility button. The move
  is backed up and reversed by restore. An occupied utility destination is never
  overwritten. With insufficient space, prepare refuses the entire plan.
- Requested keys become the displayed primary bindings. Existing secondary keys
  are retained unless they are another requested layout key. Other affected
  command bindings are snapshotted with their original order. Movement/UI keys
  can change intentionally; read preview. Account-wide bindings are never saved.
- Mapping, relocation destinations and bindings are rechecked before writes.
  Stale mappings, new uncaptured shortcuts and addon override keys cause refusal.
- Reapplying an unchanged layout performs no pickups or binding writes. API errors
  stop the operation and attempt immediate rollback only outside combat. If combat
  starts, nothing is queued; leave combat and restore manually.
- `ShamanBarsBackup` stores the active per-character snapshot.
  `ShamanBarsOriginalBackup` retains an original archive without replacing it.
  Do not remove these SavedVariables or uninstall before recovery.

To undo the corrected layout:

```text
/shamanbars restore
/reload
```

Restore recovers original spell/empty slots, relocated utility actions and the
captured binding order. It refuses to overwrite unrelated later replacements or
stale destinations. A prior spell that is no longer learned requires manual review.
Bindings remain character-specific after restore. A whole-WTF restore can rewind
unrelated settings and does not reliably recover server-stored action bars.

## Diagnostics and verification

`/shamanbars debug` prints visible bar names, button-to-slot mappings, actual
spell IDs, binding commands and primary/secondary keys. It also reports selected
learned spell IDs/ranks/book indices and stores local `ShamanBarsDiagnostics` at
the next reload. It does not move actions or bind keys. Do not publish that file.

`/shamanbars preview` shows exact current/desired spell IDs, real button names and
slots, any utility moves, and affected binding order. It changes no configuration
or backups. Resolve warnings before prepare/apply.

Compatibility is checked against the public UI source for **1.60.1 (70938)**:
https://github.com/Gethe/wow-ui-source/commit/bebcb6bf309cf41b41bd74f8ca651e6a105b2676

Lua syntax, API-name checks and mocked tests do not prove the live layout works.
Inspect debug and the actual buttons after applying; do not describe this as
live-verified unless those in-game checks were actually performed.
