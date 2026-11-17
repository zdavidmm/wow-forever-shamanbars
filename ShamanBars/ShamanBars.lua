-- ShamanBars: WoW Forever (interface 16001)
-- A one-time, manually triggered action-bar organizer. No combat automation.
-- Only empty slots and the managed spells below may be replaced.

local PREFIX = "|cff54d2ffShamanBars|r: "
local function say(msg) print(PREFIX .. msg) end

-- Default Blizzard UI mapping:
--   Main action bar 1  : action slots 1-12, bindings ACTIONBUTTON1-12
--   Bottom-left bar 2 : action slots 61-72, bindings MULTIACTIONBAR1BUTTON1-12
-- Only slots 1-10 on each of these two bars are changed.
-- When a spell isn't learned, its existing slot/binding is NOT changed.
local PLAN = {
    -- Main bar: numbers 1-5, then Q E R F G.
    {slot=1,  key="1",       bind="ACTIONBUTTON1", names={"Auto Attack", "Attack"}},
    {slot=2,  key="2",       bind="ACTIONBUTTON2", names={"Flame Shock"}},
    {slot=3,  key="3",       bind="ACTIONBUTTON3", names={"Lightning Bolt"}},
    {slot=4,  key="4",       bind="ACTIONBUTTON4", names={"Frost Shock"}},
    {slot=5,  key="5",       bind="ACTIONBUTTON5", names={"Stormstrike", "Fire Nova Totem", "Fire Nova"}},
    {slot=6,  key="Q",       bind="ACTIONBUTTON6", names={"Earth Shock"}},
    {slot=7,  key="E",       bind="ACTIONBUTTON7", names={"Lesser Healing Wave", "Healing Wave"}},
    {slot=8,  key="R",       bind="ACTIONBUTTON8", names={"Ghost Wolf"}},
    {slot=9,  key="F",       bind="ACTIONBUTTON9", names={"Searing Totem"}},
    {slot=10, key="G",       bind="ACTIONBUTTON10", names={"Purge"}},

    -- Second visible bar: Shift keys for totems, buffs and secondary heals.
    {slot=61, key="SHIFT-1", bind="MULTIACTIONBAR1BUTTON1", names={"Strength of Earth Totem"}},
    {slot=62, key="SHIFT-2", bind="MULTIACTIONBAR1BUTTON2", names={"Flametongue Weapon"}},
    {slot=63, key="SHIFT-3", bind="MULTIACTIONBAR1BUTTON3", names={"Earthbind Totem"}},
    {slot=64, key="SHIFT-4", bind="MULTIACTIONBAR1BUTTON4", names={"Stoneclaw Totem"}},
    {slot=65, key="SHIFT-5", bind="MULTIACTIONBAR1BUTTON5", names={"Healing Stream Totem"}},
    {slot=66, key="SHIFT-G", bind="MULTIACTIONBAR1BUTTON6", names={"Tremor Totem"}},
    {slot=67, key="SHIFT-Q", bind="MULTIACTIONBAR1BUTTON7", names={"Lightning Shield"}},
    {slot=68, key="SHIFT-E", bind="MULTIACTIONBAR1BUTTON8", names={"Healing Wave"}},
    {slot=69, key="SHIFT-R", bind="MULTIACTIONBAR1BUTTON9", names={"Windfury Weapon", "Rockbiter Weapon"}},
    {slot=70, key="SHIFT-F", bind="MULTIACTIONBAR1BUTTON10", names={"Stoneskin Totem"}},
}

local MANAGED_NAMES = {}
for _, entry in ipairs(PLAN) do
    for _, name in ipairs(entry.names) do MANAGED_NAMES[name] = true end
end

local function findKnownSpells()
    local found, managed = {}, {}
    if not C_SpellBook or not C_SpellBook.GetSpellBookItemInfo or
       not C_SpellBook.GetNumSpellBookSkillLines or
       not C_SpellBook.GetSpellBookSkillLineInfo or
       not C_SpellBook.IsSpellKnown or not Enum or
       not Enum.SpellBookSpellBank or not Enum.SpellBookItemType then
        return nil, "WoW Forever spellbook API is unavailable."
    end

    local bank = Enum.SpellBookSpellBank.Player
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local tab = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if tab then
            local start = (tab.itemIndexOffset or 0) + 1
            local finish = start + (tab.numSpellBookItems or 0) - 1
            for index = start, finish do
                local info = C_SpellBook.GetSpellBookItemInfo(index, bank)
                if info and info.name and info.spellID and not info.isPassive and not info.isOffSpec and
                   info.itemType == Enum.SpellBookItemType.Spell and
                   (C_SpellBook.IsSpellKnown(info.spellID, bank) or
                    (info.actionID and C_SpellBook.IsSpellKnown(info.actionID, bank))) then
                    found[info.name] = {index=index, id=info.spellID, baseID=info.actionID}
                    if MANAGED_NAMES[info.name] then
                        managed[info.spellID] = true
                        if info.actionID then managed[info.actionID] = true end
                    end
                end
            end
        end
    end
    return found, nil, managed
