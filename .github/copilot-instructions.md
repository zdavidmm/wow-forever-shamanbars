# Copilot instructions

Read `AGENTS.md`, `README.md`, and `ShamanBars\README.md` before changing behavior.
Keep the documented layout synchronized with layout changes; change TOC metadata
only when warranted.

## Scope and architecture

ShamanBars targets **WoW Forever 1.60.1, interface 16001**, using Lua 5.1 and the
default Blizzard action bars. Family IDs resolve localized names from the client;
placement uses learned spellbook entries and deterministic highest-rank selection.

Only `ShamanBars` is installed into WoW. Its TOC loads `ShamanBars.lua` and declares
the active backup, original archive and diagnostics as per-character
SavedVariables. Python, tests, and validation dependencies stay outside the addon.

The addon is a single Lua module with local helpers. Loading it only registers
`/shamanbars` and `/sbars`; commands include preview, prepare, apply, restore and
debug. The empty command previews. No login, event or reload applies a layout.

`PLAN` describes logical buttons, keys and spell-family fallbacks, not fixed slots.
`resolve()` uses the real MainActionBar and MultiBar7 button CalculateAction,
cached action, owning bar and binding command. Utility bars at 61-72 must not be
mistaken for this character's existing Shift bar (normally MultiBar7 at 169-180).
Never replace runtime resolution with those example numbers.

Version-2 snapshots store resolved entries, original action descriptors, any
relocation into an empty visible utility slot, and original affected binding
groups including primary/secondary key order. Prepare writes only the snapshot;
an explicit reload is required before apply can mutate anything. Keep originals
across reapplication. Version-1 snapshots recover their old absolute slots and
recorded keys, retain an original archive and warn that primary key order was not
captured. Action bars are server-stored; WTF alone is not reliable bar recovery.

## Non-negotiable behavior

- Configuration writes require deliberate slash commands. Never add login,
  timer, spell-learning, combat, or deferred-combat application.
- Refuse unsafe contexts: non-Shaman, combat, occupied cursor, main bar page
  other than 1, or remapped bars. Stop if combat starts during an operation;
  never queue a retry.
- Manage only the resolved first ten MainActionBar and MultiBar7 buttons and
  explicitly snapshotted moves to empty visible utility buttons. Never sweep
  unrelated bars to remove pre-existing duplicates. Refuse stale or occupied
  relocation destinations before any writes.
- Keep the exact documented keys: Auto Attack 1, Fire Nova 5, Searing Totem F and
  Shift-2, Tremor Totem Shift-6. Skip unknown/future/passive/off-spec spells
  without shifting positions or changing their keys.
- Confirm the actual placed action is the requested spell ID or its base ID
  before assigning the key. Pickup/placement/binding failures must not be
  reported as successes.
- Save bindings with `Enum.BindingSet.Character`, never the account binding set.
  Restore leaves bindings character-specific. Preview is read-only and shows
  actual slots, current/desired spell IDs, relocations and binding order changes.
  Debug records only local diagnostics; never commit actual diagnostic snapshots.
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
Forever build 70938 (`UI_COMMIT` in `tools\validate.py`). `ci\validate.yml` is an
inactive workflow template for Windows and Linux with Python 3.10. It must be
copied into `.github\workflows` and uploaded with a workflow-authorized credential
before GitHub Actions can run it. Do not report the template as active CI.
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
