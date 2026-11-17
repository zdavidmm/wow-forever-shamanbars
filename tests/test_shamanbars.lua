local source = ADDON_SOURCE
local tests, failures = 0, 0
local realPrint = print

local function copy(t)
    if type(t) ~= "table" then return t end
    local result = {}
    for k, v in pairs(t) do result[k] = copy(v) end
    return result
end

local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function expect(value, message)
    if not value then error(message or "expectation failed", 2) end
end

local function world()
    local s = {
        actions = {
            [1]={"spell",6603}, [2]={"spell",403},
            [11]={"item",6948}, [12]={"macro",1},
            [71]={"spell",2550}, [72]={"item",118},
            [120]={"macro",2}, [180]={"spell",8690},
        },
        bindings = {
            ["1"]="ACTIONBUTTON1", ["2"]="ACTIONBUTTON2", ["3"]="ACTIONBUTTON3",
            ["4"]="ACTIONBUTTON4", ["5"]="ACTIONBUTTON5", ["6"]="ACTIONBUTTON6",
            Q="STRAFELEFT", E="STRAFERIGHT", R="REPLY", F="ASSISTTARGET",
            G="TARGETLASTHOSTILE", ["SHIFT-1"]="ACTIONPAGE1",
            ["SHIFT-2"]="ACTIONPAGE2", ["CTRL-P"]="TOGGLEPROFESSION",
            F8="MULTIACTIONBAR4BUTTON7",
        },
        book={}, known={}, messages={}, writes={}, saves={}, page=1, class="SHAMAN",
        pickupFails={}, pickupThrows={}, placeFails={}, wrongPlacements={}, bindingFails={},
    }
    local spells = {
        {"Attack",6603}, {"Flame Shock",8050}, {"Lightning Bolt",403},
        {"Frost Shock",8056}, {"Fire Nova Totem",1535}, {"Earth Shock",8042},
        {"Lesser Healing Wave",8004}, {"Ghost Wolf",2645}, {"Searing Totem",3599},
        {"Purge",370}, {"Strength of Earth Totem",8075}, {"Flametongue Weapon",8024},
        {"Earthbind Totem",2484}, {"Stoneclaw Totem",5730}, {"Healing Stream Totem",5394},
        {"Tremor Totem",8143}, {"Lightning Shield",324}, {"Healing Wave",331},
        {"Rockbiter Weapon",8017}, {"Stoneskin Totem",8071},
    }
    for _, spell in ipairs(spells) do
        s.book[#s.book+1] = {
            name=spell[1], spellID=spell[2], actionID=spell[2],
            itemType=1, isPassive=false, isOffSpec=false,
        }
        s.known[spell[2]] = true
    end
    s.savedAccount = copy(s.bindings)
    local env = setmetatable({}, {__index=_G})
    env._G = env
    env.SlashCmdList = {}
    env.Enum = {SpellBookSpellBank={Player=0}, SpellBookItemType={Spell=1,FutureSpell=2},
                BindingSet={Account=1,Character=2}}
    env.UnitClass = function() return "Shaman", s.class end
    env.InCombatLockdown = function() return s.combat or false end
    env.GetCursorInfo = function()
        if s.cursor then return s.cursor[1], s.cursor[2], nil, s.cursor[2] end
    end
    env.print = function(text) s.messages[#s.messages+1] = text end
    env.C_ActionBar = {GetActionBarPage=function() return s.page end}
    env.ActionButton1 = {action=1}
    env.MultiBarBottomLeftButton1 = {action=61}
    local function write(kind, a, b)
        expect(not s.combat, "protected write during combat: " .. kind)
        s.writes[#s.writes+1] = {kind,a,b}
    end
    env.GetActionInfo = function(slot)
        local action = s.actions[slot]
        if action then return unpack(action) end
    end
    env.ClearCursor = function() s.cursor = nil end
    env.PlaceAction = function(slot)
        write("place",slot)
        if not s.cursor or s.placeFails[slot] then return end
        local displaced = s.actions[slot]
        local id = s.wrongPlacements[slot] or s.cursor[2]
        s.actions[slot] = {"spell",id}
        s.cursor = displaced
        if s.combatAfterPlacement then s.combat = true end
    end
    env.PickupAction = function(slot)
        write("remove",slot)
        s.cursor = s.actions[slot]
        s.actions[slot] = nil
    end
    env.GetBindingAction = function(key) return s.bindings[key] or "" end
    env.SetBinding = function(key, command)
        write("bind",key,command)
        if s.bindingFails[key] then return nil end
        s.bindings[key] = command
        return true
    end
    env.SaveBindings = function(set)
        write("save",set)
        if s.saveThrows then error("simulated save failure") end
        s.saves[#s.saves+1] = set
        s.savedCharacter = copy(s.bindings)
    end
    env.C_SpellBook = {
        GetNumSpellBookSkillLines=function() return 2 end,
        GetSpellBookSkillLineInfo=function(line)
            if line == 1 then return {itemIndexOffset=0,numSpellBookItems=1} end
            return {itemIndexOffset=1,numSpellBookItems=#s.book-1}
        end,
        GetSpellBookItemInfo=function(index, bank)
            expect(bank == 0, "wrong spell bank")
            return s.book[index]
        end,
        IsSpellKnown=function(id, bank)
            expect(bank == 0, "wrong known-spell bank")
            return s.known[id] or false
        end,
        PickupSpellBookItem=function(index, bank)
            write("pickup",index,bank)
            if s.pickupThrows[index] then error("simulated pickup failure") end
            if not s.pickupFails[index] then s.cursor = {"spell",s.book[index].spellID} end
            if s.combatAfterPickup then s.combat = true end
        end,
    }
    env.C_Spell = {PickupSpell=function(id)
        write("restore-pickup",id)
        expect(s.known[id], "attempt to restore unlearned spell")
        s.cursor = {"spell",id}
    end}
    function s.load()
        local chunk, err = loadstring(source, "@ShamanBars.lua")
        expect(chunk, err)
        setfenv(chunk, env)
        chunk()
    end
    function s.command(command) env.SlashCmdList.SHAMANBARS(command) end
    function s.contains(text)
        for _, line in ipairs(s.messages) do
            if line:find(text,1,true) then return true end
        end
        return false
    end
    function s.learn(name,id)
        s.book[#s.book+1] = {name=name,spellID=id,actionID=id,itemType=1,isPassive=false,isOffSpec=false}
        s.known[id] = true
    end
    s.env = env
    s.load()
    return s
end

local function test(name, fn)
    tests = tests + 1
    local ok, err = pcall(fn)
    if ok then realPrint("PASS " .. name)
    else failures = failures + 1; realPrint("FAIL " .. name .. ": " .. tostring(err)) end
end

test("load only registers slash commands; no login/reload writes", function()
    local s = world()
    expect(#s.writes == 0 and s.env.ShamanBarsBackup == nil)
    expect(s.env.SLASH_SHAMANBARS1 == "/shamanbars" and s.env.SLASH_SHAMANBARS2 == "/sbars")
    expect(type(s.env.SlashCmdList.SHAMANBARS) == "function")
    s.load()
    expect(#s.writes == 0)
end)

test("preview/default/help are read-only and show key conflicts", function()
    local s = world()
    local actions, bindings = copy(s.actions), copy(s.bindings)
    s.command("preview"); s.command(""); s.command("help")
    expect(#s.writes == 0 and s.env.ShamanBarsBackup == nil)
    expect(equal(actions,s.actions) and equal(bindings,s.bindings))
    expect(s.contains("STRAFELEFT") and s.contains("nothing has been modified"))
end)

test("main layout places requested learned spells on correct slots and keys", function()
    local s = world(); s.command("apply")
    local ids = {6603,8050,403,8056,1535,8042,8004,2645,3599,370}
    local keys = {"1","2","3","4","5","Q","E","R","F","G"}
    for slot, id in ipairs(ids) do
        expect(equal(s.actions[slot],{"spell",id}),"wrong main action " .. slot)
        expect(s.bindings[keys[slot]] == "ACTIONBUTTON" .. slot,"wrong main binding")
    end
    expect(s.saves[1] == 2 and equal(s.savedAccount,world().savedAccount))
end)

test("secondary totems, both imbues, shield, healing and accessible Shift keys", function()
    local s = world(); s.command("apply")
    local ids = {8075,8024,2484,5730,5394,8143,324,331,8017,8071}
    local keys = {"SHIFT-1","SHIFT-2","SHIFT-3","SHIFT-4","SHIFT-5","SHIFT-G","SHIFT-Q","SHIFT-E","SHIFT-R","SHIFT-F"}
    for n,id in ipairs(ids) do
        expect(equal(s.actions[60+n],{"spell",id}),"wrong secondary action")
        expect(s.bindings[keys[n]] == "MULTIACTIONBAR1BUTTON" .. n,"wrong secondary binding")
    end
end)

test("items/macros/professions/unrelated spells and their keys are protected", function()
    local s = world()
    s.actions[2]={"item",118}; s.actions[3]={"macro",1}
    s.actions[4]={"spell",2550}; s.actions[61]={"spell",8690}
    local oldActions, oldKeys = copy(s.actions), copy(s.bindings)
    s.command("preview"); expect(s.contains("SKIP slot 2"))
    s.command("apply")
    for _,slot in ipairs({2,3,4,61}) do expect(equal(oldActions[slot],s.actions[slot])) end
    for _,key in ipairs({"2","3","4","SHIFT-1"}) do expect(oldKeys[key] == s.bindings[key]) end
end)

test("all unrelated slots and non-target keys remain unchanged", function()
    local s = world(); local old = copy(s.actions); local keys = copy(s.bindings)
    s.command("apply")
    for _,slot in ipairs({11,12,71,72,120,180}) do expect(equal(old[slot],s.actions[slot])) end
    for _,key in ipairs({"6","CTRL-P","F8"}) do expect(keys[key] == s.bindings[key]) end
end)

test("unlearned spells preserve their original slots and bindings", function()
    local s = world(); s.known[8050]=false
    s.command("apply")
    expect(equal(s.actions[2],{"spell",403}) and s.bindings["2"] == "ACTIONBUTTON2")
    expect(s.env.ShamanBarsBackup.slots[2] == nil and s.env.ShamanBarsBackup.keys["2"] == nil)
end)

test("future, passive, off-spec and not-known spellbook entries are skipped", function()
    local s = world()
    s.book[2].isOffSpec=true; s.book[3].isPassive=true
    s.book[4].itemType=2; s.known[1535]=false
    s.command("preview"); s.command("apply")
    for _,slot in ipairs({2,3,4,5}) do expect(s.env.ShamanBarsBackup.slots[slot] == nil) end
end)

test("future duplicate does not replace a learned spellbook rank", function()
    local s = world()
    s.book[#s.book+1]={name="Flame Shock",spellID=999,actionID=999,itemType=2}
    s.command("apply")
    expect(equal(s.actions[2],{"spell",8050}))
end)

test("Stormstrike upgrades key 5 without removing Auto Attack; first snapshot retained", function()
    local s = world(); s.command("apply")
    local original = s.env.ShamanBarsBackup.slots[5]
    s.learn("Stormstrike",17364); s.command("apply")
    expect(equal(s.actions[1],{"spell",6603}) and equal(s.actions[5],{"spell",17364}))
    expect(s.env.ShamanBarsBackup.slots[5] == original)
end)

test("healing fallback and future Windfury upgrade use only learned spells", function()
    local s = world(); s.known[8004]=false; s.command("apply")
    expect(equal(s.actions[7],{"spell",331}) and equal(s.actions[69],{"spell",8017}))
    s.learn("Windfury Weapon",8232); s.command("apply")
    expect(equal(s.actions[69],{"spell",8232}))
end)

test("apply then restore recovers occupied/empty slots and original bound/unbound keys", function()
    local s = world(); local actions, bindings = copy(s.actions), copy(s.bindings)
    s.command("apply"); s.command("apply"); s.command("restore")
    expect(equal(actions,s.actions),"actions not restored")
    expect(equal(bindings,s.bindings),"bindings not restored")
    expect(s.env.ShamanBarsBackup == nil)
    for _,set in ipairs(s.saves) do expect(set == 2,"account binding set saved") end
end)

test("snapshot survives simulated addon reload without automatic changes", function()
    local s = world(); local actions, bindings = copy(s.actions), copy(s.bindings)
    s.command("apply"); local writes = #s.writes; s.load()
    expect(#s.writes == writes)
    s.command("restore")
    expect(equal(actions,s.actions) and equal(bindings,s.bindings))
end)

for _,condition in ipairs({"class","combat","cursor","page","remapped-main","remapped-secondary"}) do
    test("commands refuse unsafe context: " .. condition, function()
        local s = world()
        if condition == "class" then s.class="MAGE"
        elseif condition == "combat" then s.combat=true
        elseif condition == "cursor" then s.cursor={"item",118}
        elseif condition == "page" then s.page=2
        elseif condition == "remapped-main" then s.env.ActionButton1.action=121
        else s.env.MultiBarBottomLeftButton1.action=49 end
        local cursor = copy(s.cursor)
        s.command("preview"); s.command("apply"); s.command("restore")
        expect(#s.writes == 0 and s.env.ShamanBarsBackup == nil)
        expect(equal(cursor,s.cursor),"user cursor was cleared")
    end)
end

test("missing spellbook API/enum fails closed", function()
    local s = world(); s.env.Enum.SpellBookItemType=nil
    s.command("preview"); s.command("apply")
    expect(#s.writes == 0 and s.contains("API is unavailable"))
end)

test("missing write API prevents any placement", function()
    local s = world(); s.env.C_Spell.PickupSpell=nil
    s.command("apply")
    expect(#s.writes == 0 and s.env.ShamanBarsBackup == nil)
end)

test("silent pickup failure does not touch occupied slot or rebind its key", function()
    local s = world(); s.pickupFails[2]=true; s.bindings["2"]="CUSTOM"
    s.command("apply")
    expect(equal(s.actions[2],{"spell",403}) and s.bindings["2"] == "CUSTOM")
    for _,write in ipairs(s.writes) do expect(not (write[1] == "place" and write[2] == 2)) end
    expect(s.contains("spell pickup failed"))
end)

test("pickup exception is reported without a false binding success", function()
    local s = world(); s.pickupThrows[2]=true; s.bindings["2"]="CUSTOM"
    s.command("apply")
    expect(equal(s.actions[2],{"spell",403}) and s.bindings["2"] == "CUSTOM")
    expect(s.contains("simulated pickup failure") and s.cursor == nil)
end)

test("silent placement failure is not accepted just because old action is a spell", function()
    local s = world(); s.placeFails[2]=true; s.bindings["2"]="CUSTOM"
    s.command("apply")
    expect(equal(s.actions[2],{"spell",403}) and s.bindings["2"] == "CUSTOM")
    expect(s.contains("placed spell ID does not match"))
end)

test("wrong spell ID after placement is reported and key left untouched", function()
    local s = world(); s.wrongPlacements[2]=403; s.bindings["2"]="CUSTOM"
    s.command("apply")
    expect(s.bindings["2"] == "CUSTOM" and s.contains("placed spell ID does not match"))
end)

test("base/override spell IDs are supported when only the base is known", function()
    local s = world(); s.book[2].spellID=900001
    s.wrongPlacements[2]=8050
    s.command("apply")
    expect(equal(s.actions[2],{"spell",8050}) and not s.contains("Could not place Flame Shock"))
end)

test("restore preserves a newly placed consumable and retains its snapshot", function()
    local s = world(); s.command("apply"); s.actions[2]={"item",118}; s.command("restore")
    expect(equal(s.actions[2],{"item",118}) and s.env.ShamanBarsBackup.slots[2] == 403)
    expect(s.contains("Restore skipped slot 2"))
end)

test("restore does not install a previous spell that is no longer learned", function()
    local s = world(); s.command("apply"); s.known[403]=false; s.command("restore")
    expect(s.contains("previous spell is no longer learned"))
    expect(s.env.ShamanBarsBackup.slots[2] == 403)
end)

test("failed binding is reported and remains recoverable", function()
    local s = world(); s.bindingFails.Q=true; s.command("apply")
    expect(s.bindings.Q == "STRAFELEFT" and s.contains("Could not bind key Q"))
    s.bindingFails.Q=nil; s.command("restore")
    expect(s.bindings.Q == "STRAFELEFT" and s.env.ShamanBarsBackup == nil)
end)

test("combat starting during pickup prevents placement and later automatic retries", function()
    local s = world(); local actions = copy(s.actions); s.combatAfterPickup=true
    s.command("apply")
    expect(equal(s.actions,actions))
    for _,write in ipairs(s.writes) do expect(write[1] == "pickup") end
    local writes = #s.writes; s.combat=false
    expect(#s.writes == writes)
end)

test("combat starting after placement prevents binding or subsequent placements", function()
    local s = world(); s.combatAfterPlacement=true; s.command("apply")
    expect(#s.writes == 2 and s.writes[1][1] == "pickup" and s.writes[2][1] == "place")
    expect(#s.saves == 0)
end)

test("binding save exception is visible rather than aborting slash handler", function()
    local s = world(); s.saveThrows=true; s.command("apply")
    expect(s.contains("Could not save character bindings"))
end)

test("unrecognized saved-variable schema blocks writes", function()
    local s = world(); s.env.ShamanBarsBackup={version=99}; s.command("apply")
    expect(#s.writes == 0 and s.contains("Unrecognized backup format"))
end)

test("restore without snapshot is harmless", function()
    local s = world(); s.command("restore")
    expect(#s.writes == 0 and s.contains("No usable pre-apply snapshot"))
end)

realPrint(string.format("RESULT: %d tests, %d failures",tests,failures))
return tests, failures
