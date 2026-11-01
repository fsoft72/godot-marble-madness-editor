# Changes

## 2026-11-01

- Added design document for the Godot port of marble-madness (`docs/superpowers/specs/2026-11-01-marble-madness-godot-port-design.md`).
- Added implementation plan for phases 1 and 2 (`docs/superpowers/plans/2026-11-01-marble-madness-godot-editor.md`).
- Added Godot project skeleton (`project.godot`, `.gitignore`), `Constants` class and a headless test runner (`tests/run_tests.gd`, `tests/test_case.gd`).
- Test runner now fails a test method that logs a runtime script error (Logger via OS.add_logger, `tests/error_capture.gd`).
- Added `BlockData`, `LevelData` and tolerant `LevelIO` (JSON load/save, snapshot/restore in place) with tests (`scripts/core/`, `tests/test_level_io.gd`).
- Added `History` undo/redo snapshot stacks (max 100 steps) with tests (`scripts/core/history.gd`, `tests/test_history.gd`).
- Added `BlockSurface` (port of `rotateUV` and `getBlockSurfaceY`), the golden data generator `tools/gen_golden.mjs` and `tests/golden/surface_y.json` (1725 entries) with tests (`scripts/geometry/block_surface.gd`, `tests/test_block_surface.gd`).
- Added `TextureFactory` (procedural top surface, cliff and flag materials, decals drawn with Image primitives, cached) with tests (`scripts/geometry/texture_factory.gd`, `tests/test_texture_factory.gd`).
- Added `BlockMeshBuilder` (port of `buildBlockMeshGroup`: top tiles with vertex shades, cliff walls with trim, stepped sub-tiles, cutouts, goal_bevel, Godot clockwise winding, named surfaces, collision faces derived from the same generated parts) with tests (`scripts/geometry/block_mesh_builder.gd`, `tests/test_block_mesh_builder.gd`).
- Added `ElementBuilder` (port of `buildElementOnBlock` and `createGuardTubeSegment`: guard tubes, cones with floor shadow, goal flags, glass marble start; visual only, block local coordinates) with tests (`scripts/geometry/element_builder.gd`, `tests/test_element_builder.gd`).
- Fixed `ElementBuilder` marbleColor parsing: accepts `#rrggbb` strings and ints, invalid values fall back to the default red.
- Added `LevelView` (one `Block_bx_bz` node per block with mesh, element and concave collider, per-block rebuild, physics-free `pick_cell` against cached faces, `cell_from_ground_ray`); void, absent and bare pit cells get no node (`scripts/editor/level_view.gd`, `tests/test_level_view.gd`).
- Added `CameraRig` (ortho arcade camera size 34 and perspective camera FOV 42, orbit/pan/zoom around a focus point with pitch clamp, arcade isometric reset around the `focus_on` point, `ray_from_screen`; right drag orbits, middle drag pans, wheel zooms) with tests (`scripts/editor/camera_rig.gd`, `tests/test_camera_rig.gd`).
