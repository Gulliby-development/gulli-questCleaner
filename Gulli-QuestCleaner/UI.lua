local _, ns = ...
local L = ns.L
local S = ns.Skin

-- Two views in one window. Setup: the level and what to clean. Preview: zones
-- and their quests on the left, items on the right, a line from each quest to the items
-- it needs. Items no quest needs hang off a "No quest" label at the end.
local W = 680
local SETUP_H, PREVIEW_H = 214, 520
local TITLE_H = 28
local ROW_H, ZONE_H = 32, 28
local LEFT_W, GAP = 262, 52
local DIM = { 0.55, 0.55, 0.58, 0.35 }

local frame, setup, preview, status, summary
local edit, checkQuests, checkItems
local scroll, content, okButton, backButton, questHead, itemHead
local plan = { quests = {}, items = {} }
local totals = { quests = 0, items = 0 }
local pools = { zone = {}, quest = {}, item = {}, label = {}, line = {}, band = {} }
local used = {}

local function setStatus(text) status:SetText(text or "") end

-- Fixed labels by key, set once the window is built.
local labels = {}
local function say(obj, key)
    labels[#labels + 1] = { obj, key }
    obj:SetText(L[key])
end

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
    h:SetColorTexture(1, 1, 1, 0.05)
end

-- A clickable row with a check box on the left; a click anywhere on it toggles.
local function checkRow(width, height, onToggle)
    local r = CreateFrame("Button", nil, content)
    r:SetSize(width, height)
    hover(r)
    r.check = S.Check(r, 26)
    r.check:SetPoint("LEFT", 2, 0)
    local function toggle()
        if r.locked == true then return end
        onToggle(r)
        refresh()
    end
    r:SetScript("OnClick", toggle)
    r.check:SetScript("OnClick", toggle)
    return r
end

local function makeZoneRow()
    local r = checkRow(LEFT_W, ZONE_H, function(self)
        local all = true
        for _, q in ipairs(self.data.quests) do all = all and q.checked end
        for _, q in ipairs(self.data.quests) do q.checked = not all end
    end)
    r.text = S.Text(r, 13)
    r.text:SetPoint("LEFT", r.check, "RIGHT", 2, 0)
    r.text:SetPoint("RIGHT", -40, 0)
    r.text:SetWordWrap(false)
    r.count = S.Text(r, 11, S.MUTED)
    r.count:SetPoint("RIGHT", -6, 0)
    r.count:SetJustifyH("RIGHT")
    return r
end

local function makeQuestRow()
    local r = checkRow(LEFT_W - 14, ROW_H, function(self) self.data.checked = not self.data.checked end)
    r.text = S.Text(r, 12)
    r.text:SetPoint("LEFT", r.check, "RIGHT", 2, 0)
    r.text:SetPoint("RIGHT", -4, 0)
    r.text:SetWordWrap(false)
    return r
end

local function makeItemRow()
    local r = checkRow(200, ROW_H, function(self) self.data.checked = not self.data.checked end)
    local frameIcon = CreateFrame("Frame", nil, r)
    frameIcon:SetSize(24, 24)
    frameIcon:SetPoint("LEFT", r.check, "RIGHT", 2, 0)
    S.Box(frameIcon, { 0, 0, 0, 1 })
    r.icon = frameIcon:CreateTexture(nil, "ARTWORK")
    r.icon:SetPoint("TOPLEFT", 1, -1)
    r.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.text = S.Text(r, 12)
    r.text:SetPoint("TOPLEFT", frameIcon, "TOPRIGHT", 6, 1)
    r.text:SetPoint("RIGHT", -4, 0)
    r.text:SetWordWrap(false)
    r.sub = S.Text(r, 10, S.MUTED)
    r.sub:SetPoint("TOPLEFT", r.text, "BOTTOMLEFT", 0, -3)
    r.sub:SetPoint("RIGHT", -4, 0)
    r.sub:SetWordWrap(false)
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
    r.text = S.Text(r, 13, S.MUTED)
    r.text:SetPoint("LEFT", 30, 0)
    return r
end

local function makeLine()
    local l = content:CreateLine(nil, "BACKGROUND")
    l:SetThickness(2)
    return l
end

local function makeBand()
    local t = content:CreateTexture(nil, "BACKGROUND", nil, -1)
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    return t
end

---- Drawing -------------------------------------------------------------------

local function levelText(level)
    local c = GetQuestDifficultyColor and GetQuestDifficultyColor(level)
    local hex = c and S.Hex({ c.r, c.g, c.b }) or S.Hex(S.MUTED)
    return hex .. level .. "|r  "
end

local function connect(from, to, on)
    local l = take("line", makeLine)
    l:SetStartPoint("RIGHT", from, 0, 0)
    l:SetEndPoint("LEFT", to, 0, 0)
    local c = on and S.Accent() or DIM
    l:SetColorTexture(c[1], c[2], c[3], on and 0.9 or c[4])
end

local function band(y, h, color)
    local b = take("band", makeBand)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", 0, -y)
    b:SetSize(content:GetWidth(), h)
    b:SetVertexColor(color[1], color[2], color[3], color[4])
end

local function placeItem(it, y, x, width)
    local r = take("item", makeItemRow)
    r.data = it
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", x, -y)
    r:SetWidth(width)
    local blocked = false
    for _, q in ipairs(it.links) do
        if not q.checked then blocked = true end
    end
    r.locked = blocked
    r.check:SetChecked(it.checked and not blocked)
    r.check:SetEnabled(not blocked)
    r.icon:SetTexture(it.icon)
    r.text:SetText((it.link or it.name) .. (it.count > 1 and (S.Hex(S.MUTED) .. "  x" .. it.count .. "|r") or ""))
    r.sub:SetText(L[blocked and "WHY_QUEST_STAYS" or it.why])
    r:SetAlpha(ns.ItemGoes(it) and 1 or 0.45)
    return r
end

refresh = function()
    releaseAll()
    local width = content:GetWidth()
    local rightX = LEFT_W + GAP
    local rightW = width - rightX

    -- Each item is listed under the first planned quest that needs it.
    local byQuest, orphans = {}, {}
    for _, q in ipairs(plan.quests) do byQuest[q] = {} end
    for _, it in ipairs(plan.items) do
        local home
        for _, q in ipairs(it.links) do
            if byQuest[q] then home = q break end
        end
        if home then table.insert(byQuest[home], it) else orphans[#orphans + 1] = it end
    end

    local y = 0
    local questRow, itemRow = {}, {}
    local accent = S.Accent()
    for _, zone in ipairs(ns.Zones(plan.quests)) do
        band(y, ZONE_H, { 1, 1, 1, 0.06 })
        local z = take("zone", makeZoneRow)
        z.data = zone
        z:ClearAllPoints()
        z:SetPoint("TOPLEFT", 0, -y)
        local on = 0
        for _, q in ipairs(zone.quests) do if q.checked then on = on + 1 end end
        z.check:SetChecked(on == #zone.quests or (on > 0 and "some"))
        z.text:SetText(S.Hex(accent) .. (zone.name ~= "" and zone.name or "?") .. "|r")
        z.count:SetText(on .. "/" .. #zone.quests)
        y = y + ZONE_H + 2

        for _, q in ipairs(zone.quests) do
            local items = byQuest[q]
            local h = math.max(1, #items) * ROW_H
            local r = take("quest", makeQuestRow)
            r.data = q
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 14, -y)
            r.check:SetChecked(q.checked)
            r.text:SetText(levelText(q.level) .. q.title)
            r:SetAlpha(q.checked and 1 or 0.45)
            questRow[q] = r
            for i, it in ipairs(items) do
                itemRow[it] = placeItem(it, y + (i - 1) * ROW_H, rightX, rightW)
            end
            y = y + h + 2
        end
        y = y + 6
    end
    if #orphans > 0 then
        band(y, ZONE_H, { 1, 1, 1, 0.06 })
        local label = take("label", makeLabel)
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", 0, -y)
        label:SetHeight(ZONE_H)
        label.text:SetText(L.NO_QUEST)
        y = y + ZONE_H + 2
        for i, it in ipairs(orphans) do
            itemRow[it] = placeItem(it, y + (i - 1) * ROW_H, rightX, rightW)
            connect(label, itemRow[it], ns.ItemGoes(it))
        end
        y = y + #orphans * ROW_H
    end
    for _, it in ipairs(plan.items) do
        for _, q in ipairs(it.links) do
            if questRow[q] and itemRow[it] then connect(questRow[q], itemRow[it], ns.ItemGoes(it)) end
        end
    end
    content:SetHeight(math.max(y, 1))
    scroll:Update(y)

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
    checkQuests:SetChecked(d.quests ~= false)
    checkItems:SetChecked(d.items ~= false)
    setup.level:SetText(L.YOUR_LEVEL:format(UnitLevel("player")))
end

local function showPreview()
    setup:Hide()
    preview:Show()
    frame:SetHeight(PREVIEW_H)
    local width = scroll:GetWidth()
    content:SetWidth(width > 0 and width or W - 40)
    scroll:Top()
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
    d.quests = checkQuests:GetChecked()
    d.items = checkItems:GetChecked()
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

local function button(parent, key, width)
    local b = S.Button(parent, width, 30)
    say(b, key)
    return b
end

local function checkbox(parent, key, onClick)
    local c = S.Check(parent, 26)
    local label = S.Text(c, 13)
    label:SetPoint("LEFT", c, "RIGHT", 2, 0)
    say(label, key)
    c:SetHitRectInsets(0, -(label:GetStringWidth() + 8), 0, 0)
    c:SetScript("OnClick", function(self) self:SetChecked(not self:GetChecked()) end)
    return c
end

local function build()
    local accent = S.Accent()
    frame = CreateFrame("Frame", "GulliQuestCleanerFrame", UIParent)
    S.Box(frame, S.BG)
    frame:SetSize(W, SETUP_H)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()
    tinsert(UISpecialFrames, "GulliQuestCleanerFrame")

    -- Title bar: drag to move, a flat close button.
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", -1, -1)
    bar:SetHeight(TITLE_H)
    S.Box(bar, S.PANEL, { 0, 0, 0, 0 })
    local line = bar:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetVertexColor(accent[1], accent[2], accent[3], 0.8)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(1)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    local title = S.Text(bar, 14)
    title:SetPoint("LEFT", 10, 0)
    title:SetText(S.Hex(accent) .. "Gulli|r-QuestCleaner")
    local close = S.Button(bar, 24, 22)
    close:SetPoint("RIGHT", -3, 0)
    close:SetText("×")
    close:SetScript("OnEnter", function(self) S.Fill(self, { 0.6, 0.1, 0.1, 1 }) end)
    close:SetScript("OnLeave", function(self) S.Fill(self, S.PANEL) end)
    close:SetScript("OnClick", function() frame:Hide() end)

    status = S.Text(frame, 12)
    status:SetPoint("BOTTOMLEFT", 14, 20)
    status:SetPoint("RIGHT", -280, 0)

    -- Setup view
    setup = CreateFrame("Frame", nil, frame)
    setup:SetAllPoints()

    local label = S.Text(setup, 14)
    label:SetPoint("TOPLEFT", 16, -(TITLE_H + 22))
    say(label, "LEVEL")
    edit = S.Edit(setup, 44)
    edit:SetPoint("LEFT", label, "RIGHT", 10, 0)
    edit:SetNumeric(true)
    edit:SetMaxLetters(2)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); onClear() end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local after = S.Text(setup, 14)
    after:SetPoint("LEFT", edit, "RIGHT", 10, 0)
    say(after, "OR_LOWER")
    setup.level = S.Text(setup, 11, S.MUTED)
    setup.level:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -10)

    checkQuests = checkbox(setup, "DO_QUESTS")
    checkQuests:SetPoint("TOPLEFT", setup.level, "BOTTOMLEFT", -6, -10)
    checkItems = checkbox(setup, "DO_ITEMS")
    checkItems:SetPoint("TOPLEFT", checkQuests, "BOTTOMLEFT", 0, -2)

    local clear = button(setup, "CLEAR", 150)
    clear:SetPoint("BOTTOMRIGHT", -12, 12)
    clear:SetScript("OnClick", onClear)

    -- Preview view
    preview = CreateFrame("Frame", nil, frame)
    preview:SetAllPoints()
    preview:Hide()

    questHead = S.Text(preview, 13, accent)
    questHead:SetPoint("TOPLEFT", 16, -(TITLE_H + 12))
    itemHead = S.Text(preview, 13, accent)
    itemHead:SetPoint("TOPLEFT", 14 + LEFT_W + GAP, -(TITLE_H + 12))

    scroll = S.Scroll(preview)
    scroll:SetPoint("TOPLEFT", 12, -(TITLE_H + 34))
    scroll:SetPoint("BOTTOMRIGHT", -24, 84)
    content = scroll.child
    content:SetWidth(W - 40)

    local hint = S.Text(preview, 11, S.MUTED)
    hint:SetPoint("BOTTOMLEFT", 14, 58)
    hint:SetPoint("RIGHT", -14, 0)
    say(hint, "HINT")

    summary = S.Text(preview, 13)
    summary:SetPoint("BOTTOMLEFT", 14, 38)
    summary:SetPoint("RIGHT", -280, 0)

    okButton = button(preview, "OK", 150)
    okButton:SetPoint("BOTTOMRIGHT", -12, 12)
    okButton:SetScript("OnClick", onOK)
    backButton = button(preview, "BACK", 110)
    backButton:SetPoint("RIGHT", okButton, "LEFT", -8, 0)
    backButton:SetScript("OnClick", function()
        setStatus("")
        showSetup()
    end)

    frame:SetScript("OnShow", function() setStatus(""); showSetup() end)
    ns.ApplyTexts()
end

function ns.ApplyTexts()
    for _, e in ipairs(labels) do e[1]:SetText(L[e[2]]) end
    setup.level:SetText(L.YOUR_LEVEL:format(UnitLevel("player")))
    if preview:IsShown() then refresh() end
end

function ns.Toggle()
    if not frame then build() end
    frame:SetShown(not frame:IsShown())
end
