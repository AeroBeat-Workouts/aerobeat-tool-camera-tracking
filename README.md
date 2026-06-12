# AeroBeat Tool Camera Tracking

This repo hosts the first **tool-owned camera-tracking contract and public-service seam** for the AeroBeat tool lane.

The current slice is intentionally narrow but now truthful: `CameraTracking` remains the **vendor-agnostic camera-tracking service** and **singleton shell** that owns lifecycle, preview attachment semantics, source coordination, backend resolution policy, and normalized public tracking payloads, while repo-local proving can register a real vendor backend factory and drive both live-camera and replay/video-file paths through the public tool API. The public frame still stays conservative while becoming continuous: repeated updates can advance the latest normalized frame over time, `detail.tracking_ready` can truthfully mean the current continuous lane is active, and the public frame still carries only the minimal real landmark fields the paired vendor slice can truly prove.

The tool surface is aligned to the approved API sketch in `.plans/bootstrap-architecture/CAMERA-TRACKING-API.md`, which defines the current state machine, required signals, config shape, preview ownership model, normalized tracking-frame payload, and the tool-owned camera-options response contract. The backend-factory seam keeps sharable ownership here at the repo root, and the tool now lazily auto-registers the mounted `mediapipe_python` vendor lane when consumers still request the default backend alias.

## Current contract scope

- `CameraTracking` singleton shell with lifecycle methods matching the first-pass API
- tool-owned backend registration and resolution keyed by public backend ID
- lazy default-backend bootstrap for the mounted `aerobeat-vendor-mediapipe-python` lane when `camera_tracking_default` resolves to `mediapipe_python`
- standardized top-level state constants (`idle`, `starting`, `running`, `restarting`, `stopping`, `error`)
- readiness/detail helpers for `backend_ready`, `preview_ready`, `tracking_ready`, and `source_ready`
- `CameraTrackingConfig` helpers for defaults and normalization, including tracker-layer pose/hand cadence, smoothing, association, and validity fields
- `CameraTrackingBackend` interface seam for concrete integrations
- `CameraTrackingFakeBackend` proving backend for repo-local tests
- preview attachment contract helpers that preserve the preferred `attach_preview_surface(node)` ownership model
- tool-owned `CameraTrackingPreviewPresenter` control plus `create_preview_presenter(options := {})` / `mount_preview_presenter(parent, options := {})` helper APIs for binding a session-owned preview surface + overlay in the right ownership layer
- preview-presenter hand-debug support that renders normalized per-side hand bbox + landmark overlays for both live and replay sessions and exposes `get_hand_debug_snapshot()`, `get_playback_status_snapshot()`, `get_replay_transport_capabilities_snapshot()`, `get_replay_transport_status_snapshot()`, and `map_bbox_to_preview_rect()` for downstream debug UIs
- stacked preview attachment semantics for shared live sessions: the most recent attached surface is active, and `detach_preview_surface()` restores the previous tool-owned attachment instead of collapsing the whole preview state
- normalized tracking-frame contract for downstream consumers and tests, with real sample timestamp/source/frame-size facts when the vendor runtime can prove them
- tool-owned landmark normalization that exposes only public `landmarks[].id/x/y/z/v` fields, keeps `tracking_state` snapshot-honest, and preserves richer body/head/confidence semantics as defaults
- tool-owned per-side hand normalization that converts raw vendor detections into stable `hands.left` / `hands.right` payloads with `tracking_valid`, `tracking_state`, `landmark_mode`, `frame_index`, `timestamp_ms`, `timestamp_seconds`, `stale_frames`, `stale_ms`, `grace_frames`, `grace_ms`, `stable_ms`, `association`, `landmarks`, and normalized-frame `bbox` geometry (`area_unit = normalized_frame_area`)
- tool-owned `get_camera_options(camera_id := "")` API that surfaces current live-camera mode options through a vendor-agnostic response shape (`requested_mode`, `reported_modes`, `probed_modes`, `selected_mode`, `actual_mode`) while delegating enumeration/probing to the mounted vendor backend
- `.testbed/` proving that `backend = mediapipe_python` plus `source.kind = live_camera` or `source.kind = video_file` can flow through the real vendor runtime probe lane truthfully
- `.testbed/` proving that `source.kind = session_manifest` replays manifest-declared `saved_tracking_frames` packages as a first-class B-mode source without re-running vendor inference

## Repository details

- **Type:** AeroBeat tool package
- **License:** **Mozilla Public License 2.0 (MPL 2.0)**
- **Implementation status:** truthful public-service slice for backend registration/resolution, runtime probe startup, camera inventory, preview facts, continuous update polling, normalized pose landmarks, tracker-layer hand transport, and replay transport exposure. Public frames now surface `timestamp_ms`, `timestamp_seconds`, `frame_index`, source identity, `frame_size`, public landmark `id/x/y/z/v`, tracker-facing pose/hand config defaults, normalized per-side hand payloads with association + stale/reacquire semantics, and replay transport capability/status delegation via `get_replay_transport_capabilities()`, `get_replay_transport_status()`, `play_replay()`, `pause_replay()`, `step_replay_frames(...)`, and `seek_replay_to_frame(...)`. Replay/video-file sessions still flow through the same public `CameraTracking` service/preview/state seam as live mode, and `source.kind = session_manifest` now replays manifest-declared `saved_tracking_frames` packages from saved artifacts instead of re-running vendor inference, while richer body/head/confidence guarantees remain deferred

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
/home/derrick/.openclaw/workspace/scripts/godotenv-sync --repo .testbed
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

## Tracker config schema docs

- `docs/tracker-config-schema.md` locks the v1 `aerobeat/camera_tracking_config` schema, profile defaults, and the parsing/validation boundary between this tracker repo and `aerobeat-input-camera-tracking`.

## Notes for later slices

- replay/video-file sessions are now accepted through the same public `CameraTracking` service seam as live mode, and replay consumers can now inspect explicit transport capabilities/status instead of relying only on passive playback snapshots
- the default transport fallback remains truthful: backends that only prove paused/time seek report `transport_mode=approx_time_seek` and explicitly refuse frame-addressed stepping until an exact lower layer exists
- public continuous updates are now supported only to the level the paired vendor runtime can prove; `get_tracking_frame()` surfaces the latest normalized frame and `tracking_updated` can repeat while the service remains running
- frame-level public tracking truth is still intentionally conservative at the top level, while per-side hand payloads now expose the richer tracker-owned states needed by downstream boxing slices (`disabled`, `idle`, `unavailable`, `reacquiring`, `tracked`, `stale`, `tracking_lost`)
- public landmarks are intentionally limited to `id/x/y/z/v`; `confidence`, `head_position`, `head_velocity`, `head_orientation`, and `skeleton` remain default/empty by design
- the preview presenter now mirrors the normalized hand payload directly, so proving/debug consumers should treat `hands.left/right`, `hand_tracking`, and playback status as the source of truth for hand bbox visualization before any boxing-specific state machine layers are added
- downstream consumers no longer need to paper over the current default `mediapipe_python` registration seam locally, but broader multi-vendor product/runtime registration policy may still evolve later
