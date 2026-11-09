# Gulli-QuestCleaner

A small WoW Forever addon that cleans your quest log and bags.

- Enter a level. Every quest of that level and lower is abandoned.
- Quest items that no quest in your log needs any more are deleted: leftovers of abandoned quests, items of quests you already finished, and items that start a quest you already did.
- Nothing is removed before you see it. **Clear** shows quests on the left and items on the right, with a line from each quest to its items. Untick anything you want to keep, then press **OK**.

Open it with `/gqc` or from the addon button on the minimap. `/gqc reset` forgets the items you chose to keep.

## Install

Install it with [Runeloader](https://github.com/Gulliby-development/runeloader), or download the zip from [Releases](../../releases) and unpack it into `Interface/AddOns`.

## Safe by design

- Items that stay useful after their quest (dungeon keys, Drakefire Amulet, Aqual Quintessence and similar) are never offered.
- An item a quest you keep still needs is never offered. If you untick a quest, its items stay too.
- Items you untick are remembered and not offered again.
- The game may refuse some deletions in one click. The window then shows what is left; press **OK** again.

## Release

Push a tag `v<version>` (the same as `## Version` in the TOC). The workflow zips the addon and publishes a release with a `release.json` for the `forever` flavor.
