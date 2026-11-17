-- WoW Forever 1.60.1. No events, timers, casts, or automatic bar changes.
local PREFIX = "|cff54d2ffShamanBars|r: "
local function say(text) print(PREFIX .. text) end
local preparedHere = false

-- IDs identify spell families; placement always uses an actual learned entry.
local SPELLS = {
    attack    = {6603},
    flame     = {8050},
    bolt      = {403},
    frost     = {8056},
    nova      = {408341, 1535},
    earth     = {8042},
    lesser    = {8004},
    wolf      = {2645},
    searing   = {3599},
    purge     = {370},
    strength  = {8075},
    earthbind = {2484},
    stoneclaw = {5730},
    stream    = {5394},
    tremor    = {8143},
    shield    = {324},
    heal      = {331},
    windfury  = {8232},
    rockbiter = {8017},
    flametongue = {8024},
    stoneskin = {8071},
}
local PLAN = {
    {"1", "attack"}, {"2", "flame"}, {"3", "bolt"}, {"4", "frost"}, {"5", "nova"},
    {"Q", "earth"}, {"E", "lesser"}, {"R", "wolf"}, {"F", "searing"}, {"G", "purge"},
    {"SHIFT-1", "strength"}, {"SHIFT-2", "searing"}, {"SHIFT-3", "earthbind"},
    {"SHIFT-4", "stoneclaw"}, {"SHIFT-5", "stream"}, {"SHIFT-6", "tremor"},
    {"SHIFT-Q", "shield"}, {"SHIFT-E", "heal"},
    {"SHIFT-R", "windfury", "rockbiter", "flametongue"}, {"SHIFT-F", "stoneskin"},
}
local BARS = {
    {name="MainActionBar", prefix="ActionButton", binding="ACTIONBUTTON"},
    {name="MultiBar7", prefix="MultiBar7Button", binding="MULTIACTIONBAR7BUTTON"},
}
local UTILITY = {
    {name="MultiBarBottomLeft", prefix="MultiBarBottomLeftButton"},
    {name="MultiBarBottomRight", prefix="MultiBarBottomRightButton"},
    {name="MultiBarRight", prefix="MultiBarRightButton"},
    {name="MultiBarLeft", prefix="MultiBarLeftButton"},
    {name="MultiBar5", prefix="MultiBar5Button"}, {name="MultiBar6", prefix="MultiBar6Button"},
}
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
local function sameKeys(a, b)
    if #a ~= #b then return false end
    for i, key in ipairs(a) do if b[i] ~= key then return false end end
    return true
end
local function action(slot)
    local kind, id = GetActionInfo(slot)
    return {kind=kind or "empty", id=id}
end
local function sameAction(a, b) return a.kind == b.kind and a.id == b.id end
local function actionText(a)
    if a.kind == "empty" then return "empty" end
    local name = a.kind == "spell" and C_Spell.GetSpellName(a.id)
    return (name or a.kind) .. " [" .. tostring(a.id) .. "]"
end
local function bindingAction(key, overrides)
    local command = GetBindingAction(key, overrides)
    return command and command ~= "NONE" and command or ""
end
local function keysFor(command) return {GetBindingKey(command)} end
local function visible(frame)
    return frame and type(frame.IsVisible) == "function" and frame:IsVisible()
end

local function safeCombat()
    assert(not InCombatLockdown() and
        not (UnitAffectingCombat and UnitAffectingCombat("player")), "Leave combat; nothing is queued.")
end
local function safeCursor()
    safeCombat()
    assert(not GetCursorInfo(), "Cursor is occupied; put the held action/item down first.")
