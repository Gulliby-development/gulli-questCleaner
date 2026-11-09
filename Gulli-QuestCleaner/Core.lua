-- Gulli-QuestCleaner: abandon low-level quests and delete quest items nothing needs.
-- WoW Forever runs Vanilla content on the Retail engine, so this uses the Retail API
-- (C_QuestLog, C_Container, C_Item) with fallbacks to the old globals.

local ADDON, ns = ...
local L = ns.L

local ITEM_CLASS_QUEST = 12 -- Enum.ItemClass.Questitem

-- Quest-class items that stay useful after their quest: dungeon keys, attunements,
-- raid summoning items. Never offered for deletion.
local PERMANENT = {
    [16309] = true, -- Drakefire Amulet (Onyxia's Lair)
    [12344] = true, -- Seal of Ascension (Upper Blackrock Spire)
    [17333] = true, -- Aqual Quintessence (Molten Core runes)
    [22754] = true, -- Eternal Quintessence
    [9240] = true,  -- Mallet of Zul'Farrak
    [17191] = true, -- Scepter of Celebras
    [11000] = true, -- Shadowforge Key
    [11140] = true, -- Prison Cell Key
    [18249] = true, -- Crescent Key
    [18250] = true, -- Gordok Shackle Key
    [18266] = true, -- Gordok Courtyard Key
    [18268] = true, -- Gordok Inner Door Key
    [13704] = true, -- Skeleton Key (Scholomance)
    [12382] = true, -- Key to the City (Stratholme)
    [7146] = true,  -- The Scarlet Key
    [5396] = true,  -- Key to Searing Gorge
    [6893] = true,  -- Workshop Key (Gnomeregan)
    [6948] = true,  -- Hearthstone
}

local function db()
    GulliQuestCleanerDB = GulliQuestCleanerDB or {}
    local d = GulliQuestCleanerDB
    d.keep = d.keep or {}
    return d
end
ns.db = db

function ns.Print(msg)
    print("|cff9ad0ffGulli-QuestCleaner|r: " .. msg)
end

---- Quests --------------------------------------------------------------------

local function numEntries()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        return C_QuestLog.GetNumQuestLogEntries() or 0
    end
    return (GetNumQuestLogEntries()) or 0
end

local function entry(index)
    if C_QuestLog and C_QuestLog.GetInfo then
        local info = C_QuestLog.GetInfo(index)
        if not info then return nil end
        return info.title, info.level, info.isHeader, info.isHidden, info.questID
    end
    local title, level, _, isHeader, _, _, _, questID = GetQuestLogTitle(index)
    return title, level, isHeader, false, questID
end

-- Every quest in the log: { questID, title, level, index }.
function ns.Quests()
    local out = {}
    for i = 1, numEntries() do
        local title, level, isHeader, isHidden, questID = entry(i)
        if title and not isHeader and not isHidden and questID and questID > 0 then
            out[#out + 1] = { questID = questID, title = title, level = level or 0, index = i }
        end
    end
    return out
end

local function inLog(questID)
    for _, q in ipairs(ns.Quests()) do
        if q.questID == questID then return q end
    end
end

-- All text of a quest (objectives, summary, description), lowercased, to find the
-- items it asks for by name; plus the item ids of its usable quest item.
local function questNeeds(q, text, ids)
    if C_QuestLog and C_QuestLog.GetQuestObjectives then
        for _, o in ipairs(C_QuestLog.GetQuestObjectives(q.questID) or {}) do
            if o.text then text[#text + 1] = o.text end
        end
    end
    local prev = C_QuestLog and C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()
    if C_QuestLog and C_QuestLog.SetSelectedQuest then
        C_QuestLog.SetSelectedQuest(q.questID)
    elseif SelectQuestLogEntry then
        SelectQuestLogEntry(q.index)
    end
    if GetQuestLogQuestText then
        local desc, objectives = GetQuestLogQuestText(q.index)
        text[#text + 1] = desc or ""
        text[#text + 1] = objectives or ""
    end
    if C_QuestLog and C_QuestLog.SetSelectedQuest then C_QuestLog.SetSelectedQuest(prev or 0) end
    if GetQuestLogSpecialItemInfo then
        local link = GetQuestLogSpecialItemInfo(q.index)
        local id = link and tonumber(link:match("item:(%d+)"))
        if id then ids[id] = true end
    end
end

local function needsOf(quests)
    local text, ids = {}, {}
    for _, q in ipairs(quests) do questNeeds(q, text, ids) end
    return table.concat(text, "\n"):lower(), ids
end

local function needed(item, blob, ids)
    if ids[item.itemID] then return true end
    return item.name ~= "" and blob:find(item.name:lower(), 1, true) ~= nil
end

---- Bags ----------------------------------------------------------------------

local function lastBag()
    return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
end

local function slotInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local i = C_Container.GetContainerItemInfo(bag, slot)
        if not i then return nil end
        return i.itemID, i.hyperlink, i.stackCount, i.isLocked, i.iconFileID, i.itemName
    end
    local icon, count, locked, _, _, _, link, _, _, id = GetContainerItemInfo(bag, slot)
    return id, link, count, locked, icon
end
ns.SlotInfo = slotInfo

local function numSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag) or 0
    end
    return GetContainerNumSlots(bag) or 0
end

local function questInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemQuestInfo then
        local q = C_Container.GetContainerItemQuestInfo(bag, slot)
        if q then return q.isQuestItem, q.questID, q.isActive end
        return
    end
    if GetContainerItemQuestInfo then return GetContainerItemQuestInfo(bag, slot) end
end

local function classOf(itemID)
    local getInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local _, _, _, _, _, classID = getInstant(itemID)
    return classID
end

local function questDone(questID)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(questID)
    end
    return IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(questID)
end

-- Quest items in the bags: { bag, slot, itemID, link, name, count, icon, starts }.
local function bagQuestItems()
    local out = {}
    for bag = 0, lastBag() do
        for slot = 1, numSlots(bag) do
            local id, link, count, _, icon, name = slotInfo(bag, slot)
            if id then
                local isQuestItem, startsQuest = questInfo(bag, slot)
                if classOf(id) == ITEM_CLASS_QUEST or isQuestItem or startsQuest then
                    name = name or (link and link:match("%[(.-)%]")) or ""
                    out[#out + 1] = { bag = bag, slot = slot, itemID = id, link = link, name = name,
                                      count = count or 1, icon = icon, starts = startsQuest }
                end
            end
        end
    end
    return out
end

---- Plan ----------------------------------------------------------------------

-- Quests at or below maxLevel, each ticked.
function ns.PlanQuests(maxLevel)
    local out = {}
    for _, q in ipairs(ns.Quests()) do
        if q.level > 0 and q.level <= maxLevel then
            q.checked = true
            out[#out + 1] = q
        end
    end
    table.sort(out, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return a.title < b.title
    end)
    return out
end

-- Quest items that only the planned quests need, or no quest at all. Each item
-- lists the planned quests that need it (links). Quests outside the plan stay,
-- so their items are never offered. Items the player kept before stay out.
function ns.PlanItems(planned)
    local inPlan = {}
    for _, q in ipairs(planned or {}) do
        local text, ids = {}, {}
        questNeeds(q, text, ids)
        q.blob, q.ids = table.concat(text, "\n"):lower(), ids
        inPlan[q.questID] = true
    end
    local staying = {}
    for _, q in ipairs(ns.Quests()) do
        if not inPlan[q.questID] then staying[#staying + 1] = q end
    end
    local keepBlob, keepIds = needsOf(staying)
    local keep = db().keep

    local out = {}
    for _, it in ipairs(bagQuestItems()) do
        if not PERMANENT[it.itemID] and not keep[it.itemID] then
            it.links = {}
            if it.starts then
                if questDone(it.starts) then
                    it.why = "WHY_DONE"
                    out[#out + 1] = it
                end
            elseif not needed(it, keepBlob, keepIds) then
                for _, q in ipairs(planned or {}) do
                    if needed(it, q.blob, q.ids) then it.links[#it.links + 1] = q end
                end
                it.why = #it.links > 0 and "WHY_ABANDONED" or "WHY_NO_QUEST"
                out[#out + 1] = it
            end
            it.checked = true
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- An item goes only when the player ticked it and every quest it is for goes too.
function ns.ItemGoes(it)
    if not it.checked then return false end
    for _, q in ipairs(it.links or {}) do
        if not q.checked then return false end
    end
    return true
end

---- Run -----------------------------------------------------------------------

local function abandon(q)
    if C_QuestLog and C_QuestLog.SetAbandonQuest then
        C_QuestLog.SetSelectedQuest(q.questID)
        C_QuestLog.SetAbandonQuest()
        C_QuestLog.AbandonQuest()
    else
        local now = inLog(q.questID)
        if not now then return end
        SelectQuestLogEntry(now.index)
        SetAbandonQuest()
        AbandonQuest()
    end
end

local function cursorItemID()
    local kind, id = GetCursorInfo()
    if kind == "item" then return id end
end

local function pickup(bag, slot)
    if C_Container and C_Container.PickupContainerItem then
        C_Container.PickupContainerItem(bag, slot)
    else
        PickupContainerItem(bag, slot)
    end
end

-- Runs from the OK click: the game lets an addon delete a picked-up item only
-- inside a hardware event. Returns quests abandoned and stacks deleted; whatever
-- the game refused stays and is offered again.
function ns.Run(quests, items)
    if InCombatLockdown() then
        ns.Print(L.IN_COMBAT)
        return 0, 0
    end
    ClearCursor()
    local abandoned, deleted = 0, 0
    for _, q in ipairs(quests or {}) do
        if q.checked and inLog(q.questID) then
            abandon(q)
            abandoned = abandoned + 1
        end
    end
    for _, it in ipairs(items or {}) do
        if ns.ItemGoes(it) then
            local id, _, _, locked = slotInfo(it.bag, it.slot)
            if id == it.itemID and not locked then
                pickup(it.bag, it.slot)
                if cursorItemID() ~= it.itemID then
                    ClearCursor()
                    break
                end
                DeleteCursorItem()
                if GetCursorInfo() then
                    ClearCursor()
                    break
                end
                deleted = deleted + 1
            end
        end
    end
    return abandoned, deleted
end

-- What is still there of a plan after a run: ticked quests still in the log and
-- ticked items still in their slot.
function ns.Leftover(quests, items)
    local q2, i2 = {}, {}
    for _, q in ipairs(quests or {}) do
        if q.checked and inLog(q.questID) then q2[#q2 + 1] = q end
    end
    for _, it in ipairs(items or {}) do
        if ns.ItemGoes(it) and slotInfo(it.bag, it.slot) == it.itemID then i2[#i2 + 1] = it end
    end
    return q2, i2
end

---- Setup ---------------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
    if name ~= ADDON then return end
    f:UnregisterEvent("ADDON_LOADED")
    local d = db()
    if d.quests == nil then d.quests = true end
    if d.items == nil then d.items = true end
    ns.SetLanguage(d.lang)
end)

SLASH_GULLIQUESTCLEANER1 = "/gqc"
SLASH_GULLIQUESTCLEANER2 = "/questcleaner"
SlashCmdList.GULLIQUESTCLEANER = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "reset" then
        wipe(db().keep)
        ns.Print(L.KEEP_RESET)
    elseif msg == "help" then
        ns.Print(L.HELP)
    else
        ns.Toggle()
    end
end

function GulliQuestCleaner_Toggle()
    ns.Toggle()
end
