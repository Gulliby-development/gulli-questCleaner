# Gulli-QuestCleaner

A small WoW Forever addon that cleans your quest log and bags.

- Enter a level. Every quest of that level and lower is abandoned.
- Quest items that no quest in your log needs any more are deleted: leftovers of abandoned quests, items of quests you already finished, and items that start a quest you already did.
- Nothing is removed before you see it. **Clear** shows quests on the left and items on the right, with a line from each quest to its items. Untick anything you want to keep, then press **OK**.

The window speaks English, Deutsch, Español, Français, Polski, Português, Русский and 中文, the same languages as Runeloader. By default it follows the game client's language; pick another one with the **Language** button.

Open it with `/gqc` or from the addon button on the minimap. `/gqc reset` forgets the items you chose to keep.

## Install

Install it with [Runeloader](https://github.com/Gulliby-development/runeloader), or download the zip from [Releases](../../releases) and unpack it into `Interface/AddOns`.

## Safe by design

- Items that stay useful after their quest (dungeon keys, Drakefire Amulet, Aqual Quintessence and similar) are never offered.
- An item a quest you keep still needs is never offered. If you untick a quest, its items stay too.
- Items you untick are remembered and not offered again.
- The game may refuse some deletions in one click. The window then shows what is left; press **OK** again.

## Release

Bump `## Version` in the TOC, then start the Release workflow from the Actions tab (or push the tag `v<version>`). It checks the Lua syntax, zips the addon and publishes the release `v<version>` with a `release.json` for the `forever` flavor.
