# WoW Forever ShamanBars

A manual action-bar and keybinding setup addon for an Enhancement Shaman in
**WoW Forever 1.60.1**, interface **16001**. The layout targets leveling, skips
unlearned spells and uses the highest learned rank without assuming book order.

> **Status: experimental; live application verification pending.** Version 1.1.1 passes
> Lua 5.1 syntax checks and 56 mocked behavior tests, but these do not prove the
> live layout works. Earlier 1.0.x versions misplaced actions; preserve your
> original snapshot and follow the recovery instructions before applying.

## Install and use

1. Exit WoW and back up your Forever client's `WTF` folder.
2. Copy only this repository's `ShamanBars` folder into your Forever client's
   `_forever_\Interface\AddOns` directory. Do not copy the repository root.
3. Restart Forever and enable **ShamanBars - Enhancement Leveling Setup** in the
   character-selection AddOns list.
4. On your Shaman, select main bar page 1, leave combat and empty your cursor.
   Keep the existing Shift bar, **MultiBar7 / Action Bar 8**, enabled.
5. If upgrading from 1.0.x, first run `/shamanbars restore`, then `/reload`.
   This recovers the old snapshot, including utility slots that version targeted.
6. Preview, prepare a durable backup, reload to save it, and deliberately apply:

```text
/shamanbars preview
/shamanbars prepare
/reload
/shamanbars preview
/shamanbars apply
/shamanbars debug
/reload
```

Slots are resolved from actual visible **MainActionBar** and **MultiBar7**
buttons, not screen row numbers. In the verified default UI these are 1-10 and
169-178, not 61-70. Other bars are preserved. An unrelated action occupying a
target is moved only to a snapshotted, empty, visible utility button. Preview
shows each relocation; without sufficient space, the entire plan is refused.
If needed, enable an empty **Action Bar 6 (MultiBar5)** in Options > Action Bars
before preparing. Only empty buttons on enabled, actually visible default utility
bars can be used; ShamanBars never enables bars or changes their positions itself.
Requested keys become primary displayed hotkeys; secondary shortcuts are retained
where possible. Review changes to movement/UI bindings before applying.

Nothing applies on login, reload, learning spells or leaving combat. Reapplying
an unchanged layout performs no pickups or binding writes. Auto Attack remains
on **1** and Fire Nova on **5**; Stormstrike does not silently replace it.

Undo on the same character, with the addon enabled and outside combat:

```text
/shamanbars restore
/reload
```

The prepared snapshot must be saved by reload **before** first apply. It retains
the original actions, utility relocations and binding order across repeated
applies. Restore refuses unrelated replacements or stale mappings instead of
overwriting them. Bindings remain character-specific. Version-1 recovery can only
restore what that older snapshot recorded, not missing primary-key order.
Action bars are server-stored, so WTF alone cannot guarantee bar recovery.

See [the addon README](ShamanBars/README.md) for the full layout, safeguards,
recovery details and troubleshooting. `/shamanbars debug` reports actual visible
button slots, spell IDs, learned selections and binding order, and saves local
diagnostics at the next reload. Do not upload character SavedVariables.

## Development

Requires Python 3.10 or later. No Python dependencies are required inside WoW.

On Windows, from the repository root:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe -m tools.validate
```

The validator checks TOC references and Lua 5.1 syntax, then runs 56 mocked
behavior tests covering manual invocation, combat refusal, protected slots,
unlearned spells, action placement verification, keybindings and rollback.
The default validation is offline after dependencies are installed.

To additionally check namespaced APIs against the public UI source for the
exact validated Forever build, with network access:

```powershell
.\.venv\Scripts\python.exe -m tools.validate --check-apis
```

API reference: [Forever 1.60.1 (70938), pinned UI source commit](https://github.com/Gethe/wow-ui-source/commit/bebcb6bf309cf41b41bd74f8ca651e6a105b2676).
API-name checks do not replace in-game validation or prove protected calls will
succeed.

`ci\validate.yml` is an **inactive GitHub Actions template** for Windows and Linux.
To enable it, copy it to `.github\workflows\validate.yml` and push using GitHub
credentials with permission to create workflows. It is not active because the
credential used for the initial upload does not have the `workflow` OAuth scope.
Local validation is fully available without that permission.

## Repository layout

- `ShamanBars`: the installable addon; keep the folder name and TOC aligned.
- `tests`: simulated WoW API and behavior tests, not character/account data.
- `tools`: portable validation runner using Lupa's Lua 5.1 runtime.
- `.github`: Copilot contributor instructions.
- `ci`: the inactive cross-platform validation workflow template.
- `AGENTS.md`: shared guidance for AI contributors.

This repository must not contain a WoW client, WTF/SavedVariables, account data,
screenshots, logs, local backups or credentials. Keep your game configuration and
recovery copies outside version control.