end
local function ready()
    local _, class = UnitClass("player")
    assert(class == "SHAMAN", "This layout is for Shamans only.")
    safeCursor()
    assert(C_Spell and C_Spell.GetSpellName and C_Spell.PickupSpell and
        C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and
        C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo and
        C_SpellBook.IsSpellKnown and C_SpellBook.PickupSpellBookItem and
        C_ActionBar and C_ActionBar.GetActionBarPage and Enum and
        Enum.SpellBookSpellBank and Enum.SpellBookItemType and Enum.BindingSet,
        "Required Forever API is unavailable; no changes made.")
    for _, name in ipairs({"GetActionInfo", "GetCursorInfo", "ClearCursor", "PickupAction",
        "PlaceAction", "GetBindingKey", "GetBindingAction", "SetBinding", "SaveBindings"}) do
        assert(type(_G[name]) == "function", "Missing API: " .. name)
    end
end
local function normalBars()
    assert(C_ActionBar.GetActionBarPage() == 1, "Select main action bar page 1 first.")
    for _, name in ipairs({"HasBonusActionBar", "HasOverrideActionBar",
        "HasVehicleActionBar", "HasTempShapeshiftActionBar"}) do
        assert(not (C_ActionBar[name] and C_ActionBar[name]()),
            "Leave vehicle/override/bonus bars before changing the layout.")
    end
end

local function families()
    local names, ids = {}, {}
    for family, anchors in pairs(SPELLS) do
        for _, id in ipairs(anchors) do
            ids[id] = family
            local name = C_Spell.GetSpellName(id)
            if name then names[name] = family end
        end
    end
    return names, ids
end
local function familyFor(id, names, ids)
    return ids[id] or names[C_Spell.GetSpellName(id) or ""]
end
local function learned()
    local names, ids = families()
    local known = {}
    local bank = Enum.SpellBookSpellBank.Player
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if info then
            for index = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local spell = C_SpellBook.GetSpellBookItemInfo(index, bank)
                if spell and spell.itemType == Enum.SpellBookItemType.Spell and spell.spellID and
                    not spell.isPassive and not spell.isOffSpec and
                    (C_SpellBook.IsSpellKnown(spell.spellID, bank) or
                     (spell.actionID and C_SpellBook.IsSpellKnown(spell.actionID, bank))) then
                    local family = ids[spell.spellID] or ids[spell.actionID] or names[spell.name]
                    if family then
                        ids[spell.spellID] = family
                        if spell.actionID then ids[spell.actionID] = family end
                        local subtext = spell.subName or
                            (C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(spell.spellID)) or ""
                        local rank = tonumber(subtext:match("(%d+)")) or 0
                        local highest = C_ActionBar.IsHighestSpellRank and
                            C_ActionBar.IsHighestSpellRank(spell.spellID) and 1 or 0
                        local level = C_Spell.GetSpellLevelLearned and
                            C_Spell.GetSpellLevelLearned(spell.spellID) or 0
                        local old = known[family]
                        if not old or highest > old.highest or
                            (highest == old.highest and (rank > old.rank or
                             (rank == old.rank and (level > old.level or
                              (level == old.level and spell.spellID > old.id))))) then
                            known[family] = {id=spell.spellID, baseID=spell.actionID, index=index,
                                name=spell.name, family=family, highest=highest, rank=rank, level=level}
                        end
                    end
                end
            end
        end
    end
    return known, names, ids
end
local function choose(definition, known)
    for i = 2, #definition do
        if known[definition[i]] then return known[definition[i]] end
    end
end
local function managed(a, names, ids)
    return a.kind == "spell" and familyFor(a.id, names, ids) ~= nil
end

local function buttonSlot(button)
    assert(button and type(button.CalculateAction) == "function", "Default action button is unavailable.")
    local slot = button:CalculateAction()
    assert(type(slot) == "number" and slot > 0 and slot % 1 == 0, "Invalid runtime action slot.")
    assert(not button.action or button.action == slot, "Cached and secure button slots disagree; reload first.")
    return slot
end
local function visibleBar(spec)
    local bar = _G[spec.name]
    assert(visible(bar), "Show the Blizzard " .. spec.name .. " bar first.")
    assert(not bar.numButtonsShowable or bar.numButtonsShowable >= 10,
        spec.name .. " must show at least 10 buttons.")
    assert((not bar.numRows or bar.numRows == 1) and bar.isHorizontal ~= false and
        bar.addButtonsToRight ~= false, spec.name .. " must use one left-to-right horizontal row.")
    return bar
