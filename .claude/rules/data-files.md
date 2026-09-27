---
paths:
  - "game/data/**"
---

# Data File Rules

- All JSON files must be valid JSON — broken JSON blocks the entire build pipeline
- File naming: lowercase with underscores only, one file per data domain, named for what it holds
  (`cells.json` — cell definitions keyed by cell id; `assumptions.json` — provisional
  simulation and balance values). Split a domain as `[domain]_[name].json` only when it outgrows one file
- Every data file must have a documented schema (either JSON Schema or documented in the corresponding design doc)
- Numeric values must include comments or companion docs explaining what the numbers mean
- Use consistent key naming: **`snake_case` for keys within JSON files**, matching
  the snake_case file naming above and the engine idiom
  every other standard in this repo uses.

  > **On Unity and Unreal this costs you a mapping layer — budget for it rather
  > than changing the keys.** `JsonUtility` binds by *exact field name*, and C#
  > fields are `camelCase` per `naming.variables`, so a snake_case file cannot bind
  > directly to the type that consumes it. Use a private nested DTO whose fields
  > are the wire format and which maps once into your real type, or take a
  > dependency that supports a naming policy (Newtonsoft `SnakeCaseNamingStrategy`,
  > `System.Text.Json` `JsonNamingPolicy`). Do **not** switch the file to camelCase
  > to avoid the DTO: keys are the cross-engine contract. Write the DTO and
  > document it as a wire-format boundary — that is the intended shape.
- No orphaned data entries — every entry must be referenced by code or another data file
- Version data files when making breaking schema changes
- Include sensible defaults for all optional fields

## Examples

**Correct** naming and structure (`viruses.json`):

```json
{
  "goblin": {
    "base_health": 50,
    "base_damage": 8,
    "move_speed": 3.5,
    "loot_table": "loot_goblin_common"
  },
  "goblin_chief": {
    "base_health": 150,
    "base_damage": 20,
    "move_speed": 2.8,
    "loot_table": "loot_goblin_rare"
  }
}
```

**Incorrect** (`EnemyData.json`):

```json
{
  "Goblin": { "hp": 50 }
}
```

Violations: uppercase filename, uppercase key, abbreviated key, missing required fields.
