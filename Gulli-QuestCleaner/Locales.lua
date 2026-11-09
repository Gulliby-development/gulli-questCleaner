local _, ns = ...

local L = {
    LEVEL = "Abandon quests of level",
    OR_LOWER = "and lower",
    YOUR_LEVEL = "Your level: %d",
    DO_QUESTS = "Abandon quests",
    DO_ITEMS = "Delete leftover quest items",
    CLEAR = "Clear",
    OK = "OK",
    BACK = "Back",
    QUESTS_N = "Quests: %d of %d",
    ITEMS_N = "Items: %d of %d",
    SUMMARY = "Abandon %d quests, delete %d items",
    NO_QUEST = "No quest",
    WHY_QUEST_STAYS = "kept: its quest stays",
    HINT = "Untick what you want to keep. Unticked items are kept next time too.",
    NOTHING = "Nothing to clean.",
    BAD_LEVEL = "Enter a level from 1 to 99.",
    IN_COMBAT = "Not in combat.",
    DONE = "Done: %d quests abandoned, %d item stacks deleted.",
    LEFT = "%d left. Press OK again.",
    WHY_ABANDONED = "for a quest you abandon",
    WHY_NO_QUEST = "no quest in your log needs it",
    WHY_DONE = "starts a quest you already did",
    KEEP_RESET = "Forgot all kept items.",
    HELP = "/gqc opens the window, /gqc reset forgets kept items.",
}

if GetLocale() == "ruRU" then
    L.LEVEL = "Бросить квесты уровня"
    L.OR_LOWER = "и ниже"
    L.YOUR_LEVEL = "Ваш уровень: %d"
    L.DO_QUESTS = "Бросать квесты"
    L.DO_ITEMS = "Удалять ненужные квестовые предметы"
    L.CLEAR = "Очистить"
    L.OK = "OK"
    L.BACK = "Назад"
    L.QUESTS_N = "Квесты: %d из %d"
    L.ITEMS_N = "Предметы: %d из %d"
    L.SUMMARY = "Бросить квестов: %d, удалить предметов: %d"
    L.NO_QUEST = "Без квеста"
    L.WHY_QUEST_STAYS = "останется: его квест остаётся"
    L.HINT = "Снимите галочку с того, что нужно оставить. Такие предметы останутся и в следующий раз."
    L.NOTHING = "Чистить нечего."
    L.BAD_LEVEL = "Введите уровень от 1 до 99."
    L.IN_COMBAT = "Не в бою."
    L.DONE = "Готово: брошено квестов %d, удалено стопок предметов %d."
    L.LEFT = "Осталось %d. Нажмите OK ещё раз."
    L.WHY_ABANDONED = "для квеста, который бросаете"
    L.WHY_NO_QUEST = "не нужен ни одному квесту в журнале"
    L.WHY_DONE = "начинает уже сделанный квест"
    L.KEEP_RESET = "Список сохраняемых предметов очищен."
    L.HELP = "/gqc открывает окно, /gqc reset забывает сохраняемые предметы."
end

ns.L = L
