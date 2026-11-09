local _, ns = ...
local L = ns.L

-- Preview: quests on the left, items on the right, a line from each quest to the
-- items it needs. Items no quest needs hang off a "no quest" label at the end.
local W = 660
local SETUP_H, PREVIEW_H = 200, 480
local ROW_H = 32
local LEFT_W, GAP = 250, 56
local GOLD = { 1, 0.82, 0, 0.85 }
local DIM = { 0.55, 0.55, 0.55, 0.35 }
local GREY = "|cff9d9d9d"

local frame, setup, preview, status, summary
local edit, checkQuests, checkItems
local scroll, content, okButton, backButton, questHead, itemHead
local plan = { quests = {}, items = {} }
local totals = { quests = 0, items = 0 }
local pools = { quest = {}, item = {}, label = {}, line = {}, band = {} }
local used = {}

local function setStatus(text) status:SetText(text or "") end

---- Pools ---------------------------------------------------------------------

local function take(kind, make)
    used[kind] = (used[kind] or 0) + 1
    local p = pools[kind]
    local o = p[used[kind]]
    if not o then
        o = make()
        p[used[kind]] = o
    end
    o:Show()
    return o
end

local function releaseAll()
    for kind, p in pairs(pools) do
        for i = 1, #p do p[i]:Hide() end
        used[kind] = 0
    end
end

local refresh

local function hover(r)
    local h = r:CreateTexture(nil, "HIGHLIGHT")
    h:SetAllPoints()
    h:SetColorTexture(1, 1, 1, 0.07)
end

local function newCheck(parent)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(26, 26)
    c:SetPoint("LEFT", 2, 0)
    return c
end

