# AeroBeat Tool Camera Tracking

This repo hosts the first **tool-owned camera-tracking contract and public-service seam** for the AeroBeat tool lane.

The current slice is intentionally narrow but now truthful: `CameraTracking` remains the **vendor-agnostic camera-tracking service** and **singleton shell** that owns lifecycle, preview attachment semantics, source coordination, backend resolution policy, and normalized public tracking payloads, while repo-local proving can register a real vendor backend factory and drive both live-camera and replay/video-file paths through the public tool API. The public frame still stays conservative while becoming continuous: repeated updates can advance the latest normalized frame over time, `detail.tracking_ready` can truthfully mean the current continuous lane is active, and the public frame still carries only the minimal real landmark fields the paired vendor slice can truly prove.

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
- stacked preview attachment semantics for shared live sessions: the most recent attached surface is active, and `detach_preview_surface()` restores the previous tool-owned attachment instead of collapsing the whole preview state
- normalized tracking-frame contract for downstream consumers and tests, with real sample timestamp/source/frame-size facts when the vendor runtime can prove them
- tool-owned landmark normalization that exposes only public `landmarks[].id/x/y/z/v` fields, keeps `tracking_state` snapshot-honest (`tracked` only when public landmarks exist), and preserves richer body/head/confidence semantics as defaults
- `.testbed/` proving that `backend = mediapipe_python` plus `source.kind = live_camera` or `source.kind = video_file` can flow through the real vendor runtime probe lane truthfully

## Repository details

- **Type:** AeroBeat tool package
- **License:** **Mozilla Public License 2.0 (MPL 2.0)**
- **Implementation status:** truthful public-service slice for backend registration/resolution, runtime probe startup, camera inventory, preview facts, continuous update polling, and normalized minimal-real-landmark behavior (`timestamp_ms`, source identity, `frame_size`, snapshot `tracking_state`, and public landmark `id/x/y/z/v` now surface when the sampled frame truly yields a pose); replay/video-file sessions now flow through the same public `CameraTracking` service/preview/state seam as live mode, while richer body/head/confidence guarantees remain deferred

## GodotEnv development flow

This repo follows the AeroBeat GodotEnv package convention.

- Canonical dev/test manifest: `.testbed/addons.jsonc`
- Installed dev/test addons: `.testbed/addons/`
- GodotEnv cache: `.testbed/.addons/`
- Hidden workbench project: `.testbed/project.godot`
- Repo-local unit tests: `.testbed/tests/`
- Repo-root sharable source: `src/`

The repo root remains the package/published boundary for downstream consumers. `.testbed/` is only the proving surface. Do real sharable work at the repo root, not inside `.testbed/addons/` mirrors.

GodotEnv now mounts this repo into `.testbed/addons/aerobeat-tool-camera-tracking` as the managed symlink declared in `.testbed/addons.jsonc`, so repo-local proving reads the live repo-root `src/` tree directly. Keep sharable source at the repo root; do not add addon-mirror glue inside `.testbed/addons/`.

### Restore dev/test dependencies

From the repo root:

```bash
/home/derrick/.openclaw/workspace/scripts/godotenv-sync
cd .testbed
godotenv addons install
cd ..
```

Use the sync helper first if the local toolchain or linked workspace packages need refreshing. `godotenv addons install` restores the managed symlink for this repo automatically via `.testbed/addons.jsonc`; no extra prepare step is required.

### Import smoke check

From the repo root:

```bash
godot --headless --path .testbed --import
```

### Run repo-local tests

From the repo root:

```bash
godot --headless --path .testbed --script addons/aerobeat-vendor-godot-unit-test/gut_cmdln.gd \
  -gdir=res://tests \
  -ginclude_subdirs \
  -gexit
```

## Notes for later slices

- replay/video-file sessions are now accepted through the same public `CameraTracking` service seam as live mode, but only to the minimal truthful level the paired vendor runtime can currently prove
- public continuous updates are now supported only to the level the paired vendor runtime can prove; `get_tracking_frame()` surfaces the latest normalized frame and `tracking_updated` can repeat while the service remains running
- frame-level public tracking truth is still intentionally conservative: only `tracked` (current normalized frame has landmarks) or `idle` (it does not) are claimed here
- public landmarks are intentionally limited to `id/x/y/z/v`; `confidence`, `head_position`, `head_velocity`, `head_orientation`, and `skeleton` remain default/empty by design
- downstream consumers will still need a stable product/runtime registration pattern, but the tool-side backend-factory seam is now the ownership boundary for that later work