end
local function resolve()
    normalBars()
    local entries, occupied, allSlots = {}, {}, {}
    for barIndex, spec in ipairs(BARS) do
        local bar = visibleBar(spec)
        for index = 1, 12 do
            local button = _G[spec.prefix .. index]
            local slot = buttonSlot(button)
            assert(button.bar == bar, "Button belongs to an unexpected bar.")
            if barIndex == 1 then assert(slot == index, "Main bar is not on its default page.") end
            assert(not allSlots[slot], "Visible bars share an action slot; no changes allowed.")
            allSlots[slot] = true
            local command = button.bindingAction or button.commandName
            assert(command == spec.binding .. index, "Unexpected button binding command.")
            if index <= 10 then
                occupied[slot] = true
                local definition = PLAN[(barIndex - 1) * 10 + index]
                entries[#entries+1] = {slot=slot, button=spec.prefix .. index, bar=spec.name,
                    command=command, key=definition[1], definition=(barIndex - 1) * 10 + index}
            end
        end
    end
    for _, spec in ipairs(UTILITY) do
        local bar = _G[spec.name]
        if visible(bar) then
            for index = 1, 12 do
                local button = _G[spec.prefix .. index]
                if button then
                    assert(button.bar == bar, "Unexpected utility button ownership.")
                    local slot = buttonSlot(button)
                    assert(not allSlots[slot], "Visible bars share an action slot: " .. spec.prefix .. index)
                    allSlots[slot] = true
                end
            end
        end
    end
    return entries, occupied
end
local function captureBindings(entries)
    local groups = {}
    for _, entry in ipairs(entries) do
        groups[entry.command] = keysFor(entry.command)
        local old = bindingAction(entry.key)
        if old ~= "" then groups[old] = keysFor(old) end
    end
    return groups
