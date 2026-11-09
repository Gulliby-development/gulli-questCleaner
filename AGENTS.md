# Working on Gulli-QuestCleaner

These instructions apply to every coding agent (Claude Code, GitHub Copilot, Codex and others) and to human contributors.

## Project

Gulli-QuestCleaner is a World of Warcraft addon for WoW Forever. It abandons the quests at or below a level the player enters and deletes the quest items in the bags that no quest needs any more. Nothing is removed before the player sees it: **Clear** builds a preview, and only **OK** acts.

- WoW Forever is Vanilla content on the Retail engine. The API is Retail's (`C_QuestLog`, `C_Container`, `C_Item`); the quest and item data are Vanilla's. Keep a fallback to the old global API where it costs one line, so the addon also loads on a client without the `C_` namespaces.
- TOC: `## Interface: 16001`. The index and Runeloader treat `## Interface: 160xx` as a Forever build.
- Our own addons are all named `Gulli-<Name>` (G-U-L-L-I, after the nick Gulliby). The folder, the TOC, the title and the repository use that name.
- It is plain Lua 5.1 with no libraries (no Ace3, no LibStub). The whole UI is built in code with the game's own templates.
- It ships through [Runeloader](https://github.com/Gulliby-development/runeloader): the [runeloader-index](https://github.com/Gulliby-development/runeloader-index) lists it from `seeds.txt` and reads the `release.json` of each release.

## How the addon works

- `Gulli-QuestCleaner.toc` loads `Locales.lua`, `Core.lua`, `Skin.lua`, `UI.lua` in this order and keeps `GulliQuestCleanerDB` as saved variables (`level`, `quests`, `items`, `keep`). The tests load the files in the TOC order.
- `Locales.lua` has the texts of every language: `ns.L` reads the game client's language and falls back to English.
- `Core.lua` holds the rules and touches the game: the quest log scan (`ns.Quests`), the plan (`ns.PlanQuests`, `ns.PlanItems`, `ns.ItemGoes`), the run (`ns.Run`, `ns.Leftover`), the slash commands and the saved variables.
  - A quest is planned when its level is at or below the entered level. Headers, hidden quests and quests without a level stay.
  - Each quest keeps its zone: the quest log header above it. `ns.PlanQuests` sorts by zone in quest log order, then by level; `ns.Zones` groups the plan by zone for the window.
  - A bag item is a quest item when its class is Quest (12), the game marks it as a quest item, or it starts a quest.
  - A quest item is offered when no quest that stays in the log needs it. "Needs" means its name is in the quest's objectives, summary or description, or it is the quest's usable item. The planned quests that need it become its `links`; an item with no link is listed under "No quest".
  - An item that starts a quest is offered only when that quest is already done.
  - `PERMANENT` lists quest items that stay useful after their quest (dungeon keys, attunements, raid summoning items). They are never offered. Items the player unticked go into `keep` and are not offered again until `/gqc reset`.
  - `ns.ItemGoes`: an item goes only when it is ticked and every quest it is linked to goes too.
- `Skin.lua` is the flat look in the spirit of ElvUI: dark panels with 1 pixel borders, the class colour as the accent, flat buttons, check boxes, edit boxes and a thin scroll bar, all drawn from plain textures.
- `UI.lua` is the window: the setup view (level, what to clean) and the preview (zones with their quests on the left, items on the right, a line from each quest to its items; a zone row ticks or unticks all its quests). It shows what `Core.lua` planned and never decides on its own what to remove.
- Removing things runs inside the **OK** click, because the game lets an addon delete a picked-up item only inside a hardware event. `ns.Run` stops at the first refused delete; a second later `ns.Leftover` shows what is still there, and the player presses **OK** again.

## Task workflow

- Track planned work as GitHub Issues in this repository, not in Markdown files or TODO comments. Before you start, find the issue for the task or open one. Record a new idea, a follow-up or a deferred item as an issue.
  - Issue types: Task, Bug or Feature.
  - Labels: `idea` (not decided yet), `deferred` (agreed for later), `needs-owner` (only the owner can do or decide it), `verification` (needs the real game), and `area:quests|items|ui|locales|build|ci`.
  - Put `Priority: P0|P1|P2` on the first line of the issue body. P0 blocks current work or a release, P1 is next, P2 is later or an idea.
- Before you open or extend a Bug issue, follow the [file-issue skill](.agents/skills/file-issue/SKILL.md). It finds the root cause and sweeps the code for every other place with the same defect. A pull request that fixes such an issue fixes every place the issue lists and reports the result in a `## Sweep` section of its description.
- Every Feature and Task issue has a `## Maintainability` section. It names the rule a later change must follow when the task adds something that later code must extend (a new item rule, a new language, a new saved setting). It says `None` when nothing needs extending. The pull request that adds such a mechanism adds its rule to this file.
- Start every task on its own branch from an up-to-date `main`:
  - new feature, documentation, CI or refactor: `feature/<name>`;
  - bug fix: `bugfix/<name>`.

  `<name>` is a few lowercase words joined by hyphens. Do not use other prefixes (`docs/`, `fix/`, `claude/`, `copilot/`) or generic names such as `patch` or `update`. If your tool proposes a default branch, rename it before the first push. CI fails a pull request whose branch breaks this rule; only Dependabot's `dependabot/` branches are exempt.
- Commit working states on the task branch. Before each commit, run `lua5.1 tests/test.lua`, so every commit passes.
- A pull request that finishes an issue says `Closes #N` in its description. Use `Refs #N` when the pull request does only part of it.
- Before you finish a task, check `README.md` against your change and update it in the same pull request: features, commands, button names, FAQ answers and images must match the addon as it is after the merge. Say in the pull request description that you checked it, or what you changed.
- When the task is complete and [Verification](#verification) passes, open a pull request to `main`. `main` takes changes only through pull requests with green CI. Do not push to `main` directly.

## Working conventions

- Keep the addon free of libraries. Use the game's API and Lua 5.1 only. A new dependency needs an issue and the owner's decision first.
- Nothing leaves the bags or the quest log without the preview. Every abandon and every delete runs from the **OK** click, for the entries the player left ticked. Never delete from a timer, an event or a slash command.
- Never offer an item a quest that stays in the log may need. When in doubt, keep it: a false "needed" only leaves an item in the bags, a false "not needed" loses it.
- A quest item that stays useful after its quest goes into `PERMANENT` in `Core.lua`, with its name in a comment.
- A new rule for what gets offered goes into `Core.lua` (`PlanQuests`, `PlanItems` or `ItemGoes`) with a test in `tests/test.lua`. `UI.lua` only shows the plan.
- The game API goes through the small wrappers in `Core.lua` (`slotInfo`, `numSlots`, `questInfo`, `pickup`, ...), which pick the `C_` function and fall back to the old global. A new game call gets such a wrapper and a fake in `tests/wow.lua`.
- Build the UI in code from the widgets in `Skin.lua` (`Box`, `Button`, `Check`, `Edit`, `Scroll`, `Text`), not from Blizzard's templates, so every part keeps the flat ElvUI-like look. A new kind of widget goes into `Skin.lua`. Do not add XML files.
- The window must work by mouse and by touch on a phone or handheld: buttons at least 28 pixels high, check boxes at least 26, no text that runs out of its row.
- Keep comments short and about intent that the code does not show.
- Do not commit release zips or `release.json`; the Release workflow makes them.

## Releases

`.github/workflows/release.yml` builds a release:

1. In a pull request, bump `## Version` in `Gulli-QuestCleaner.toc` (`x.y.z`), and merge it.
2. Start the Release workflow on `main` from the Actions tab ("Run workflow"), or push the tag `v<version>`.
3. The workflow runs the tests, zips the `Gulli-QuestCleaner` folder as `Gulli-QuestCleaner-<version>-forever.zip`, writes `release.json` with the `forever` flavor, and publishes the release `v<version>` with both files. It refuses a version that is already released.

The owner asks for a release after every merged bug fix and after each batch of features: bump the version and run the workflow once the pull request is merged with green CI. Runeloader shows the new version after the next nightly index run.

The asset names and `release.json` are what Runeloader and its index read. A change to them is a change in runeloader-index too.

## Language

- Write code, identifiers, comments, commit messages, issues, pull requests and these instructions in English.
- `README.md` is the addon's page for players. It is in plain English (about B1 level): short sentences, no jargon in the main part. It keeps this order: the wordmark, a one-line pitch, features, install steps, FAQ. Technical details go inside `<details>` spoilers. Its images live in `docs/images/` and stay small (under about 400 KB each; use JPEG for large photo-like images).
- The addon speaks the same languages as the Runeloader app: English (the base and the fallback), Deutsch, Español, Français, Polski, Português, Русский and 中文.
  - Put no UI text in `Core.lua` or `UI.lua`. Add every new key to every language table in `Locales.lua` in the same pull request; the test fails on a missing key or a different number of `%d`.
  - The addon always follows the game client's language (`GetLocale`), like the app follows the system language. There is no language picker (owner's decision).
  - A new language needs a table in `T`, an entry in `TAGS`, its client locales in `CLIENT` when the game has them, and a `## Notes-<locale>` line in the TOC.
  - Save a text by its key (as `item.why` does), not as a translated string.

## Navigation

- `Gulli-QuestCleaner/`: the addon as it goes into `Interface/AddOns`. `icon.tga` (64x64) is its icon in the game's addon list and in Runeloader; the game reads TGA or BLP, not PNG.
- `tests/wow.lua`: a fake WoW client with only the calls the addon makes. `tests/test.lua`: the tests.
- `docs/images/`: the logo and the images in `README.md`. The logo and wordmarks come from Codex CLI image generation; the prompts are in `docs/images/PROMPTS.md`. The window pictures are drawn from the addon's layout in HTML, not taken in the game; replace them with real screenshots when there are some.
- `.agents/skills/file-issue/`: the bug sweep skill.
- `.github/workflows/`: CI (`ci.yml`) and releases (`release.yml`).

## Verification

CI runs these on every pull request to `main`. Run them before you open one:

```sh
for f in Gulli-QuestCleaner/*.lua tests/*.lua; do luac5.1 -p "$f"; done
lua5.1 tests/test.lua
```

The fake client cannot show the window or run the real game rules. For a change to `Core.lua` or `UI.lua`, also try it in WoW Forever: copy `Gulli-QuestCleaner` into `Interface/AddOns`, `/reload`, open `/gqc`, press **Clear** and check the preview before **OK**. Use a character whose quests and items you can lose. Attach a screenshot of a changed window to the pull request. Say what you checked, on which client and device, and report any check you could not run.
