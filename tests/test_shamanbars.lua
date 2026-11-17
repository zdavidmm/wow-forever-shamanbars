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
        actions={
            [1]={"spell",6603}, [2]={"spell",403},
            [11]={"item",6948}, [12]={"macro",1},
            [49]={"item",118}, [61]={"spell",8004}, [62]={"spell",2645},
            [71]={"spell",2550}, [72]={"item",117},
            [120]={"macro",2}, [179]={"item",159}, [180]={"spell",8690},
        },
        bindings={}, order={}, book={}, known={}, names={}, ranks={}, levels={},
        messages={}, writes={}, saves={}, page=1, class="SHAMAN",
        pickupFails={}, placeFails={}, wrongPlacements={}, bindingFailures={},
    }
    local env = setmetatable({}, {__index=_G})
    env._G = env
    env.SlashCmdList = {}
    env.Enum = {SpellBookSpellBank={Player=0}, SpellBookItemType={Spell=1,FutureSpell=2},
        BindingSet={Account=1,Character=2}}
    function s.bind(key, command)
        local old = s.bindings[key]
        if old then
            for index, value in ipairs(s.order[old]) do
                if value == key then table.remove(s.order[old],index); break end
            end
        end
        s.bindings[key] = command
        if command then
            s.order[command] = s.order[command] or {}
            s.order[command][#s.order[command]+1] = key
        end
    end
    for index=1,12 do s.bind(index <= 9 and tostring(index) or (index == 10 and "0" or (index == 11 and "-" or "=")),
        "ACTIONBUTTON"..index) end
    for index=1,6 do s.bind("SHIFT-"..index,"MULTIACTIONBAR7BUTTON"..index) end
    for index, key in ipairs({"Q","E","R","F"}) do s.bind(key,"MULTIACTIONBAR1BUTTON"..index) end
    s.bind("SHIFT-R","MULTIACTIONBAR1BUTTON6")
    s.bind("SHIFT-E","MULTIACTIONBAR1BUTTON5")
    s.bind("SHIFT-F","MULTIACTIONBAR1BUTTON7")
    s.bind("G","TARGETLASTHOSTILE")
    s.bind("CTRL-P","TOGGLEPROFESSION")
    s.bind("F8","MULTIACTIONBAR4BUTTON7")
    s.savedAccount = copy(s.bindings)
    function s.learn(name,id,rank,level)
        s.book[#s.book+1] = {name=name,spellID=id,actionID=id,itemType=1,
            subName="Rank "..(rank or 1),isPassive=false,isOffSpec=false}
        s.known[id], s.names[id], s.ranks[id], s.levels[id] = true,name,rank or 1,level or 1
    end
    for _, spell in ipairs({
        {"Attack",6603}, {"Flame Shock",8050}, {"Lightning Bolt",403},
        {"Frost Shock",8056}, {"Fire Nova Totem",1535}, {"Earth Shock",8042},
        {"Lesser Healing Wave",8004}, {"Ghost Wolf",2645}, {"Searing Totem",3599},
        {"Purge",370}, {"Strength of Earth Totem",8075}, {"Flametongue Weapon",8024},
        {"Earthbind Totem",2484}, {"Stoneclaw Totem",5730}, {"Healing Stream Totem",5394},
        {"Tremor Totem",8143}, {"Lightning Shield",324}, {"Healing Wave",331},
        {"Rockbiter Weapon",8017}, {"Stoneskin Totem",8071},
    }) do s.learn(spell[1],spell[2]) end
    s.names[408341] = "Fire Nova"
    s.names[8232] = "Windfury Weapon"
    s.names[556], s.known[556] = "Astral Recall",true
    local function write(kind,a,b)
        if s.combat then s.combatWrites=(s.combatWrites or 0)+1; error("protected write in combat") end
        s.writes[#s.writes+1] = {kind,a,b}
    end
    env.UnitClass = function() return "Shaman",s.class end
    env.InCombatLockdown = function() return s.combat or false end
    env.UnitAffectingCombat = function() return s.combat or false end
    env.GetCursorInfo = function()
        if s.cursor then return s.cursor[1],s.cursor[2],nil,s.cursor[2] end
    end
    env.print = function(text) s.messages[#s.messages+1]=text end
    env.GetActionInfo = function(slot) if s.actions[slot] then return unpack(s.actions[slot]) end end
    env.GetBindingAction = function(key,overrides)
        return (overrides and s.overrideKey == key and "CLICK OtherAddon:LeftButton") or s.bindings[key] or ""
    end
    env.GetBindingKey = function(command) return unpack(s.order[command] or {}) end
    env.SetBinding = function(key,command)
        write("bind",key,command)
        if (s.bindingFailures[key] or 0) > 0 then
            s.bindingFailures[key]=s.bindingFailures[key]-1; return nil
        end
        s.bind(key,command)
        return true
    end
    env.SaveBindings = function(set)
        write("save",set)
        if s.saveFailure then s.saveFailure=false; return false end
        s.saves[#s.saves+1]=set
        s.savedCharacter=copy(s.bindings)
        return true
    end
    env.ClearCursor = function() s.cursor=nil end
    env.PickupAction = function(slot)
        write("remove",slot)
        s.cursor=s.actions[slot]; s.actions[slot]=nil
    end
    env.PlaceAction = function(slot)
        write("place",slot)
        if not s.cursor or s.placeFails[slot] then return end
        local old=s.actions[slot]
        s.actions[slot]=copy(s.cursor)
        if s.wrongPlacements[slot] then s.actions[slot][2]=s.wrongPlacements[slot] end
        s.cursor=old
        if s.combatAfterPlacement then s.combat=true end
    end
    env.C_ActionBar = {
        GetActionBarPage=function() return s.page end,
        HasBonusActionBar=function() return s.bonus end,
        HasOverrideActionBar=function() return s.override end,
        HasVehicleActionBar=function() return s.vehicle end,
        HasTempShapeshiftActionBar=function() return s.shapeshift end,
        IsHighestSpellRank=function(id)
            for _, spell in ipairs(s.book) do
                if s.known[spell.spellID] and spell.itemType == 1 and not spell.isOffSpec and
                    spell.name == s.names[id] and (s.ranks[spell.spellID] or 0) > (s.ranks[id] or 0) then
                    return false
                end
            end
            return true
        end,
    }
    env.C_Spell = {
        GetSpellName=function(id) return s.names[id] end,
        GetSpellSubtext=function(id) return "Rank "..(s.ranks[id] or 0) end,
        GetSpellLevelLearned=function(id) return s.levels[id] or 0 end,
        PickupSpell=function(id)
            write("restore-pickup",id)
            expect(s.known[id],"restoring unlearned spell")
            s.cursor={"spell",id}
        end,
    }
    env.C_SpellBook = {
        GetNumSpellBookSkillLines=function() return 2 end,
        GetSpellBookSkillLineInfo=function(line)
            return line == 1 and {itemIndexOffset=0,numSpellBookItems=1} or
                {itemIndexOffset=1,numSpellBookItems=#s.book-1}
        end,
        GetSpellBookItemInfo=function(index,bank)
            expect(bank == 0,"wrong bank"); return s.book[index]
        end,
        IsSpellKnown=function(id,bank)
            expect(bank == 0,"wrong bank"); return s.known[id] or false
        end,
        PickupSpellBookItem=function(index,bank)
            write("pickup",index,bank)
            if not s.pickupFails[index] then s.cursor={"spell",s.book[index].spellID} end
            if s.combatAfterPickup then s.combat=true end
        end,
    }
    local function bar(name,prefix,first,command)
        local b={shown=true,numButtonsShowable=12,numRows=1,isHorizontal=true,addButtonsToRight=true}
        function b:IsShown() return self.shown end
        function b:IsVisible() return self.shown and not self.hiddenByVisibility end
        env[name]=b
        for i=1,12 do
            local button={bar=b,action=first+i-1,bindingAction=command..i,calculated=first+i-1}
            function button:CalculateAction() return self.calculated end
            env[prefix..i]=button
        end
    end
    bar("MainActionBar","ActionButton",1,"ACTIONBUTTON")
    bar("MultiBar7","MultiBar7Button",169,"MULTIACTIONBAR7BUTTON")
    bar("MultiBarBottomLeft","MultiBarBottomLeftButton",61,"MULTIACTIONBAR1BUTTON")
    bar("MultiBarBottomRight","MultiBarBottomRightButton",49,"MULTIACTIONBAR2BUTTON")
    function s.extraUtility()
        bar("MultiBar5","MultiBar5Button",145,"MULTIACTIONBAR5BUTTON")
    end
    function s.load()
        local chunk,err=loadstring(source,"@ShamanBars.lua")
        expect(chunk,err); setfenv(chunk,env); chunk()
    end
    function s.command(command) env.SlashCmdList.SHAMANBARS(command) end
    function s.contains(text)
        for _, line in ipairs(s.messages) do if line:find(text,1,true) then return true end end
        return false
    end
    function s.setup()
        s.command("prepare"); expect(env.ShamanBarsBackup and env.ShamanBarsBackup.version == 2,"prepare failed")
        s.load(); s.command("apply")
    end
    s.env=env; s.load()
    return s
end
local function test(name,fn)
    tests=tests+1
    local ok,err=pcall(fn)
    if ok then realPrint("PASS "..name)
    else failures=failures+1; realPrint("FAIL "..name..": "..tostring(err)) end
end

test("load/reload only registers commands; never applies",function()
    local s=world()
    expect(#s.writes == 0 and not s.env.ShamanBarsBackup)
    expect(s.env.SLASH_SHAMANBARS1 == "/shamanbars" and s.env.SLASH_SHAMANBARS2 == "/sbars")
    s.load(); expect(#s.writes == 0)
end)
test("preview/default/help are read-only and show exact slot and primary binding changes",function()
    local s=world(); local actions,bindings=copy(s.actions),copy(s.bindings)
    s.command("preview"); s.command(""); s.command("help")
    expect(#s.writes == 0 and not s.env.ShamanBarsBackup)
    expect(equal(actions,s.actions) and equal(bindings,s.bindings))
    expect(s.contains("MultiBar7Button1 slot 169") and s.contains("BIND ACTIONBUTTON6: [6] -> [Q, 6]"))
end)
test("first apply only prepares a snapshot; reload is required before writes",function()
    local s=world(); s.command("apply"); s.command("apply")
    expect(#s.writes == 0 and s.contains("persist the prepared snapshot"))
    s.load(); s.command("apply"); expect(#s.writes > 0)
end)
test("exact main layout uses learned spellbook entries; Fire Nova does not become Stormstrike",function()
    local s=world(); s.learn("Stormstrike",17364); s.setup()
    local ids={6603,8050,403,8056,1535,8042,8004,2645,3599,370}
    local keys={"1","2","3","4","5","Q","E","R","F","G"}
    for i,id in ipairs(ids) do
        expect(equal(s.actions[i],{"spell",id}),"wrong main slot "..i)
        expect(s.env.GetBindingKey("ACTIONBUTTON"..i) == keys[i],"wrong displayed main key")
    end
end)
test("secondary uses actual MultiBar7 slots and the requested Shift layout",function()
    local s=world(); s.setup()
    local ids={8075,3599,2484,5730,5394,8143,324,331,8017,8071}
    local keys={"SHIFT-1","SHIFT-2","SHIFT-3","SHIFT-4","SHIFT-5","SHIFT-6","SHIFT-Q","SHIFT-E","SHIFT-R","SHIFT-F"}
    for i,id in ipairs(ids) do
        expect(equal(s.actions[168+i],{"spell",id}),"wrong secondary slot")
        expect(s.env.GetBindingKey("MULTIACTIONBAR7BUTTON"..i) == keys[i],"wrong Shift key")
    end
end)
test("utility bar at 61-72 is not confused with the Shift bar",function()
    local s=world(); local old=copy(s.actions); s.setup()
    for slot=61,72 do expect(equal(old[slot],s.actions[slot]),"utility slot overwritten") end
end)
test("runtime CalculateAction determines secondary slots rather than hardcoded 169",function()
    local s=world()
    for i=1,12 do
        local button=s.env["MultiBar7Button"..i]
        button.action=144+i; button.calculated=144+i
    end
    s.setup()
    expect(equal(s.actions[145],{"spell",8075}) and not s.actions[169])
end)
test("requested keys become primary; existing secondary shortcuts are retained",function()
    local s=world(); local account=copy(s.savedAccount); s.setup()
    expect(equal(s.order.ACTIONBUTTON6,{"Q","6"}))
    expect(equal(s.order.ACTIONBUTTON7,{"E","7"}))
    expect(s.bindings["CTRL-P"] == "TOGGLEPROFESSION" and s.bindings.F8 == "MULTIACTIONBAR4BUTTON7")
    expect(equal(account,s.savedAccount))
    for _,set in ipairs(s.saves) do expect(set == 2) end
end)
test("second apply is a strict no-op, including pickup and binding calls",function()
    local s=world(); s.setup()
    local actions,bindings,snapshot=copy(s.actions),copy(s.bindings),copy(s.env.ShamanBarsBackup)
    local writes=#s.writes; s.command("apply")
    expect(#s.writes == writes and equal(actions,s.actions) and equal(bindings,s.bindings))
    expect(equal(snapshot,s.env.ShamanBarsBackup))
end)
test("highest learned rank wins regardless of spellbook traversal order",function()
    local s=world(); s.learn("Flame Shock",8052,2,14)
    local high=table.remove(s.book); table.insert(s.book,2,high)
    s.setup(); expect(equal(s.actions[2],{"spell",8052}))
end)
test("lower-rank managed actions are recognized even if absent from the spellbook",function()
    local s=world(); s.names[99901]="Flame Shock"; s.actions[3]={"spell",99901}
    s.setup()
    expect(equal(s.actions[3],{"spell",403}) and not s.env.ShamanBarsBackup.entries[3].moveTo)
end)
test("localized ID-derived family names and actual Fire Nova variant are resolved",function()
    local s=world()
    for _,spell in ipairs(s.book) do
        if spell.name == "Flame Shock" then spell.name="Localized Flame"; s.names[spell.spellID]=spell.name end
    end
    s.known[1535]=false; s.learn("Fire Nova",408341)
    s.setup()
    expect(equal(s.actions[2],{"spell",8050}) and equal(s.actions[5],{"spell",408341}))
end)
test("future, passive, off-spec and unlearned entries do not shift slots or bindings",function()
    local s=world()
    s.book[2].isOffSpec=true; s.book[3].isPassive=true; s.book[4].itemType=2; s.known[8004]=false
    local before,bindings=copy(s.actions),copy(s.bindings); s.setup()
    for _,slot in ipairs({2,3,4,7}) do expect(equal(before[slot],s.actions[slot])) end
    expect(s.bindings.E == bindings.E and not s.actions[7])
end)
test("unknown future higher rank never replaces a learned entry",function()
    local s=world(); s.learn("Flame Shock",99902,9,60)
    s.book[#s.book].itemType=2; s.known[99902]=false
    s.setup(); expect(equal(s.actions[2],{"spell",8050}))
end)
test("occupied items, macros and unrelated spells move only to empty visible utility slots",function()
    local s=world(); s.actions[7]={"spell",556}; s.actions[8]={"item",118}; s.actions[170]={"macro",7}
    s.command("preview"); expect(s.contains("MOVE existing"))
    local before=copy(s.actions); s.setup()
    for _,index in ipairs({7,8,12}) do
        local entry=s.env.ShamanBarsBackup.entries[index]
        expect(entry.moveTo and equal(s.actions[entry.moveTo],before[entry.slot]),"original action not preserved")
    end
    expect(equal(s.actions[49],before[49]) and equal(s.actions[61],before[61]))
end)
test("no visible utility space fails preparation without any partial changes",function()
    local s=world(); s.actions[7]={"spell",556}
    s.env.MultiBarBottomLeft.shown=false; s.env.MultiBarBottomRight.shown=false
    s.command("prepare")
    expect(#s.writes == 0 and not s.env.ShamanBarsBackup and s.contains("No empty visible utility slots"))
end)
test("an additional visible default bar preserves overflowing utility actions and restores them",function()
    local s=world(); s.actions[7]={"spell",556}
    s.env.MultiBarBottomLeft.shown=false; s.env.MultiBarBottomRight.shown=false
    s.extraUtility()
    local original=copy(s.actions); s.setup()
    expect(s.env.ShamanBarsBackup.entries[7].moveTo == 145)
    expect(equal(s.actions[145],{"spell",556}) and equal(s.actions[7],{"spell",8004}))
    s.command("restore")
    expect(equal(original,s.actions) and s.env.ShamanBarsBackup.state == "restored")
end)
test("disabled or visibility-hidden additional bars never receive utility actions",function()
    for _,condition in ipairs({"disabled","hidden"}) do
        local s=world(); s.actions[7]={"spell",556}
        s.env.MultiBarBottomLeft.shown=false; s.env.MultiBarBottomRight.shown=false
        s.extraUtility()
        if condition == "disabled" then s.env.MultiBar5.shown=false
        else s.env.MultiBar5.hiddenByVisibility=true end
        s.command("prepare")
        expect(#s.writes == 0 and not s.env.ShamanBarsBackup and s.contains("No empty visible utility slots"))
    end
end)
test("additional utility bars preserve occupied buttons and must stay visible through application",function()
    local s=world(); s.actions[7]={"spell",556}
    s.env.MultiBarBottomLeft.shown=false; s.env.MultiBarBottomRight.shown=false
    s.extraUtility(); s.actions[145]={"item",117}
    s.command("prepare"); s.load()
    expect(s.env.ShamanBarsBackup.entries[7].moveTo == 146)
    s.env.MultiBar5.hiddenByVisibility=true; s.command("apply")
    expect(#s.writes == 0 and s.contains("Utility bar mapping changed"))
    s.env.MultiBar5.hiddenByVisibility=nil; s.command("apply")
    expect(equal(s.actions[145],{"item",117}) and equal(s.actions[146],{"spell",556}))
end)
test("an enabled secondary bar hidden by visibility rules is not treated as visible",function()
    local s=world(); s.env.MultiBar7.hiddenByVisibility=true
    s.command("prepare"); expect(not s.env.ShamanBarsBackup and #s.writes == 0)
end)
test("enabled-but-hidden utility bars cannot receive preserved actions",function()
    local s=world(); s.actions[7]={"spell",556}
    s.env.MultiBarBottomLeft.hiddenByVisibility=true
    s.env.MultiBarBottomRight.hiddenByVisibility=true
    s.command("prepare")
    expect(#s.writes == 0 and not s.env.ShamanBarsBackup and s.contains("No empty visible utility slots"))
end)
test("apply/restore recovers all original actions and exact primary/secondary binding order",function()
    local s=world(); s.actions[7]={"spell",556}; s.actions[8]={"item",118}; s.actions[170]={"macro",7}
    local actions,bindings,order=copy(s.actions),copy(s.bindings),copy(s.order)
    s.setup(); s.command("restore")
    expect(equal(actions,s.actions),"actions not restored")
    expect(equal(bindings,s.bindings),"key actions not restored")
    for command,keys in pairs(order) do expect(equal(keys,s.order[command]),"binding order not restored") end
    expect(s.env.ShamanBarsBackup.state == "restored")
end)
test("persisted pre-apply snapshot restores after simulated crash before post-apply reload",function()
    local s=world(); s.actions[7]={"spell",556}; local actions=copy(s.actions)
    s.command("prepare"); local disk=copy(s.env.ShamanBarsBackup); s.load(); s.command("apply")
    s.env.ShamanBarsBackup=disk; s.load(); s.command("restore")
    expect(equal(actions,s.actions),"durable prepared backup could not restore")
end)
test("restore preserves a later unrelated replacement by refusing the whole operation",function()
    local s=world(); s.setup(); s.actions[2]={"item",118}
    local actions,bindings,writes=copy(s.actions),copy(s.bindings),#s.writes
    s.command("restore")
    expect(equal(actions,s.actions) and equal(bindings,s.bindings) and #s.writes == writes)
    expect(s.contains("Target changed to an unrelated action"))
end)
test("a reserved utility slot filled after preparation blocks all application",function()
    local s=world(); s.actions[7]={"spell",556}; s.command("prepare"); s.load()
    local destination=s.env.ShamanBarsBackup.entries[7].moveTo; s.actions[destination]={"item",117}
    local actions=copy(s.actions); s.command("apply")
    expect(#s.writes == 0 and equal(actions,s.actions) and s.contains("Reserved utility slot changed"))
end)
test("removing original utility action before it is relocated does not discard its backup",function()
    local s=world(); s.actions[7]={"spell",556}; s.command("prepare"); s.load(); s.actions[7]=nil
    s.command("apply")
    expect(#s.writes == 0 and s.contains("Moved action is missing"))
end)
test("legacy snapshot blocks new applies until explicit recovery",function()
    local s=world(); s.env.ShamanBarsBackup={version=1,slots={[61]=8004},keys={Q="MULTIACTIONBAR1BUTTON1"}}
    s.command("apply"); s.command("prepare")
    expect(#s.writes == 0 and s.env.ShamanBarsBackup.version == 1)
end)
test("legacy recovery restores old utility slots and keys not in the new plan, retaining original data",function()
    local s=world()
    local legacy={version=1,slots={[2]=403,[61]=8004},keys={Q="MULTIACTIONBAR1BUTTON1",["SHIFT-G"]="TARGETLASTHOSTILE"}}
    s.env.ShamanBarsBackup=copy(legacy); s.actions[2]={"spell",8050}; s.actions[61]={"spell",8075}
    s.bind("Q","ACTIONBUTTON6"); s.bind("SHIFT-G","MULTIACTIONBAR1BUTTON6")
    s.command("restore")
    expect(equal(s.actions[2],{"spell",403}) and equal(s.actions[61],{"spell",8004}))
    expect(s.bindings.Q == "MULTIACTIONBAR1BUTTON1" and s.bindings["SHIFT-G"] == "TARGETLASTHOSTILE")
    expect(equal(s.env.ShamanBarsOriginalBackup,legacy),"known-good legacy snapshot overwritten")
    s.command("prepare")
    expect(s.env.ShamanBarsBackup.version == 2 and equal(s.env.ShamanBarsOriginalBackup,legacy))
end)
test("legacy recovery does not overwrite unrelated current items",function()
    local s=world(); s.env.ShamanBarsBackup={version=1,slots={[61]=8004},keys={Q="MULTIACTIONBAR1BUTTON1"}}
    s.actions[61]={"item",118}; s.command("restore")
    expect(#s.writes == 0 and equal(s.actions[61],{"item",118}))
end)
test("legacy recovery rejects corrupt slots outside the old owned ranges",function()
    local s=world(); s.env.ShamanBarsBackup={version=1,slots={[120]=8004},keys={}}
    s.command("restore"); expect(#s.writes == 0 and s.contains("Invalid legacy slot"))
end)
for _,condition in ipairs({"class","combat","cursor","page","override","vehicle","shapeshift",
    "hidden-secondary","multirow","cached-mismatch","overlapping-slot"}) do
    test("unsafe context fails closed: "..condition,function()
        local s=world()
        if condition == "class" then s.class="MAGE"
        elseif condition == "combat" then s.combat=true
        elseif condition == "cursor" then s.cursor={"item",118}
        elseif condition == "page" then s.page=2
        elseif condition == "override" then s.override=true
        elseif condition == "vehicle" then s.vehicle=true
        elseif condition == "shapeshift" then s.shapeshift=true
        elseif condition == "hidden-secondary" then s.env.MultiBar7.shown=false
        elseif condition == "multirow" then s.env.MultiBar7.numRows=2
        elseif condition == "cached-mismatch" then s.env.MultiBar7Button1.action=70
        else s.env.MultiBar7Button1.action=1; s.env.MultiBar7Button1.calculated=1 end
        local cursor=copy(s.cursor); s.command("prepare"); s.command("apply")
        expect(#s.writes == 0 and not s.env.ShamanBarsBackup and equal(cursor,s.cursor))
    end)
end
test("bar paging/mapping changes after snapshot block all writes",function()
    local s=world(); s.command("prepare"); s.load()
    s.env.MultiBar7Button1.action=145; s.env.MultiBar7Button1.calculated=145
    s.command("apply")
    expect(#s.writes == 0 and s.contains("Bar mapping changed since backup"))
end)
test("target slots cannot alias another visible bar's actions",function()
    local s=world()
    local other={IsVisible=function() return true end}
    s.env.MultiBar5=other
    s.env.MultiBar5Button1={bar=other,action=169,CalculateAction=function() return 169 end}
    s.command("prepare")
    expect(#s.writes == 0 and not s.env.ShamanBarsBackup and s.contains("share an action slot"))
end)
test("secondary targets cannot overwrite protected main buttons 11-12 through aliasing",function()
    local s=world()
    for i=1,12 do
        s.env["MultiBar7Button"..i].action=10+i
        s.env["MultiBar7Button"..i].calculated=10+i
    end
    s.command("prepare")
    expect(#s.writes == 0 and not s.env.ShamanBarsBackup and s.contains("share an action slot"))
end)
test("another addon's override binding blocks all application",function()
    local s=world(); s.command("prepare"); s.load(); s.overrideKey="Q"; s.command("apply")
    expect(#s.writes == 0 and s.contains("Another addon overrides Q"))
end)
test("new uncaptured shortcuts on affected commands are not erased",function()
    local s=world(); s.command("prepare"); s.load(); s.bind("F12","ACTIONBUTTON6"); s.command("apply")
    expect(#s.writes == 0 and s.bindings.F12 == "ACTIONBUTTON6" and s.contains("Bindings changed since"))
end)
test("silent pickup failure is detected and existing action is not accepted as success",function()
    local s=world(); local before=copy(s.actions); s.pickupFails[2]=true; s.setup()
    expect(equal(before,s.actions) and s.contains("Spell pickup failed") and s.env.ShamanBarsBackup)
end)
test("silent placement failure is detected and transaction rolls back outside combat",function()
    local s=world(); local before=copy(s.actions); s.placeFails[2]=true; s.setup()
    expect(equal(before,s.actions) and s.contains("Placed spell ID does not match"))
end)
test("binding failure triggers rollback instead of leaving a mixed layout",function()
    local s=world(); local actions,bindings=copy(s.actions),copy(s.bindings)
    s.bindingFailures.Q=1; s.setup()
    expect(equal(actions,s.actions) and equal(bindings,s.bindings) and s.contains("Apply stopped"))
end)
test("save failure is reported and rolled back without touching account bindings",function()
    local s=world(); local actions,bindings=copy(s.actions),copy(s.bindings)
    s.saveFailure=true; s.setup()
    expect(equal(actions,s.actions) and equal(bindings,s.bindings) and s.contains("Could not save character bindings"))
    expect(equal(bindings,s.savedAccount))
end)
test("combat starting during pickup stops placement and never queues a retry",function()
    local s=world(); local before=copy(s.actions); s.combatAfterPickup=true; s.setup()
    expect(equal(before,s.actions) and not s.combatWrites)
    for _,write in ipairs(s.writes) do expect(write[1] == "pickup") end
    local writes=#s.writes; s.combat=false; expect(#s.writes == writes)
end)
test("combat after placement prevents bindings, saves and automatic rollback",function()
    local s=world(); s.combatAfterPlacement=true; s.setup()
    expect(not s.combatWrites and #s.saves == 0 and s.contains("No deferred changes"))
end)
test("debug records actual visible slots, learned IDs and key order without bar/binding writes",function()
    local s=world(); s.command("debug")
    expect(#s.writes == 0 and not s.env.ShamanBarsBackup and s.env.ShamanBarsDiagnostics)
    expect(s.contains("MultiBar7Button1 slot=169") and s.contains("MultiBarBottomLeftButton1 slot=61"))
    expect(s.env.ShamanBarsDiagnostics.spells.lesser.id == 8004)
    expect(s.env.ShamanBarsDiagnostics.bars[1].buttons[1].actionName == "Attack")
end)
test("snapshot cannot be overwritten by preparing a second time",function()
    local s=world(); s.command("prepare"); local before=copy(s.env.ShamanBarsBackup)
    s.actions[2]={"spell",8050}; s.command("prepare")
    expect(equal(before,s.env.ShamanBarsBackup) and s.contains("will not be overwritten"))
end)
test("missing client API fails before preparing or changing configuration",function()
    local s=world(); s.env.C_Spell.GetSpellName=nil; s.command("prepare"); s.command("apply")
    expect(#s.writes == 0 and not s.env.ShamanBarsBackup and s.contains("Required Forever API"))
end)
test("restore without snapshot reports no fabricated recovery",function()
    local s=world(); s.command("restore")
    expect(#s.writes == 0 and s.contains("No snapshot exists"))
end)

realPrint(string.format("RESULT: %d tests, %d failures",tests,failures))
io.stdout:flush()
return tests,failures