local function makeQuestRow()
    local r = CreateFrame("Button", nil, content)
    r:SetSize(LEFT_W, ROW_H)
    hover(r)
    r.check = newCheck(r)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.text:SetPoint("LEFT", r.check, "RIGHT", 2, 0)
    r.text:SetPoint("RIGHT", -4, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    r:SetScript("OnClick", function(self) self.check:Click() end)
    r.check:SetScript("OnClick", function(self)
        r.data.checked = self:GetChecked() and true or false
        refresh()
    end)
    return r
end

local function makeItemRow()
    local r = CreateFrame("Button", nil, content)
    r:SetHeight(ROW_H)
    hover(r)
    r.check = newCheck(r)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(22, 22)
    r.icon:SetPoint("LEFT", r.check, "RIGHT", 2, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.text:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 6, 1)
    r.text:SetPoint("RIGHT", -4, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.sub:SetPoint("TOPLEFT", r.text, "BOTTOMLEFT", 0, -2)
    r.sub:SetPoint("RIGHT", -4, 0)
    r.sub:SetJustifyH("LEFT")
    r.sub:SetWordWrap(false)
    r:SetScript("OnClick", function(self)
        if self.check:IsEnabled() then self.check:Click() end
    end)
    r.check:SetScript("OnClick", function(self)
        r.data.checked = self:GetChecked() and true or false
        refresh()
    end)
    r:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(self.data.bag, self.data.slot)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

local function makeLabel()
    local r = CreateFrame("Frame", nil, content)
    r:SetSize(LEFT_W, ROW_H)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    r.text:SetPoint("LEFT", 32, 0)
    r.text:SetPoint("RIGHT", -4, 0)
    r.text:SetJustifyH("LEFT")
    return r
end

local function makeLine()
    local l = content:CreateLine(nil, "BACKGROUND")
    l:SetThickness(2)
    return l
end

local function makeBand()
    local t = content:CreateTexture(nil, "BACKGROUND", nil, -1)
    t:SetColorTexture(1, 1, 1, 0.035)
    return t
end

---- Drawing -------------------------------------------------------------------

local function levelText(level)
    local c = GetQuestDifficultyColor and GetQuestDifficultyColor(level)
    local hex = c and string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) or GREY
    return hex .. "[" .. level .. "]|r "
end

local function connect(from, to, on)
    local l = take("line", makeLine)
    l:SetStartPoint("RIGHT", from, 0, 0)
    l:SetEndPoint("LEFT", to, 0, 0)
    l:SetColorTexture(unpack(on and GOLD or DIM))
end

local function placeItem(it, y, rightX, width)
    local r = take("item", makeItemRow)
    r.data = it
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", rightX, -y)
    r:SetWidth(width)
    local blocked = false
    for _, q in ipairs(it.links) do
        if not q.checked then blocked = true end
    end
    r.check:SetChecked(it.checked and not blocked)
    r.check:SetEnabled(not blocked)
    r.icon:SetTexture(it.icon)
    r.text:SetText((it.link or it.name) .. (it.count > 1 and (GREY .. " x" .. it.count .. "|r") or ""))
    r.sub:SetText(blocked and L.WHY_QUEST_STAYS or it.why or "")
    r:SetAlpha(ns.ItemGoes(it) and 1 or 0.5)
    return r
end

refresh = function()
    releaseAll()
    local width = content:GetWidth()
    local rightX = LEFT_W + GAP
    local rightW = width - rightX

    local first = {}   -- item -> the quest it is listed under
    local byQuest = {}
    for _, q in ipairs(plan.quests) do byQuest[q] = {} end
    local orphans = {}
    for _, it in ipairs(plan.items) do
        local home
        for _, q in ipairs(it.links) do
            if byQuest[q] then home = q break end
        end
        if home then
            first[it] = home
            table.insert(byQuest[home], it)
        else
            orphans[#orphans + 1] = it
        end
    end

    local y, odd = 0, true
    local questRow, itemRow = {}, {}
    local function block(left, items, band)
        local h = math.max(1, #items) * ROW_H
        if band then
            local b = take("band", makeBand)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 0, -y)
            b:SetSize(width, h)
        end
        left:ClearAllPoints()
        left:SetPoint("TOPLEFT", 0, -y)
        for i, it in ipairs(items) do
            itemRow[it] = placeItem(it, y + (i - 1) * ROW_H, rightX, rightW)
        end
        y = y + h + 4
    end

    for _, q in ipairs(plan.quests) do
        local r = take("quest", makeQuestRow)
        r.data = q
        r.check:SetChecked(q.checked)
        r.text:SetText(levelText(q.level) .. q.title)
        r:SetAlpha(q.checked and 1 or 0.5)
        questRow[q] = r
        block(r, byQuest[q], odd)
        odd = not odd
    end
    if #orphans > 0 then
        local label = take("label", makeLabel)
        label.text:SetText(L.NO_QUEST)
        block(label, orphans, odd)
        for _, it in ipairs(orphans) do connect(label, itemRow[it], ns.ItemGoes(it)) end
    end
    -- Every link gets a line, also to quests an item is not listed under.
    for _, it in ipairs(plan.items) do
        for _, q in ipairs(it.links) do
            if questRow[q] and itemRow[it] then connect(questRow[q], itemRow[it], ns.ItemGoes(it)) end
        end
    end
    content:SetHeight(math.max(y, 1))

    local nq, ni = 0, 0
    for _, q in ipairs(plan.quests) do if q.checked then nq = nq + 1 end end
    for _, it in ipairs(plan.items) do if ns.ItemGoes(it) then ni = ni + 1 end end
    questHead:SetText(L.QUESTS_N:format(nq, #plan.quests))
    itemHead:SetText(L.ITEMS_N:format(ni, #plan.items))
    summary:SetText(L.SUMMARY:format(nq, ni))
    okButton:SetEnabled(nq + ni > 0)
end

---- Views ---------------------------------------------------------------------

local function showSetup()
    preview:Hide()
    setup:Show()
    frame:SetHeight(SETUP_H)
    local d = ns.db()
    edit:SetText(tostring(d.level or math.max(1, UnitLevel("player") - 10)))
    checkQuests:SetChecked(d.quests)
    checkItems:SetChecked(d.items)
    setup.level:SetText(GREY .. L.YOUR_LEVEL:format(UnitLevel("player")))
end

local function showPreview()
    setup:Hide()
    preview:Show()
    frame:SetHeight(PREVIEW_H)
    local width = scroll:GetWidth()
    content:SetWidth(width > 0 and width or W - 44)
    scroll:SetVerticalScroll(0)
    refresh()
end

local function onClear()
    local level = tonumber(edit:GetText())
    if not level or level < 1 or level > 99 then
        setStatus(L.BAD_LEVEL)
        return
    end
    local d = ns.db()
    d.level = level
    d.quests = checkQuests:GetChecked() and true or false
    d.items = checkItems:GetChecked() and true or false
    plan.quests = d.quests and ns.PlanQuests(level) or {}
    plan.items = d.items and ns.PlanItems(plan.quests) or {}
    totals.quests, totals.items = 0, 0
    if #plan.quests + #plan.items == 0 then
        setStatus(L.NOTHING)
        return
    end
    setStatus("")
    showPreview()
end

local function onOK()
    local keep = ns.db().keep
    for _, it in ipairs(plan.items) do
        if not it.checked then keep[it.itemID] = true end
    end
    local a, d = ns.Run(plan.quests, plan.items)
    totals.quests = totals.quests + a
    totals.items = totals.items + d
    okButton:Disable()
    backButton:Disable()
    -- Abandons and deletes land a moment later; then see what the game refused.
    C_Timer.After(1, function()
        backButton:Enable()
        local q, i = ns.Leftover(plan.quests, plan.items)
        if #q + #i == 0 then
            local done = L.DONE:format(totals.quests, totals.items)
            ns.Print(done)
            plan.quests, plan.items = {}, {}
            showSetup()
            setStatus(done)
        else
            plan.quests, plan.items = q, i
            showPreview()
            setStatus(L.LEFT:format(#q + #i))
        end
    end)
end

---- Build ---------------------------------------------------------------------

local function button(parent, text, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 100, 30)
    b:SetText(text)
    return b
end

local function checkbox(parent, text)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(26, 26)
    local label = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", c, "RIGHT", 2, 0)
    label:SetText(text)
    return c
end

local function build()
    frame = CreateFrame("Frame", "GulliQuestCleanerFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(W, SETUP_H)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    tinsert(UISpecialFrames, "GulliQuestCleanerFrame")

    local title = frame.TitleText
    if not title then
        title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", 0, -5)
    end
    title:SetText("|cff9ad0ffGulli|r-QuestCleaner")

    status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("BOTTOMLEFT", 16, 20)
    status:SetPoint("RIGHT", -290, 0)
    status:SetJustifyH("LEFT")

    -- Setup view
    setup = CreateFrame("Frame", nil, frame)
    setup:SetAllPoints()

    local label = setup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 18, -42)
    label:SetText(L.LEVEL)
    edit = CreateFrame("EditBox", nil, setup, "InputBoxTemplate")
    edit:SetSize(36, 24)
    edit:SetPoint("LEFT", label, "RIGHT", 10, 0)
    edit:SetAutoFocus(false)
    edit:SetNumeric(true)
    edit:SetMaxLetters(2)
    edit:SetJustifyH("CENTER")
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); onClear() end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local after = setup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    after:SetPoint("LEFT", edit, "RIGHT", 6, 0)
    after:SetText(L.OR_LOWER)
    setup.level = setup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    setup.level:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)

    checkQuests = checkbox(setup, L.DO_QUESTS)
    checkQuests:SetPoint("TOPLEFT", setup.level, "BOTTOMLEFT", -4, -10)
    checkItems = checkbox(setup, L.DO_ITEMS)
    checkItems:SetPoint("TOPLEFT", checkQuests, "BOTTOMLEFT", 0, -2)

    local clear = button(setup, L.CLEAR, 140)
    clear:SetPoint("BOTTOMRIGHT", -14, 12)
    clear:SetScript("OnClick", onClear)

    -- Preview view
    preview = CreateFrame("Frame", nil, frame)
    preview:SetAllPoints()
    preview:Hide()

    questHead = preview:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    questHead:SetPoint("TOPLEFT", 16, -32)
    itemHead = preview:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemHead:SetPoint("TOPLEFT", 14 + LEFT_W + GAP, -32)

    scroll = CreateFrame("ScrollFrame", nil, preview, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -52)
    scroll:SetPoint("BOTTOMRIGHT", -32, 76)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(W - 44, 1)
    scroll:SetScrollChild(content)

    local hint = preview:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 16, 54)
    hint:SetPoint("RIGHT", -16, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText(L.HINT)

    summary = preview:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    summary:SetPoint("BOTTOMLEFT", 16, 36)
    summary:SetPoint("RIGHT", -290, 0)
    summary:SetJustifyH("LEFT")

    okButton = button(preview, L.OK, 140)
    okButton:SetPoint("BOTTOMRIGHT", -14, 12)
    okButton:SetScript("OnClick", onOK)
    backButton = button(preview, L.BACK, 110)
    backButton:SetPoint("RIGHT", okButton, "LEFT", -8, 0)
    backButton:SetScript("OnClick", function()
        setStatus("")
        showSetup()
    end)

    frame:SetScript("OnShow", function() setStatus(""); showSetup() end)
end

function ns.Toggle()
    if not frame then build() end
    frame:SetShown(not frame:IsShown())
end
