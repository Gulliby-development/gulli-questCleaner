# Copilot instructions

Follow [AGENTS.md](../AGENTS.md) in the repository root. It holds the rules for every coding agent in this project: the issue and branch workflow, the working conventions and the checks to run before a pull request.

The most important rules:

- Work on a `feature/<name>` or `bugfix/<name>` branch from `main`. Never push to `main`.
- Plain Lua 5.1 for the WoW Forever client (Retail API, `## Interface: 16001`), no libraries.
- Nothing is removed without the preview: every abandon and delete runs from the **OK** click.
- Every UI text goes into all 8 languages in `Locales.lua`.
- Before a pull request, run `lua5.1 tests/test.lua`.
- Before you file or fix a bug, follow [the file-issue skill](../.agents/skills/file-issue/SKILL.md).
- Before you finish a task, check `README.md` and keep it up to date with your change.
