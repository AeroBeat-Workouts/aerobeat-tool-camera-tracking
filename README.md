# AeroBeat Tool Camera Tracking

This repo hosts the first **camera-tracking contract shell** for the AeroBeat tool lane.

The current slice is intentionally a **singleton shell** for a **vendor-agnostic camera-tracking service** rather than a real camera implementation. It establishes the repo-root sharable contracts for lifecycle, config, preview attachment, backend seams, and normalized tracking frames so later MediaPipe or native integrations can plug in without changing the public surface.

The shell is aligned to the approved API sketch in `.plans/bootstrap-architecture/CAMERA-TRACKING-API.md`, which defines the current state machine, required signals, config shape, preview ownership model, and normalized tracking-frame payload.

## Current contract scope

- `CameraTracking` singleton shell with lifecycle methods matching the first-pass API
- standardized top-level state constants (`idle`, `starting`, `running`, `restarting`, `stopping`, `error`)
- readiness/detail helpers for `backend_ready`, `preview_ready`, `tracking_ready`, and `source_ready`
- `CameraTrackingConfig` helpers for defaults and normalization
- `CameraTrackingBackend` interface seam for concrete integrations
- `CameraTrackingFakeBackend` proving backend for repo-local tests
- preview attachment contract helpers that preserve the preferred `attach_preview_surface(node)` ownership model
- normalized tracking-frame stub contract for downstream consumers and tests

## Repository details

- **Type:** AeroBeat tool package
- **License:** **Mozilla Public License 2.0 (MPL 2.0)**
- **Implementation status:** contract shell only; no real camera backend shipped in this slice

## GodotEnv development flow

This repo follows the AeroBeat GodotEnv package convention.

- Canonical dev/test manifest: `.testbed/addons.jsonc`
- Installed dev/test addons: `.testbed/addons/`
- GodotEnv cache: `.testbed/.addons/`
- Hidden workbench project: `.testbed/project.godot`
- Repo-local unit tests: `.testbed/tests/`
- Repo-root sharable source: `src/`

The repo root remains the package/published boundary for downstream consumers. `.testbed/` is only the proving surface. Do real sharable work at the repo root, not inside `.testbed/addons/` mirrors.

### Restore dev/test dependencies

From the repo root:

```bash
/home/derrick/.openclaw/workspace/scripts/godotenv-sync
cd .testbed
godotenv addons install
```

Use the sync helper first if the local toolchain or linked workspace packages need refreshing.

### Import smoke check

From the repo root:

```bash
godot --headless --path .testbed --import
```

### Run repo-local tests

From the repo root:

```bash
godot --headless --path .testbed --script addons/gut/gut_cmdln.gd \
  -gdir=res://tests \
  -ginclude_subdirs \
  -gexit
```

## Notes for later slices

- real backend selection/factories are intentionally deferred
- replay/video-file integration remains part of the public source contract but not yet implemented
- preview descriptors and tracking frames are stabilized now so downstream consumers do not need to guess payload shape per backend
