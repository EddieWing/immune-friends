---
paths:
  - "game/tests/**"
  - "tests/**"
---

# Test Standards

## How tests work in this project

Game tests are headless Godot scripts in `game/tests/`, not a GdUnit suite:

- One file per system or feature: `game/tests/test_[system].gd`
  (`test_simulation.gd`, `test_cell_tuner.gd`, `test_hud_a.gd`).
- Each file `extends SceneTree`, runs its scenarios from `_initialize()`, reports
  each assertion through a local `check(ok, message)` that prints `PASS:`/`FAIL:`,
  and ends with `quit(1 if failures else 0)` — the exit code is the verdict.
- Load the code under test by path (`load("res://scripts/simulation.gd").new()`)
  and seed randomness explicitly (`sim.reset(42, 12)`), so a run is deterministic.
- Run one locally: `godot --headless --path game --script res://tests/test_[system].gd`.
- **A new test file must be added to the `for test in ...` list in
  `.github/workflows/deploy.yml`.** CI runs only the files named there; an
  unlisted test never gates a deploy.

## Rules

- `check()` messages name the scenario and the expected result
  (`"wall blocks virus after placement"`), because the message is the only
  record of which assertion failed
- Every test must have a clear arrange/act/assert structure
- Unit tests must not depend on external state (filesystem, network, database)
- Integration tests must clean up after themselves
- Performance tests must specify acceptable thresholds and fail if exceeded
- Test data must be defined in the test or in dedicated fixtures, never shared mutable state
- Mock external dependencies — tests should be fast and deterministic
- Every bug fix must have a regression test that would have caught the original bug —
  and **you must watch it fail before you trust it.** Run the new test against the
  unfixed code, confirm it fails, then apply the fix and confirm it passes. A
  regression test that has only ever been seen passing is not known to test anything.

  > This is `.claude/rules/skill-authoring.md`'s "a gate you have not watched fail
  > is not a gate", applied to tests. It is written out here because stating the
  > *goal* is not enough. A regression test for an iteration-order defect can use
  > a fixture where no cell takes part in two transfers per tick — it then passes
  > against the very bug it was written for, and looks authoritative doing it. The
  > fixture, not the assertion, is what makes it useless, and only running it
  > against the unfixed code exposes that.

## Examples

**Correct** (deterministic setup, one scenario per `check`, exit code set):

```gdscript
extends SceneTree
var failures := 0

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok: failures += 1

func _initialize() -> void:
	# Arrange
	var sim = load("res://scripts/simulation.gd").new()
	sim.reset(42, 12)
	# Act
	sim.begin_battle()
	# Assert
	check(sim.spawn_queue.size() > 0, "battle start queues the first wave")
	quit(1 if failures else 0)
```

**Incorrect**:

```gdscript
func _initialize() -> void:
	var sim = load("res://scripts/simulation.gd").new()
	sim.reset(randi(), 12)   # VIOLATION: non-deterministic seed
	sim.begin_battle()
	check(true, "ok")        # VIOLATION: message says nothing, assertion checks nothing
	# VIOLATION: no quit() — CI sees exit 0 even when checks failed
```
