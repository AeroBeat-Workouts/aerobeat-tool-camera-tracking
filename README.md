# AeroBeat Tool Camera Tracking

This repo hosts the first **tool-owned camera-tracking contract and live-camera integration seam** for the AeroBeat tool lane.

The current slice is intentionally narrow but now truthful: `CameraTracking` remains the **vendor-agnostic camera-tracking service** and **singleton shell** that owns lifecycle, preview attachment semantics, source coordination, backend resolution policy, and normalized public tracking payloads, while repo-local proving can register a real vendor backend factory and drive a live-camera bootstrap/probe path through the public tool API.

The tool surface is aligned to the approved API sketch in `.plans/bootstrap-architecture/CAMERA-TRACKING-API.md`, which defines the current state machine, required signals, config shape, preview ownership model, and normalized tracking-frame payload. The newly added backend-factory seam keeps sharable ownership here at the repo root without hard-preloading vendor source from this package.

## Current contract scope

- `CameraTracking` singleton shell with lifecycle methods matching the first-pass API
- tool-owned backend registration and resolution keyed by public backend ID
- standardized top-level state constants (`idle`, `starting`, `running`, `restarting`, `stopping`, `error`)
- readiness/detail helpers for `backend_ready`, `preview_ready`, `tracking_ready`, and `source_ready`
- `CameraTrackingConfig` helpers for defaults and normalization
- `CameraTrackingBackend` interface seam for concrete integrations
- `CameraTrackingFakeBackend` proving backend for repo-local tests
- preview attachment contract helpers that preserve the preferred `attach_preview_surface(node)` ownership model
- normalized tracking-frame default/stub contract for downstream consumers and tests
- `.testbed/` proving that `backend = mediapipe_python` plus `source.kind = live_camera` can flow through the real vendor runtime probe lane truthfully

## Repository details

- **Type:** AeroBeat tool package
- **License:** **Mozilla Public License 2.0 (MPL 2.0)**
- **Implementation status:** truthful live-camera integration slice for backend registration/resolution, runtime probe startup, camera inventory, preview facts, and normalized default-frame behavior; replay/video-file support and long-lived tracking inference are still deferred

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

- replay/video-file integration remains out of scope for the current truthful live-camera slice and should still fail honestly
- long-lived MediaPipe tracking inference is still deferred; the normalized tracking frame may remain empty/default while the runtime probe lane is the only live implementation
- downstream consumers will still need a stable product/runtime registration pattern, but the tool-side backend-factory seam is now the ownership boundary for that later work
