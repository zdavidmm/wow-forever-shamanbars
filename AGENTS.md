# Contributor instructions

## Scope and structure

This repository contains ShamanBars for WoW Forever 1.60.1 (interface 16001),
not Retail, Classic Era, or a full WoW installation.

- `ShamanBars/ShamanBars.lua`: layout, learned-spell discovery, preview/apply/restore.
- `ShamanBars/ShamanBars.toc`: loader metadata and per-character backup declaration.
- `ShamanBars/README.md`: in-game usage and complete layout.
- `tools/validate.py` and `tests/test_shamanbars.lua`: Lua 5.1 validation and WoW mocks.

## Non-negotiable behavior

- Configuration changes must be deliberate slash commands, never login/event,
  timer, spell-learning, combat, or deferred-combat automation.
- Refuse writes during combat or with an occupied cursor. Use the default
  Blizzard main bar on page 1; do not silently remap other UI addons.
- Manage only slots 1-10 and 61-70. Preserve consumables, professions, macros,
  unrelated spells, unrelated slots and non-target keys.
- Use learned active spellbook entries; skip future, unknown, passive and
  off-spec spells. Do not insert hardcoded spell IDs into the production layout.
- Keep Auto Attack on 1. Stormstrike upgrades 5 only when learned.
- Verify the actual placed spell ID before assigning its key.
- Save bindings character-specifically. Preserve the first pre-apply snapshot
  across repeated applies and keep restore conservative and recoverable.
- Use Lua 5.1-compatible syntax and the Forever APIs, not generic Retail guesses.

## Development checks

Use Python 3.10+ and install `requirements-dev.txt` into a local virtualenv.
No development dependency belongs in the installed addon.

Windows:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe -m tools.validate
.\.venv\Scripts\python.exe -m tools.validate --check-apis
git diff --check
```

On other platforms, use the virtualenv's Python with the same `-m tools.validate`
commands. The optional `--check-apis` check requires network access and uses a
pinned public source commit for build 70938. Add focused behavior tests when
changing addon behavior; keep the mock API aligned with the actual client API.

Read both READMEs and relevant source before editing. Keep Lua style consistent
with the existing file. Update the documented layout and TOC only as warranted.
Distinguish static/mocked checks from actual in-game testing in every report.

## Privacy and deployment

Never commit a WoW client, WTF, SavedVariables, bindings/macros caches, account or
character identifiers, logs, screenshots, local backup archives or credentials.
Do not install into a user's game, edit live settings or apply bars unless the
user explicitly requests that operation. Do not claim tests were run in-game
unless they actually were. Preserve existing authorship; do not invent licensing.
