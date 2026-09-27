# Game Scripts (code root)

When writing or editing game code in this directory, follow these standards.

## Engine Version Warning

The LLM's training data predates the pinned engine version.
**Always check `docs/engine-reference/` before using any engine API.**
Do not guess at post-cutoff API signatures — look them up first.

## Coding Standards

- All public APIs require doc comments
- Gameplay values must be **data-driven** (external config files), never hardcoded
- Prefer dependency injection over singletons for testability
- Architecture decisions go in `docs/architecture/` as ADRs — **how many depends on
  `modes.workflow`**: all at `full`, critical only at `standard`, none required at
  `minimal` (the decision log carries them)
- Commits must reference the relevant story ID or design document

## File Routing

Match the engine-specialist agent to the file type being written.
See `CLAUDE.md` → Technical Preferences → Engine Specialists → File Extension Routing.

When in doubt, use the primary engine specialist configured in `CLAUDE.md`.

## Tests

Tests live in `game/tests/` (headless runners, `test_*.gd`) — not in `game/scripts/`.
Gameplay values come from `game/data/assumptions.json` and `game/data/cells.json`.
Every gameplay system should have unit tests covering its formulas and edge cases.

## Verification-Driven Development

Write tests first when adding gameplay systems.
For UI changes, verify with screenshots.
Compare expected output to actual output before marking work complete.