end

local function choose(entry, known)
    for _, name in ipairs(entry.names) do
        if known[name] then return name, known[name] end
    end
    return nil, nil
end

local function checkReady()
    local _, class = UnitClass("player")
    if class ~= "SHAMAN" then say("This setup is for Shamans only."); return false end
    if InCombatLockdown() then say("Leave combat before using this command."); return false end
    if GetCursorInfo and GetCursorInfo() then
        say("Your cursor is holding something. Place it down or press Escape first.")
        return false
    end
    if not C_ActionBar or not C_ActionBar.GetActionBarPage then
        say("WoW Forever action-bar API is unavailable.")
        return false
    end
    if C_ActionBar.GetActionBarPage() ~= 1 or
       (ActionButton1 and ActionButton1.action and ActionButton1.action ~= 1) or
       (MultiBarBottomLeftButton1 and MultiBarBottomLeftButton1.action and
        MultiBarBottomLeftButton1.action ~= 61) then
        say("Use the default Blizzard bars on main bar page 1, outside vehicle/override bars.")
        return false
    end
    return true
end

local function canReplace(slot, managed)
    local actionType, id = GetActionInfo(slot)
    return not actionType or (actionType == "spell" and managed[id]), id
end

local function writeAPIReady()
    if not C_SpellBook or not C_SpellBook.PickupSpellBookItem or
       not C_Spell or not C_Spell.PickupSpell or
       not Enum or not Enum.BindingSet or not Enum.BindingSet.Character then
        say("Your client is missing an action-bar/restore API. No changes made.")
        return false
    end
    for _, name in ipairs({"GetCursorInfo", "ClearCursor", "GetActionInfo", "PickupAction",
                           "PlaceAction", "GetBindingAction", "SetBinding", "SaveBindings"}) do
        if type(_G[name]) ~= "function" then
            say("Missing API " .. name .. ". No changes made.")
            return false
        end
    end
    return true
end

local function putSpell(slot, spell)
    if GetCursorInfo() then return false, "cursor is occupied" end
    local ok, err = pcall(function()
        if InCombatLockdown() then error("combat lockdown") end
        if spell.index then
            C_SpellBook.PickupSpellBookItem(spell.index, Enum.SpellBookSpellBank.Player)
        else
            C_Spell.PickupSpell(spell.id)
        end
        if GetCursorInfo() ~= "spell" then error("spell pickup failed; slot not changed") end
        if InCombatLockdown() then error("combat lockdown") end
        PlaceAction(slot)
        local actionType, id = GetActionInfo(slot)
        if actionType ~= "spell" or not id or (id ~= spell.id and id ~= spell.baseID) then
            error("placed spell ID does not match the requested spell")
        end
    end)
    ClearCursor()
    return ok, err
end

local function bindKey(key, command)
    local ok, result = pcall(SetBinding, key, command ~= "" and command or nil)
    return ok and result and (GetBindingAction(key) or "") == command
end

local function saveCharacterBindings()
    if InCombatLockdown() then
        say("Combat started; bindings were not saved. Nothing is queued.")
        return
    end
    local ok, err = pcall(SaveBindings, Enum.BindingSet.Character)
    if not ok then say("Could not save character bindings: " .. tostring(err)) end
end

local function preview()
    if not checkReady() then return end
    local known, err, managed = findKnownSpells()
    if not known then say(err); return end
    local changing, missing, protected = 0, 0, 0
    say("PREVIEW - nothing has been modified:")
    for _, entry in ipairs(PLAN) do
        local name = choose(entry, known)
        if not name then
            missing = missing + 1
            say(entry.key .. " -> SKIP (not learned: " .. table.concat(entry.names, " / ") .. ")")
        elseif not canReplace(entry.slot, managed) then
            protected = protected + 1
            say(entry.key .. " -> SKIP slot " .. entry.slot .. " (item, macro, or unrelated spell; move it manually first)")
        else
            changing = changing + 1
            local actionType = GetActionInfo(entry.slot)
            local note = actionType and " (replaces a managed spell)" or ""
            local oldBinding = GetBindingAction(entry.key)
            if oldBinding and oldBinding ~= "" and oldBinding ~= entry.bind then
                note = note .. " (key currently: " .. oldBinding .. ")"
            end
            say(entry.key .. " -> " .. name .. " [action slot " .. entry.slot .. "]" .. note)
        end
    end
    say(changing .. " slots available, " .. missing .. " unlearned and " .. protected .. " protected slots skipped.")
    say("Q/E/R/F/G and Shift keys may replace movement/UI bindings. Other keys are not changed.")
    say("To proceed: /shamanbars apply. Roll back with /shamanbars restore.")
end

