-- Run from the repository root: lua5.1 tests/test.lua
local W = dofile("tests/wow.lua")
local failed, count = 0, 0

local function test(name, fn)
    count = count + 1
    local ok, err = pcall(fn)
    if ok then
        io.write("ok   ", name, "\n")
    else
        failed = failed + 1
        io.write("FAIL ", name, "\n     ", tostring(err), "\n")
    end
end

local function eq(a, b, what)
    if a ~= b then error((what or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

local function names(list)
    local t = {}
    for _, x in ipairs(list) do t[#t + 1] = x.name or x.title end
    table.sort(t)
    return table.concat(t, ",")
end

local QUESTS = {
    { title = "Zone", isHeader = true },
    { title = "Wolf Pelts", level = 5, questID = 101, objectives = { { text = "Wolf Pelt: 3/10" } } },
    { title = "Deliver Letter", level = 8, questID = 102, description = "Bring the Sealed Letter to Bob." },
    { title = "Ogres", level = 30, questID = 103, objectives = { { text = "Ogre Tooth: 1/5" } } },
}
local function bag()
    return {
        { id = 1, name = "Wolf Pelt", class = 12, count = 3 },
        { id = 2, name = "Sealed Letter", class = 12 },
        { id = 3, name = "Ogre Tooth", class = 12 },
        { id = 4, name = "Old Note", class = 12 },
        { id = 16309, name = "Drakefire Amulet", class = 12 },
        { id = 5, name = "Linen Cloth", class = 7 },
        { id = 6, name = "Done Starter", class = 15, starts = 55 },
        { id = 7, name = "Open Starter", class = 15, starts = 56 },
    }
end

test("quests at or below the level are planned, headers are not", function()
    Fake { quests = QUESTS, bag = bag() }
    local ns = Load()
    eq(names(ns.PlanQuests(10)), "Deliver Letter,Wolf Pelts")
    eq(#ns.PlanQuests(4), 0, "quests at level 4")
end)

test("items: leftovers go, items of quests that stay and permanent items stay", function()
    Fake { quests = QUESTS, bag = bag(), done = { [55] = true } }
    local ns = Load()
    local items = ns.PlanItems(ns.PlanQuests(10))
    eq(names(items), "Done Starter,Old Note,Sealed Letter,Wolf Pelt")
    for _, it in ipairs(items) do
        if it.name == "Wolf Pelt" then eq(it.links[1].title, "Wolf Pelts", "Wolf Pelt link") end
        if it.name == "Sealed Letter" then eq(it.links[1].title, "Deliver Letter", "letter link (found in the description)") end
        if it.name == "Old Note" then eq(#it.links, 0, "Old Note links"); eq(it.why, "WHY_NO_QUEST") end
        if it.name == "Done Starter" then eq(it.why, "WHY_DONE") end
    end
end)

test("unticking a quest keeps its items", function()
    Fake { quests = QUESTS, bag = bag() }
    local ns = Load()
    local quests = ns.PlanQuests(10)
    local items = ns.PlanItems(quests)
    for _, q in ipairs(quests) do if q.title == "Deliver Letter" then q.checked = false end end
    for _, it in ipairs(items) do
        eq(ns.ItemGoes(it), it.name ~= "Sealed Letter", it.name .. " goes")
    end
end)

test("OK abandons ticked quests and deletes ticked items only", function()
    local w = Fake { quests = QUESTS, bag = bag() }
    local ns = Load()
    local quests = ns.PlanQuests(10)
    local items = ns.PlanItems(quests)
    for _, it in ipairs(items) do if it.name == "Old Note" then it.checked = false end end
    local a, d = ns.Run(quests, items)
    eq(a, 2, "abandoned")
    eq(d, 2, "delete tries")
    eq(w.abandoned[101] and w.abandoned[102] and not w.abandoned[103], true, "abandoned the right quests")
    for _, it in ipairs(w.bag) do
        local gone = it.name == "Wolf Pelt" or it.name == "Sealed Letter"
        eq(it.gone == true, gone, it.name .. " deleted")
    end
end)

test("a refused delete leaves the item to be offered again", function()
    local w = Fake { quests = QUESTS, bag = bag() }
    local ns = Load()
    local quests = ns.PlanQuests(10)
    local items = ns.PlanItems(quests)
    w.refuseDelete = true
    ns.Run(quests, items)
    eq(w.cursor, nil, "cursor cleared")
    local _, left = ns.Leftover(quests, items)
    eq(#left, #items, "items left")
end)

test("one OK deletes every ticked item even when the cursor clears late", function()
    local w = Fake { quests = QUESTS, bag = bag(), done = { [55] = true } }
    local ns = Load()
    local quests = ns.PlanQuests(10)
    local items = ns.PlanItems(quests)
    w.slowCursor = true
    ns.Run(quests, items)
    local _, left = ns.Leftover(quests, items)
    eq(#left, 0, "items left after one OK")
    eq(w.cursor, nil, "cursor cleared")
end)

test("nothing happens in combat", function()
    local w = Fake { quests = QUESTS, bag = bag() }
    local ns = Load()
    w.combat = true
    local quests = ns.PlanQuests(10)
    local a, d = ns.Run(quests, ns.PlanItems(quests))
    eq(a + d, 0, "changes in combat")
end)

test("the window: Clear, then OK, cleans and reports", function()
    local w = Fake { quests = QUESTS, bag = bag(), level = 18 }
    local ns = Load()
    ns.Toggle()
    Find(function(f) return rawget(f, "_OnShow") end)._OnShow()
    Find(function(f) return TextOf(f) == ns.L.CLEAR and rawget(f, "_OnClick") end)._OnClick()
    Find(function(f) return TextOf(f) == ns.L.OK and rawget(f, "_OnClick") end)._OnClick()
    eq(w.abandoned[101] and w.abandoned[102], true, "abandoned")
    eq(w.printed[#w.printed]:find("2 quests abandoned", 1, true) ~= nil, true, "done message: " .. tostring(w.printed[#w.printed]))
end)

test("the addon speaks the client's language and falls back to English", function()
    Fake { locale = "ruRU" }
    eq(Load().L.CLEAR, "Очистить")
    Fake { locale = "deDE" }
    eq(Load().L.CLEAR, "Aufräumen")
    Fake { locale = "koKR" }
    eq(Load().L.CLEAR, "Clear")
end)

test("quests keep their zone and the plan is grouped by zone in log order", function()
    Fake { quests = {
        { title = "Westfall", isHeader = true },
        { title = "Stew", level = 14, questID = 1 },
        { title = "Elwynn Forest", isHeader = true },
        { title = "Wolves", level = 6, questID = 2 },
        { title = "Kobolds", level = 4, questID = 3 },
        { title = "Westfall", isHeader = true },
        { title = "Murlocs", level = 12, questID = 4 },
    } }
    local ns = Load()
    local zones = ns.Zones(ns.PlanQuests(20))
    eq(#zones, 2, "zones")
    eq(zones[1].name, "Westfall")
    eq(names(zones[1].quests), "Murlocs,Stew", "Westfall quests")
    eq(zones[2].name, "Elwynn Forest")
    eq(zones[2].quests[1].title, "Kobolds", "lower level first")
end)

test("a zone row ticks and unticks all of its quests", function()
    Fake { quests = QUESTS, bag = bag(), level = 18 }
    local ns = Load()
    ns.Toggle()
    Find(function(f) return rawget(f, "_OnShow") end)._OnShow()
    Find(function(f) return TextOf(f) == ns.L.CLEAR and rawget(f, "_OnClick") end)._OnClick()
    local zoneRow = Find(function(f) local d = rawget(f, "data"); return d and d.quests end)
    assert(zoneRow, "no zone row")
    zoneRow._OnClick()
    for _, q in ipairs(rawget(zoneRow, "data").quests) do eq(q.checked, false, q.title .. " after one click") end
    zoneRow._OnClick()
    for _, q in ipairs(rawget(zoneRow, "data").quests) do eq(q.checked, true, q.title .. " after two clicks") end
end)

test("every language has every key, with the same %d placeholders", function()
    Fake {}
    local ns = Load()
    local en = ns.T.en
    for i, tag in ipairs(ns.TAGS) do
        do
            local t = ns.T[tag]
            assert(t, "no table for " .. tag)
            for key, text in pairs(en) do
                assert(t[key], tag .. " is missing " .. key)
                local _, a = text:gsub("%%d", "")
                local _, b = t[key]:gsub("%%d", "")
                assert(a == b, tag .. "." .. key .. " has " .. b .. " %d, English has " .. a)
            end
            for key in pairs(t) do assert(en[key], tag .. " has unknown key " .. key) end
        end
    end
end)

io.write(count - failed, "/", count, " passed\n")
os.exit(failed == 0 and 0 or 1)
