-- A fake WoW client for tests: just the API Gulli-QuestCleaner calls.
-- Fake{ quests = {...}, texts = {...}, bag = {...}, locale = "enUS" } sets the globals,
-- Load() runs the addon files on it and returns the addon table.

local W = {}

local function stub()
    return setmetatable({}, { __index = function(t, k)
        if k == "TitleText" then return nil end
        if k == "GetWidth" then return function() return 616 end end
        if k == "GetHeight" then return function() return 32 end end
        if k == "IsShown" or k == "IsEnabled" then return function() return true end end
        if k == "GetChecked" then return function() return true end end
        if k == "GetText" then return function() return rawget(t, "_text") end end
        if k == "SetText" then return function(_, v) rawset(t, "_text", v) end end
        if k == "SetScript" then return function(_, n, f) rawset(t, "_" .. n, f) end end
        return function() return stub() end
    end })
end

function Fake(spec)
    W.quests = spec.quests or {}
    W.texts = spec.texts or {}
    W.bag = spec.bag or {}
    W.done = spec.done or {}
    W.abandoned = {}
    W.selected = 0
    W.cursor = nil
    W.frames = {}
    W.printed = {}
    W.combat, W.refuseDelete = false, false

    C_QuestLog = {
        GetNumQuestLogEntries = function() return #W.quests end,
        GetInfo = function(i)
            local q = W.quests[i]
            if not q then return nil end
            if q.questID and W.abandoned[q.questID] then return { title = "", isHeader = true } end
            return q
        end,
        GetQuestObjectives = function(id)
            for _, q in ipairs(W.quests) do
                if q.questID == id then return q.objectives or {} end
            end
        end,
        GetSelectedQuest = function() return W.selected end,
        SetSelectedQuest = function(id) W.selected = id end,
        SetAbandonQuest = function() end,
        AbandonQuest = function() W.abandoned[W.selected] = true end,
        IsQuestFlaggedCompleted = function(id) return W.done[id] == true end,
    }
    GetQuestLogQuestText = function(i)
        local q = W.quests[i]
        if q then return q.description, q.summary end
    end
    GetQuestLogSpecialItemInfo = function(i)
        local q = W.quests[i]
        return q and q.special and ("|Hitem:" .. q.special .. "|h[x]|h") or nil
    end
    NUM_BAG_SLOTS = 4
    NUM_TOTAL_EQUIPPED_BAG_SLOTS = nil
    C_Container = {
        GetContainerNumSlots = function(b) return b == 0 and #W.bag or 0 end,
        GetContainerItemInfo = function(b, s)
            local it = b == 0 and W.bag[s]
            if not it or it.gone then return nil end
            return { itemID = it.id, hyperlink = "|cffffffff|Hitem:" .. it.id .. "|h[" .. it.name .. "]|h|r",
                     stackCount = it.count or 1, isLocked = false, iconFileID = 1 }
        end,
        GetContainerItemQuestInfo = function(b, s)
            local it = W.bag[s]
            return { isQuestItem = it and it.questItem or false, questID = it and it.starts }
        end,
        PickupContainerItem = function(b, s) W.cursor = s end,
    }
    C_Item = { GetItemInfoInstant = function(id)
        for _, it in ipairs(W.bag) do
            if it.id == id then return id, nil, nil, nil, nil, it.class end
        end
    end }
    GetCursorInfo = function() if W.cursor then return "item", W.bag[W.cursor].id end end
    ClearCursor = function() W.cursor = nil end
    DeleteCursorItem = function()
        if W.refuseDelete then return end
        W.bag[W.cursor].gone = true
        W.cursor = nil
    end
    InCombatLockdown = function() return W.combat == true end
    GetLocale = function() return spec.locale or "enUS" end
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    SlashCmdList = {}
    CreateFrame = function() local f = stub(); W.frames[#W.frames + 1] = f; return f end
    UIParent, GameTooltip, UISpecialFrames = stub(), stub(), {}
    tinsert = table.insert
    UnitLevel = function() return spec.level or 40 end
    GetQuestDifficultyColor = function() return { r = 1, g = 0.5, b = 0 } end
    C_Timer = { After = function(_, f) f() end }
    print = function(...) W.printed[#W.printed + 1] = table.concat({ ... }, " ") end
    GulliQuestCleanerDB = spec.db
    return W
end

function Load(dir)
    dir = dir or "Gulli-QuestCleaner/"
    local ns = {}
    for _, f in ipairs({ "Locales.lua", "Core.lua", "UI.lua" }) do
        assert(loadfile(dir .. f))("Gulli-QuestCleaner", ns)
    end
    for _, f in ipairs(W.frames) do
        local onEvent = rawget(f, "_OnEvent")
        if onEvent then onEvent(f, "ADDON_LOADED", "Gulli-QuestCleaner") end
    end
    return ns
end

-- Buttons of the built window, found by their text or a field.
function Find(test)
    for _, f in ipairs(W.frames) do
        if test(f) then return f end
    end
end

return W