local function apply()
    if not checkReady() then return end
    local known, err, managed = findKnownSpells()
    if not known then say(err); return end
    if not writeAPIReady() then return end
    if ShamanBarsBackup and (type(ShamanBarsBackup) ~= "table" or ShamanBarsBackup.version ~= 1 or
       type(ShamanBarsBackup.slots) ~= "table" or type(ShamanBarsBackup.keys) ~= "table") then
        say("Unrecognized backup format. No changes made.")
        return
    end
    ShamanBarsBackup = ShamanBarsBackup or {version=1, slots={}, keys={}}
    local backup = ShamanBarsBackup

    local applied, skipped, bindFailures, placementFailures = 0, 0, 0, 0
    local bindingsChanged = false
    for _, entry in ipairs(PLAN) do
        if InCombatLockdown() then
            say("Combat started; stopped. No changes will run automatically later.")
            break
        end
        local name, spell = choose(entry, known)
        local replaceable, oldID = canReplace(entry.slot, managed)
        if not spell or not replaceable then
            skipped = skipped + 1
        else
            -- Keep the first pre-apply state, including empty slots, across upgrades.
            if backup.slots[entry.slot] == nil then backup.slots[entry.slot] = oldID or 0 end
            local ok, errorText = putSpell(entry.slot, spell)
            if not ok then
                placementFailures = placementFailures + 1
                say("Could not place " .. name .. ": " .. tostring(errorText))
            else
                applied = applied + 1
                if InCombatLockdown() then break end
                if backup.keys[entry.key] == nil then
                    backup.keys[entry.key] = GetBindingAction(entry.key) or ""
                end
                if bindKey(entry.key, entry.bind) then
                    bindingsChanged = true
                else
                    bindFailures = bindFailures + 1
                    say("Could not bind key " .. entry.key .. ".")
                end
            end
        end
    end

    if bindingsChanged then saveCharacterBindings() end
    say("Done: " .. applied .. " slots set, " .. skipped .. " unlearned/protected slots skipped; " ..
        placementFailures .. " placement issues and " .. bindFailures .. " keybind issues.")
    say("Check your bars, then /reload to persist the restore snapshot. Undo: /shamanbars restore.")
    say("After learning Stormstrike, preview/apply again: key 5 upgrades; Auto Attack stays on 1.")
end

local function restore()
    if not checkReady() then return end
    local known, err, managed = findKnownSpells()
    if not known then say(err); return end
    if not writeAPIReady() then return end
    local backup = ShamanBarsBackup
    if type(backup) ~= "table" or backup.version ~= 1 or
       type(backup.slots) ~= "table" or type(backup.keys) ~= "table" then
        say("No usable pre-apply snapshot for this character.")
        return
    end
    local restored, skipped, keys = 0, 0, 0
    for _, entry in ipairs(PLAN) do
        local oldID = backup.slots[entry.slot]
        if oldID ~= nil then
            if InCombatLockdown() then say("Combat started; restore stopped. Nothing is queued."); return end
            local replaceable, currentID = canReplace(entry.slot, managed)
            local ok, errorText
            if currentID == oldID and GetActionInfo(entry.slot) == "spell" then
                ok = true
            elseif not replaceable then
                errorText = "slot now contains an item, macro, or unrelated spell"
            elseif oldID == 0 then
                ok, errorText = pcall(function()
                    if GetCursorInfo() then error("cursor is occupied") end
                    PickupAction(entry.slot)
                    ClearCursor()
                    if GetActionInfo(entry.slot) then error("could not empty slot") end
                end)
            elseif C_SpellBook.IsSpellKnown(oldID, Enum.SpellBookSpellBank.Player) then
                ok, errorText = putSpell(entry.slot, {id=oldID})
            else
                errorText = "previous spell is no longer learned"
            end
            if ok then
                backup.slots[entry.slot] = nil
                restored = restored + 1
            else
                skipped = skipped + 1
                say("Restore skipped slot " .. entry.slot .. ": " .. tostring(errorText))
            end
        end
    end
    for _, entry in ipairs(PLAN) do
        local oldBinding = backup.keys[entry.key]
        if oldBinding ~= nil then
            if InCombatLockdown() then say("Combat started; restore stopped. Nothing is queued."); return end
            if bindKey(entry.key, oldBinding) then
                backup.keys[entry.key] = nil
                keys = keys + 1
            else
                skipped = skipped + 1
                say("Could not restore key " .. entry.key .. ".")
            end
        end
    end
    if keys > 0 then saveCharacterBindings() end
    if not next(backup.slots) and not next(backup.keys) then ShamanBarsBackup = nil end
    say("Restored " .. restored .. " slots and " .. keys .. " keys; " .. skipped .. " issues/skips.")
    say("Bindings remain character-specific. /reload to persist the restore result.")
end

SLASH_SHAMANBARS1 = "/shamanbars"
SLASH_SHAMANBARS2 = "/sbars"
SlashCmdList.SHAMANBARS = function(message)
    local command = (message or ""):lower():match("^%s*(%S*)")
    if command == "apply" then
        apply()
    elseif command == "restore" then
        restore()
    elseif command == "preview" or command == "" then
        preview()
    else
        say("Commands: /shamanbars preview, /shamanbars apply, /shamanbars restore")
    end
end
