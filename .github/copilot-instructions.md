# Copilot instructions

Read `AGENTS.md`, `README.md`, and `ShamanBars\README.md` before changing behavior.
Keep the documented layout synchronized with layout changes; change TOC metadata
only when warranted.

## Scope and architecture

ShamanBars targets **WoW Forever 1.60.1, interface 16001**, using Lua 5.1 and the
default Blizzard action bars. Spell-name matching expects an English client.

Only `ShamanBars` is installed into WoW. Its TOC loads `ShamanBars.lua` and declares
`ShamanBarsBackup` as a per-character SavedVariable. Python, tests, and validation
dependencies stay outside the installed addon.

The addon is a single Lua module with local helpers. Loading it only registers
`/shamanbars` and `/sbars`; slash-command dispatch invokes preview, apply, or
restore. The empty command previews. There are no event-driven configuration
changes.

`PLAN` couples each managed slot to its key, Blizzard binding command, and ordered
spell-name fallbacks. `MANAGED_NAMES` is derived from all those names.
`findKnownSpells()` scans the player spellbook to resolve learned active entries
and their spell/base IDs. Preview and apply share spell selection and slot
protection; apply snapshots a slot before placement and binds its key only after
placement verification.

The version-1 backup stores original spell IDs in `slots` and original binding
commands in `keys`. A slot value of `0` means originally empty; a key value of
`""` means originally unbound; `nil` means no pending snapshot entry. Repeated
applies retain the first snapshot for each entry. Restore removes entries only
after success, retaining skipped/failed work for retry and clearing the backup
only when both tables are empty. SavedVariables persist at reload/logout;
action bars are server-stored, so a disk-only WTF backup is not full bar recovery.

## Non-negotiable behavior

- Configuration writes require deliberate slash commands. Never add login,
  timer, spell-learning, combat, or deferred-combat application.
- Refuse unsafe contexts: non-Shaman, combat, occupied cursor, main bar page
  other than 1, or remapped bars. Stop if combat starts during an operation;
  never queue a retry.
- Manage only slots **1-10 and 61-70**. Replace only empty slots or currently
  learned managed spells. Preserve items, macros, professions, unrelated spells,
  other slots, and non-target keys. Restore must protect items, macros, and
  unrelated spells added later, retaining unresolved snapshots.
- Keep Auto Attack on **1**; learned Stormstrike upgrades **5**. Resolve ordered
  fallbacks from learned active spellbook entries, skipping unknown, future,
  passive, and off-spec entries. Do not hardcode spell IDs in the production plan.
- Confirm the actual placed action is the requested spell ID or its base ID
  before assigning the key. Pickup/placement/binding failures must not be
  reported as successes.
- Save bindings with `Enum.BindingSet.Character`, never the account binding set.
  Restore leaves bindings character-specific. Preview must remain read-only and
  disclose conflicts with requested keys, including movement/UI bindings.
- Use the Forever APIs and Lua 5.1 syntax. Keep missing-API checks fail-closed and
  mocks aligned with the actual client API.

## Development checks

From the repository root, use Python 3.10+ and the local virtualenv:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe -m tools.validate
.\.venv\Scripts\python.exe -m tools.validate --check-apis
git diff --check
```

Reuse an existing environment when available. `requirements-dev.txt` pins Lupa;
the validator explicitly uses `lupa.lua51`, not Lupa's default Lua runtime.
Default validation is offline after setup: it checks TOC references, interface,
backup metadata, addon nesting, Lua syntax, and the mocked behavior suite.
`--check-apis` additionally requires network access and checks names in
`C_SpellBook`, `C_Spell`, and `C_ActionBar` against the pinned public UI source for
Forever build 70938 (`UI_COMMIT` in `tools\validate.py`). CI runs this check on
Windows and Linux with Python 3.10, followed by `git diff --check`.
`.gitattributes` specifies LF for source, metadata, and documentation.

The suite is small; run the whole harness rather than modifying it to select
individual tests.

Behavior tests use `world()` to load the real addon into an isolated Lua 5.1
environment via `loadstring`/`setfenv`. Exercise commands through `s.command()`;
use the mock world's actions, bindings, write log, failure switches, and
`s.env.ShamanBarsBackup` to check outcomes. Add focused cases for changed behavior
in the existing harness. Synthetic spell IDs belong in mocks, not the layout.

Static syntax, API-name checks, and mocked behavior are not live in-game
validation and do not prove protected calls will succeed. Distinguish these
checks from actual in-game testing in reports.

## Privacy and deployment

Never commit a WoW client, WTF/SavedVariables, bindings/macros caches, account or
character identifiers, logs, screenshots, local backup archives, or credentials.
Do not install into a user's game, edit live settings, or apply bars unless
explicitly requested. Preserve existing authorship; do not invent licensing.
