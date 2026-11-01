# Changes

## 2026-11-01

- Added design document for the Godot port of marble-madness (`docs/superpowers/specs/2026-11-01-marble-madness-godot-port-design.md`).
- Added implementation plan for phases 1 and 2 (`docs/superpowers/plans/2026-11-01-marble-madness-godot-editor.md`).
- Added Godot project skeleton (`project.godot`, `.gitignore`), `Constants` class and a headless test runner (`tests/run_tests.gd`, `tests/test_case.gd`).
- Test runner now fails a test method that logs a runtime script error (Logger via OS.add_logger, `tests/error_capture.gd`).
- Added `BlockData`, `LevelData` and tolerant `LevelIO` (JSON load/save, snapshot/restore in place) with tests (`scripts/core/`, `tests/test_level_io.gd`).
- Added `History` undo/redo snapshot stacks (max 100 steps) with tests (`scripts/core/history.gd`, `tests/test_history.gd`).
- Added `BlockSurface` (port of `rotateUV` and `getBlockSurfaceY`), the golden data generator `tools/gen_golden.mjs` and `tests/golden/surface_y.json` (1725 entries) with tests (`scripts/geometry/block_surface.gd`, `tests/test_block_surface.gd`).