end
local function buildSnapshot()
    local entries, occupied = resolve()
    local _, names, ids = learned()
    local empty = {}
    for _, spec in ipairs(UTILITY) do
        local bar = _G[spec.name]
        if visible(bar) then
            for index = 1, math.min(bar.numButtonsShowable or 12, 12) do
                local button = _G[spec.prefix .. index]
                if button and button.bar == bar then
                    local slot = buttonSlot(button)
                    if not occupied[slot] and action(slot).kind == "empty" then
                        occupied[slot] = true
                        empty[#empty+1] = {slot=slot, button=spec.prefix .. index}
                    end
                end
            end
        end
    end
    for _, entry in ipairs(entries) do
        entry.before = action(entry.slot)
        if entry.before.kind ~= "empty" and not managed(entry.before, names, ids) then
            assert(entry.before.kind == "spell" or entry.before.kind == "item" or
                entry.before.kind == "macro", "Unsupported occupied target; move " .. entry.button .. " manually.")
            local destination = table.remove(empty, 1)
            assert(destination, "No empty visible utility slots; enable an empty utility bar (e.g. Action Bar 6) " ..
                "or free space before preparing. No changes made.")
            entry.moveTo, entry.moveButton = destination.slot, destination.button
        end
    end
    return {version=2, entries=entries, bindings=captureBindings(entries), state="prepared"}
end
local function validateSnapshot(backup)
    assert(type(backup) == "table" and backup.version == 2 and
        type(backup.entries) == "table" and #backup.entries == #PLAN and
        type(backup.bindings) == "table", "Unrecognized snapshot; refusing changes.")
    local current = resolve()
    local seen = {}
    for index, entry in ipairs(backup.entries) do
        local actual = current[index]
        assert(entry.slot == actual.slot and entry.button == actual.button and
            entry.command == actual.command and entry.key == actual.key and
            entry.definition == index and type(entry.before) == "table",
            "Bar mapping changed since backup; restore the original bars before continuing.")
        assert(not seen[entry.slot], "Duplicate snapshot slot.")
        seen[entry.slot] = true
    end
    for _, entry in ipairs(backup.entries) do
        if entry.moveTo then
            assert(not seen[entry.moveTo] and type(entry.moveButton) == "string",
                "Invalid utility relocation in snapshot.")
            local button = _G[entry.moveButton]
            local utilityBar = button and button.bar
            local approved = false
            for _, spec in ipairs(UTILITY) do
                if utilityBar and utilityBar == _G[spec.name] then approved = true; break end
            end
            assert(approved and visible(utilityBar) and
                buttonSlot(button) == entry.moveTo, "Utility bar mapping changed since backup.")
            seen[entry.moveTo] = true
        end
    end
end
local function finalBindings(backup, known)
    local reserved, selected = {}, {}
    for _, entry in ipairs(backup.entries) do
        if choose(PLAN[entry.definition], known) then
            reserved[entry.key] = true
            selected[entry.command] = entry.key
        end
    end
    local groups = {}
    for command, before in pairs(backup.bindings) do
        local keys = {}
        if selected[command] then keys[1] = selected[command] end
        for _, key in ipairs(before) do
            if not reserved[key] then keys[#keys+1] = key end
        end
        groups[command] = keys
    end
    return groups
end
local function writeBindings(groups)
    local changed = false
    for command, wanted in pairs(groups) do
        if not sameKeys(keysFor(command), wanted) then changed = true end
    end
    if not changed then return false end
    for command in pairs(groups) do
        for _, key in ipairs(keysFor(command)) do
            safeCursor()
            assert(SetBinding(key), "Could not unbind " .. key)
        end
    end
    for command, keys in pairs(groups) do
        for _, key in ipairs(keys) do
            safeCursor()
            assert(SetBinding(key, command), "Could not bind " .. key)
        end
    end
    for command, keys in pairs(groups) do
        assert(sameKeys(keysFor(command), keys), "Binding order verification failed for " .. command)
    end
    return true
end
local function saveBindings()
    safeCursor()
    assert(SaveBindings(Enum.BindingSet.Character) ~= false, "Could not save character bindings.")
end
local function withCursor(fn)
    safeCursor()
    local ok, err = pcall(fn)
    ClearCursor()
    if not ok then error(err, 0) end
end
local function putSpell(slot, spell)
    withCursor(function()
        if spell.index then
            C_SpellBook.PickupSpellBookItem(spell.index, Enum.SpellBookSpellBank.Player)
        else
            C_Spell.PickupSpell(spell.id)
        end
        assert(GetCursorInfo() == "spell", "Spell pickup failed.")
        safeCombat()
        PlaceAction(slot)
        local result = action(slot)
        assert(result.kind == "spell" and (result.id == spell.id or result.id == spell.baseID),
            "Placed spell ID does not match the requested spell.")
    end)
end
local function clearSlot(slot)
    if action(slot).kind == "empty" then return end
    withCursor(function()
        PickupAction(slot)
        assert(action(slot).kind == "empty" and GetCursorInfo(), "Action pickup failed.")
    end)
end
local function moveAction(from, to, expected)
    assert(sameAction(action(from), expected) and action(to).kind == "empty",
        "Relocation source/destination changed; refusing overwrite.")
    withCursor(function()
        PickupAction(from)
        assert(GetCursorInfo() and action(from).kind == "empty", "Action pickup failed.")
        safeCombat()
        PlaceAction(to)
        assert(sameAction(action(to), expected) and action(from).kind == "empty",
            "Relocation verification failed.")
    end)
end
local function preflight(backup, known, names, ids, restoring)
    validateSnapshot(backup)
    local permittedKeys = {}
    for _, keys in pairs(backup.bindings) do
        for _, key in ipairs(keys) do permittedKeys[key] = true end
    end
    for _, entry in ipairs(backup.entries) do permittedKeys[entry.key] = true end
    for command in pairs(backup.bindings) do
        for _, key in ipairs(keysFor(command)) do
            assert(permittedKeys[key], "Bindings changed since the snapshot; review /shamanbars debug.")
        end
    end
    for _, entry in ipairs(backup.entries) do
        local spell = choose(PLAN[entry.definition], known)
        local current = action(entry.slot)
        if restoring or spell then
            assert(sameAction(current, entry.before) or current.kind == "empty" or
                managed(current, names, ids), "Target changed to an unrelated action: " .. entry.button)
            if entry.moveTo then
                local destination = action(entry.moveTo)
                if sameAction(current, entry.before) then
                    assert(destination.kind == "empty", "Reserved utility slot changed: " .. entry.moveButton)
                else
                    assert(sameAction(destination, entry.before), "Moved action is missing; refusing unsafe overwrite.")
                end
            elseif restoring and entry.before.kind == "spell" and
                not sameAction(current, entry.before) then
                assert(C_SpellBook.IsSpellKnown(entry.before.id, Enum.SpellBookSpellBank.Player),
                    "Original spell is no longer learned: " .. actionText(entry.before))
            end
            if not restoring and spell then
                local command = bindingAction(entry.key)
                assert(command == "" or backup.bindings[command],
                    "Requested key changed to an uncaptured binding: " .. entry.key)
                assert(bindingAction(entry.key, true) == command,
                    "Another addon overrides " .. entry.key .. "; no changes made.")
            end
        end
    end
end
local function restoreV2(backup)
    local known, names, ids = learned()
    preflight(backup, known, names, ids, true)
    for index = #backup.entries, 1, -1 do
        local entry = backup.entries[index]
        local current = action(entry.slot)
        if not sameAction(current, entry.before) then
            if entry.moveTo then
                clearSlot(entry.slot)
                moveAction(entry.moveTo, entry.slot, entry.before)
            elseif entry.before.kind == "empty" then
                clearSlot(entry.slot)
            else
                putSpell(entry.slot, {id=entry.before.id})
            end
        end
    end
    if writeBindings(backup.bindings) then saveBindings() end
    backup.state = "restored"
    say("Original slots, relocated utility actions and binding order restored. /reload to save.")
end
local function legacySlot(slot)
    return type(slot) == "number" and slot % 1 == 0 and
        ((slot >= 1 and slot <= 10) or (slot >= 61 and slot <= 70))
end
local function restoreLegacy(backup)
    assert(type(backup.slots) == "table" and type(backup.keys) == "table", "Invalid legacy snapshot.")
    local _, names, ids = learned()
    for slot, oldID in pairs(backup.slots) do
        assert(legacySlot(slot) and type(oldID) == "number", "Invalid legacy slot record.")
        local current = action(slot)
        assert(current.kind == "empty" or managed(current, names, ids) or
            (current.kind == "spell" and current.id == oldID), "Legacy slot changed; refusing unsafe restore.")
        assert(oldID == 0 or C_SpellBook.IsSpellKnown(oldID, Enum.SpellBookSpellBank.Player),
            "Legacy original spell is no longer learned: " .. tostring(oldID))
    end
    local allowed = {["SHIFT-G"]=true}
    for _, definition in ipairs(PLAN) do allowed[definition[1]] = true end
    for key, command in pairs(backup.keys) do
        assert(allowed[key] and type(command) == "string", "Invalid legacy binding record.")
    end
    if not ShamanBarsOriginalBackup then ShamanBarsOriginalBackup = copy(backup) end
    for slot, oldID in pairs(backup.slots) do
        if oldID == 0 then clearSlot(slot)
        elseif not sameAction(action(slot), {kind="spell", id=oldID}) then
            putSpell(slot, {id=oldID})
        end
    end
    for key, command in pairs(backup.keys) do
        safeCursor()
        assert(SetBinding(key, command ~= "" and command or nil), "Could not restore legacy key " .. key)
    end
    saveBindings()
    backup.restored = true
    say("Legacy pre-install spell slots and recorded keys restored; original snapshot retained.")
    say("Legacy backups did not record primary-key order. /reload, then /shamanbars prepare.")
end
local function snapshotForPreview()
    if ShamanBarsBackup and ShamanBarsBackup.version == 2 and ShamanBarsBackup.state ~= "restored" then
        validateSnapshot(ShamanBarsBackup)
        return ShamanBarsBackup
    end
    return buildSnapshot()
end
local function preview()
    ready()
    local backup = snapshotForPreview()
    local known = learned()
    say("PREVIEW ONLY - no bars, bindings or backups changed.")
    say("MainActionBar + MultiBar7; slots below come from visible buttons, not screen row numbers.")
    for _, entry in ipairs(backup.entries) do
        local spell = choose(PLAN[entry.definition], known)
        if not spell then
            say(entry.key .. " SKIP unlearned; " .. entry.button .. " slot " .. entry.slot .. " stays unchanged.")
        else
            local wanted = {kind="spell", id=spell.id}
            say(entry.button .. " slot " .. entry.slot .. ": " .. actionText(action(entry.slot)) ..
                " -> " .. actionText(wanted) .. " (" .. (sameAction(action(entry.slot), wanted) and "KEEP" or "SET") .. ")")
            if entry.moveTo and sameAction(action(entry.slot), entry.before) then
                say("  MOVE existing " .. actionText(entry.before) .. " -> " .. entry.moveButton ..
                    " slot " .. entry.moveTo .. " (empty utility slot; preserved for rollback)")
            end
        end
    end
    local groups = finalBindings(backup, known)
    for command, keys in pairs(groups) do
        local before = keysFor(command)
        if not sameKeys(before, keys) then
            say("BIND " .. command .. ": [" .. table.concat(before, ", ") .. "] -> [" ..
                table.concat(keys, ", ") .. "] (first key is the displayed hotkey)")
        end
    end
    if ShamanBarsBackup and ShamanBarsBackup.version == 1 and not ShamanBarsBackup.restored then
        say("APPLY BLOCKED: restore the legacy snapshot first: /shamanbars restore, then /reload.")
    else
        say("Before first apply: /shamanbars prepare, /reload, /shamanbars preview, /shamanbars apply.")
    end
    say("Searing Totem on F and Shift-2 is intentional. Other bars are not swept for duplicates.")
end
local function prepare()
    ready()
    if ShamanBarsBackup and not ShamanBarsBackup.restored and ShamanBarsBackup.state ~= "restored" then
        error("Snapshot already exists; it will not be overwritten. Use /shamanbars restore first.")
    end
    local backup = buildSnapshot()
    if ShamanBarsBackup and not ShamanBarsOriginalBackup then
        ShamanBarsOriginalBackup = copy(ShamanBarsBackup)
    end
    ShamanBarsBackup = backup
    preparedHere = true
    say("Pre-change snapshot prepared; NO bars or bindings changed.")
    say("Run /reload to persist it BEFORE /shamanbars apply. No apply runs on reload.")
end
local function apply()
    ready()
    if not ShamanBarsBackup or ShamanBarsBackup.restored or ShamanBarsBackup.state == "restored" then
        prepare()
        return
    end
    local backup = ShamanBarsBackup
    assert(backup.version == 2, "Restore the legacy snapshot first: /shamanbars restore, then /reload.")
    assert(not preparedHere, "Run /reload to persist the prepared snapshot before applying.")
    local known, names, ids = learned()
    preflight(backup, known, names, ids, false)
    local placed, skipped, moved = 0, 0, 0
    local ok, err = pcall(function()
        for _, entry in ipairs(backup.entries) do
            local spell = choose(PLAN[entry.definition], known)
            if not spell then
                skipped = skipped + 1
            else
                safeCursor()
                if entry.moveTo and sameAction(action(entry.slot), entry.before) then
                    moveAction(entry.slot, entry.moveTo, entry.before)
                    moved = moved + 1
                end
                local current = action(entry.slot)
                if current.kind ~= "spell" or (current.id ~= spell.id and current.id ~= spell.baseID) then
                    putSpell(entry.slot, spell)
                    placed = placed + 1
                end
            end
        end
        if writeBindings(finalBindings(backup, known)) then saveBindings() end
    end)
    if not ok then
        say("Apply stopped: " .. tostring(err))
        if not InCombatLockdown() and not GetCursorInfo() then
            local restored, restoreError = pcall(restoreV2, backup)
            if not restored then say("Rollback needs review: " .. tostring(restoreError)) end
        else
            say("Leave combat and use /shamanbars restore. No deferred changes are queued.")
        end
        return
    end
    backup.state = "applied"
    say("Done: " .. placed .. " spells changed, " .. moved .. " utility actions preserved, " ..
        skipped .. " unlearned positions skipped. Repeat apply is a no-op when unchanged.")
    say("Use /shamanbars debug to inspect actual buttons and keys, then /reload to save.")
end
local function restore()
    ready()
    normalBars()
    local backup = ShamanBarsBackup
    assert(type(backup) == "table", "No snapshot exists; no restoration was attempted.")
    if backup.version == 1 then
        if backup.restored then say("Legacy snapshot is already restored; it remains retained.")
        else restoreLegacy(backup) end
    else
        restoreV2(backup)
    end
end
local function debug()
    ready()
    local report = {page=C_ActionBar.GetActionBarPage(), bars={}}
    local specs = {BARS[1], BARS[2]}
    for _, spec in ipairs(UTILITY) do specs[#specs+1] = spec end
    say("DEBUG page=" .. report.page .. "; no bars or bindings changed.")
    for _, spec in ipairs(specs) do
        local bar = _G[spec.name]
        if bar then
            local record = {name=spec.name, shown=bar:IsShown(), visible=visible(bar), buttons={}}
            report.bars[#report.bars+1] = record
            say(spec.name .. " enabled=" .. tostring(record.shown) .. " visible=" .. tostring(record.visible))
            if record.visible then
                for index = 1, 12 do
                    local button = _G[spec.prefix .. index]
                    if button then
                        local ok, slot = pcall(buttonSlot, button)
                        local command = button.bindingAction or button.commandName or ""
                        local data = {button=spec.prefix .. index, slot=ok and slot or nil,
                            error=not ok and tostring(slot) or nil, command=command,
                            keys=keysFor(command)}
                        record.buttons[#record.buttons+1] = data
                        if ok then
                            data.action = action(slot)
                            data.actionName = data.action.kind == "spell" and
                                C_Spell.GetSpellName(data.action.id) or nil
                            say(data.button .. " slot=" .. slot .. " " .. actionText(data.action) ..
                                " bind=" .. command .. " keys=[" .. table.concat(data.keys, ", ") .. "]")
                        else
                            say(data.button .. " MAPPING ERROR: " .. tostring(slot))
                        end
                    end
                end
            end
        end
    end
    local known = learned()
    report.spells = copy(known)
    ShamanBarsDiagnostics = report
    say("Learned selections:")
    for family, spell in pairs(known) do
        say(family .. " = " .. spell.name .. " [" .. spell.id .. "], rank " .. spell.rank ..
            ", spellbook index " .. spell.index)
    end
    say("Diagnostics are local SavedVariables only; /reload persists them. Do not upload character data.")
end

SLASH_SHAMANBARS1 = "/shamanbars"
SLASH_SHAMANBARS2 = "/sbars"
SlashCmdList.SHAMANBARS = function(message)
    local command = (message or ""):lower():match("^%s*(%S*)")
    local handlers = {preview=preview, prepare=prepare, apply=apply, restore=restore, debug=debug}
    if command == "" then command = "preview" end
    if not handlers[command] then
        say("Commands: /shamanbars preview | prepare | apply | restore | debug")
        return
    end
    local ok, err = pcall(handlers[command])
    if not ok then say(tostring(err)) end
end
