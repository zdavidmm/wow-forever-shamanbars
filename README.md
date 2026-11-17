# WoW Forever ShamanBars

A manual action-bar and keybinding setup addon for an Enhancement Shaman in
**WoW Forever 1.60.1**, interface **16001**. The initial layout targets leveling,
skips unlearned spells, and supports learning Stormstrike later.

The addon is ready to preview in-game. Lua 5.1 syntax and mocked behavior have
been tested; **no live in-game testing has been performed**.

## Install and use

1. Exit WoW and back up your Forever client's `WTF` folder.
2. Copy only this repository's `ShamanBars` folder into your Forever client's
   `_forever_\Interface\AddOns` directory. Do not copy the repository root.
3. Restart Forever and enable **ShamanBars - Enhancement Leveling Setup** in the
   character-selection AddOns list.
4. On your Shaman, select main bar page 1, leave combat and empty your cursor.
   Enable Action Bar 2 in Options > Action Bars if hidden.
5. Preview before applying:

```text
/shamanbars preview
/shamanbars apply
/reload
```

Only slots **1-10** and **61-70** are considered. Items, macros, professions and
unrelated spells are protected, including in those slots. Requested keys can
replace existing movement/UI bindings; read preview before applying.

Nothing applies on login, reload, learning spells or leaving combat. After
learning Stormstrike, preview/apply again: key **5** upgrades while Auto Attack
remains on **1**.

Undo on the same character, with the addon enabled and outside combat:

```text
/shamanbars restore
/reload
```

The first pre-apply slot/key snapshot is retained across repeated applies and
saved per character at reload/logout. A crash before that save can lose the
snapshot. Restore preserves items, macros and unrelated spells placed later and
reports skips. Bindings remain character-specific. Action bars are server-stored,
so a disk-only WTF backup cannot guarantee bar recovery.

See [the addon README](ShamanBars/README.md) for the full layout, safeguards,
recovery details and troubleshooting. Spell matching expects an English client.

## Development

Requires Python 3.10 or later. No Python dependencies are required inside WoW.

On Windows, from the repository root:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe -m tools.validate
```

The validator checks TOC references and Lua 5.1 syntax, then runs 34 mocked
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
succeed. GitHub Actions runs syntax, mocked behavior and API-name checks on both
Windows and Linux.

## Repository layout

- `ShamanBars`: the installable addon; keep the folder name and TOC aligned.
- `tests`: simulated WoW API and behavior tests, not character/account data.
- `tools`: portable validation runner using Lupa's Lua 5.1 runtime.
- `.github`: CI and Copilot contributor instructions.
- `AGENTS.md`: shared guidance for AI contributors.

This repository must not contain a WoW client, WTF/SavedVariables, account data,
screenshots, logs, local backups or credentials. Keep your game configuration and
recovery copies outside version control.
