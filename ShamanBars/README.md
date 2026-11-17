# ShamanBars — WoW Forever Enhancement Shaman action bar installer

A small **one-time setup addon** for the WoW Forever 1.60.1 client (interface 16001).
This is intended for the default Blizzard action bars, not ElvUI/Bartender/Dominos bar remappings.

## Install

1. Fully exit WoW. Make a copy of `World of Warcraft\\_forever_\\WTF` as a backup **before** any action-bar changes. Backing up after applying is too late.
2. Extract the ZIP and copy its **ShamanBars** folder into `World of Warcraft\\_forever_\\Interface\\AddOns\\`.
3. Restart WoW Forever; enable **ShamanBars - Enhancement Leveling Setup** in the AddOns list on the character selection screen.
4. Log into your Shaman, leave combat, and type `/shamanbars preview`.
5. Read the preview. Then type `/shamanbars apply` to place spells **and change keybinds**.
6. Verify the bars, especially Q/E/R/F/G, which may replace existing bindings (including movement keys). If the bar is hidden, enable Action Bar 2 in Options > Action Bars.

## Layout

Main action bar: 1 Auto Attack, 2 Flame Shock, 3 Lightning Bolt, 4 Frost Shock, 5 Stormstrike (or Fire Nova Totem / Fire Nova if learned), Q Earth Shock, E Lesser Healing Wave (or Healing Wave), R Ghost Wolf, F Searing Totem, G Purge.

Bottom-left action bar (Action Bar 2): Shift+1 Strength of Earth, Shift+2 Flametongue Weapon, Shift+3 Earthbind, Shift+4 Stoneclaw, Shift+5 Healing Stream, Shift+G Tremor, Shift+Q Lightning Shield, Shift+E Healing Wave, Shift+R Windfury Weapon (or Rockbiter Weapon), Shift+F Stoneskin.

- **Only** default action bar slots 1–10 and 61–70 are considered. Only empty slots or learned spells named in this layout can be replaced. Items, macros, professions, and unrelated spells are protected even in these slots; move them manually if preview reports a protected slot. Other bar slots, including buttons 11–12 on both bars, are never changed.
- **Missing spells:** skips their slots and keybinds, as well as future, passive, off-spec, and unknown spellbook entries. Learn the spell and rerun preview/apply. After learning **Stormstrike**, rerun to upgrade key 5; Auto Attack stays on key 1.
- **Bindings:** only keys for successfully placed spells are reassigned, to a character-specific binding set. Preview shows conflicting bindings; Q/E and other requested keys can replace movement/UI bindings. Other keys are not deliberately reassigned. Account-wide binding files are not saved.
- **No combat automation:** it only sets up your UI. All spell casts still require player input.
- **Manual only:** logging in, reloading, learning spells, and leaving combat do not apply anything. Both apply and restore refuse combat, an occupied cursor, and a remapped/paged main bar. Select main bar page 1 first.
- **Restore:** `/shamanbars restore` restores the original managed spell slots (including originally empty slots) and the keys this addon attempted to change. Repeated applies keep the first pre-apply snapshot. Restore protects items/macros/unrelated spells added later, so resolve any reported skips manually and retry. Bindings remain character-specific after restoring. Use `/reload` after applying or restoring to save the snapshot/result to disk; until a reload/logout, a client crash can lose the snapshot. Do not remove the addon or its per-character `ShamanBars.lua` SavedVariables file before restoring.
- **Disk backups:** keep the pre-install WTF backup as well. Action bars are server-stored, so a WTF copy alone cannot guarantee action-bar recovery; use the in-game restore command first. Restoring old WTF files with WoW closed can recover local bindings/settings but can also revert later local changes.
- **Compatibility:** interface 16001 and APIs were checked against the public UI source for Forever **1.60.1 (70938)**, commit `bebcb6bf309cf41b41bd74f8ca651e6a105b2676` in `Gethe/wow-ui-source` (`forever` branch). Lua syntax and mocked behavior are validated separately; this is not live in-game testing. Use preview first.

## Troubleshooting

- `/shamanbars` not recognized: check folder nesting. It must be `...\\AddOns\\ShamanBars\\ShamanBars.toc`, not `...\\AddOns\\ShamanBars\\ShamanBars\\...`.
- No spells found: confirm an English client and a Shaman, and that the spellbook loads. Spell matching uses English names.
- Wrong buttons: other action-bar addons may remap action slots. Use the default Blizzard bars for this version.
- Lua error: type `/console scriptErrors 1`, reload, and inspect the error. No automatic retry will occur.
