# AeroBeat Preview Frame Error Loop And Resource Churn

**Date:** 2026-06-06
**Status:** In Progress
**Last Updated:** 2026-06-06 23:14 EDT
**Blocked Reason:** None
**Agent:** `pico`

---

## Goal

Investigate and fix the preview-frame load/error loop in the boxing testing scene that appears after leaving the scene running for several minutes and may be causing CPU/resource churn on lower-power hardware.

---

## Overview

Derrick reported that when the boxing test scene is left running for a few minutes on Chip's laptop, errors accumulate in the terminal and the fans kick on. The first-pass diagnosis is **not yet a confirmed memory leak**. The strongest immediate seam is a repeated preview-image load failure loop in the tool-owned preview presenter path.

The likely owner is `aerobeat-tool-camera-tracking` because the error seam points at `src/CameraTrackingPreviewPresenter.gd::_update_preview_texture()`, which repeatedly loads a preview image from disk. The screenshot evidence suggests the preview image can be read while corrupt/partial or otherwise unavailable, causing repeated image-load failures and likely log/CPU churn. Derrick's fresh-session clarification is that the bug was observed from the `aerobeat-input-camera-tracking` boxing validation scene, but the actual fault may still live in this tool repo or its downstream dependency `aerobeat-vendor-mediapipe-python`; repro should prove the true owner rather than assume the consumer scene is the owner.

The slice should stay narrow and truth-oriented: reproduce, identify whether preview writes are atomic, harden the preview load path against transient corrupt files, reduce repeated identical error spam, and verify whether there is any real memory/resource growth over time. If dependency refreshes are needed during validation, use the `godotenv-sync` script so addon/dependency updates avoid unnecessary Godot UID/import noise.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Derrick's screenshot showing accumulated preview/image-load errors after leaving the boxing test scene running | `/home/derrick/.openclaw/workspace/.temp/nerve-uploads/2026/06/07/image-cd8391a7.png` |
| `REF-02` | Derrick's repro description: leave the boxing test scene running for a few minutes on Chip's laptop, errors accumulate, fans kick on, suspected memory leak | User report in current session on 2026-06-06 21:47 EDT |
| `REF-03` | Tool-owned preview presenter seam that loads preview images from disk | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingPreviewPresenter.gd` |
| `REF-04` | Likely preview presenter update path around `_update_preview_texture()` | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingPreviewPresenter.gd` |
| `REF-05` | Consumer repro surface where Derrick observed the bug: boxing validation scene in `aerobeat-input-camera-tracking` | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking` |
| `REF-06` | Possible lower-layer dependency owner if the preview/prod seam resolves below the tool repo | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python` |

---

## Initial Evidence / Repro Notes

- Repro from Derrick: leave the boxing input testing scene running for several minutes.
- Observed result: terminal errors accumulate over time and Chip's laptop fans kick on.
- Current suspicion from Derrick: possible memory leak.
- Current leading technical hypothesis from Pico: repeated preview image load failures / file-race in the preview presenter may be creating a hot error loop and CPU churn; memory/resource accumulation still needs to be proven rather than assumed.
- The screenshot evidence specifically points toward repeated failures loading the preview frame image, including at least one corrupt-file style failure.

---

## Tasks

### Task 1: Reproduce and classify the failure mode

**Bead ID:** `aerobeat-tool-camera-tracking-jbb`
**SubAgent:** `primary`
**Role:** `coder`
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`
**Prompt:** Reproduce the boxing-scene preview-frame error accumulation from the `aerobeat-input-camera-tracking` boxing validation surface, determine whether the dominant issue is (a) preview image read/write race, (b) repeated identical error loop/log spam, (c) real memory/resource accumulation, or (d) a combination. Capture exact evidence, prove the true owner seam across input/tool/vendor, and keep work/queryable state on bead `aerobeat-tool-camera-tracking-jbb` by claiming it on start.

**Folders Created/Deleted/Modified:**
- `.plans/`
- any nondurable repro artifact folders if needed

**Files Created/Deleted/Modified:**
- this plan
- optional nondurable repro notes/artifacts if needed

**Status:** ✅ Complete

**Results:** 2026-06-06 22:03 EDT — Execution resumed from the fresh-session handoff. Created owner-repo Beads for Tasks 1-4 (`aerobeat-tool-camera-tracking-jbb`, `aerobeat-tool-camera-tracking-nhe`, `aerobeat-tool-camera-tracking-f5x`, `aerobeat-tool-camera-tracking-1yt`) with Task 1 → Task 2 → Task 3 → Task 4 dependencies. Launching coder investigation now from the tool-owner repo while keeping the repro truth anchored to the input-scene surface and vendor seam possibility.

2026-06-06 22:14 EDT — Diagnosis complete without code changes. The dominant issue is **(d) a combination of (a) preview image read/write race plus (b) repeated identical error-loop/log spam**, with **no concrete evidence yet that (c) real memory/resource accumulation is the primary bug**. Evidence:
- Tool seam `src/CameraTrackingPreviewPresenter.gd::_update_preview_texture()` reloads the preview whenever `image_revision` changes and calls `Image.load(image_path)` directly against the live preview file (`REF-03`, `REF-04`). On load failure it returns immediately without backoff, dedupe, or failure-state caching, so the next revision retries again.
- Vendor seam `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/runtime/mediapipe_runtime_probe.py::_write_preview_frame()` rewrites the same `preview_frame.jpg` path in place with `cv2.imwrite(...)` and then publishes a fresh millisecond `image_revision`; writes are **not atomic** and do not use temp-file + rename (`REF-06`).
- Vendor backend seam `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/src/MediaPipePythonCameraTrackingBackend.gd::_refresh_runtime_snapshot_if_running()` emits `preview_changed` whenever the preview descriptor changes, so new revisions keep driving the presenter retry loop from the consumer scene.
- Empirical repro: in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.temp-preview-race-repro/`, I ran `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/.venv/bin/python .temp-preview-race-repro/writer.py` to overwrite one JPEG path in place with `cv2.imwrite(...)` while `godot --headless --script .temp-preview-race-repro/read_loop.gd` repeatedly called `Image.load()` on the same path. Result: repeated Godot `Error loading image` plus `Condition "src_image_len == 0" is true. Returning: ERR_FILE_CORRUPT` errors, matching `REF-01`'s failure shape. Repro artifacts are nondurable temp files under `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.temp-preview-race-repro/` and were not committed.
- Code inspection does **not** show unbounded collection growth in the hot path: the presenter replaces one `Texture2D`, the backend stores one latest preview descriptor/frame, and the vendor snapshot retains only the latest preview descriptor. That does not rule out temporary CPU/allocator churn from repeated decode attempts and texture recreation, but it does make a primary leak diagnosis unproven in this slice.
- Follow-up work was materialized as bead `aerobeat-tool-camera-tracking-jbb.1` (`Vendor seam: make preview frame publication atomic in aerobeat-vendor-mediapipe-python`), and it now blocks Task 2's existing bead `aerobeat-tool-camera-tracking-nhe` so the primary owner seam is explicit.

Owner recommendation: Task 2 should be **layered across repos with the primary correctness fix in `aerobeat-vendor-mediapipe-python`** (atomic preview writes or publish-after-rename), plus a defensive hardening pass in `aerobeat-tool-camera-tracking` to suppress repeated identical load failures/backoff/log churn if a transient bad frame still appears.

---

### Task 2: Harden preview-frame load/write behavior in the owning tool seam

**Bead ID:** `aerobeat-tool-camera-tracking-nhe`
**SubAgent:** `primary`
**Role:** `coder`
**References:** `REF-01`, `REF-03`, `REF-04`, `REF-05`, `REF-06`
**Prompt:** Implement the narrowest owner-correct fix so the preview presenter and preview producer no longer enter a hot failure loop on transient/corrupt preview frames. **Start with child bead `aerobeat-tool-camera-tracking-jbb.1` for the primary vendor-owner correction in `aerobeat-vendor-mediapipe-python` (atomic preview publish/write semantics), then use bead `aerobeat-tool-camera-tracking-nhe` only for any remaining tool-side defensive hardening** such as repeated-failure suppression/backoff and truthful error handling. Avoid cosmetic masking; preserve a clear owner boundary in code and bead state.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/runtime/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/runtime/tests/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/.beads/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/runtime/mediapipe_runtime_probe.py`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/runtime/tests/test_mediapipe_runtime_probe.py`
- this plan

**Status:** ✅ Complete

**Results:** 2026-06-06 22:10 EDT — Landed the primary owner-correct fix in vendor repo bead `aerobeat-vendor-mediapipe-python-aub` after initializing repo-local Beads state there because the durable code change belongs to `aerobeat-vendor-mediapipe-python`, not the tool presenter. Changed `runtime/mediapipe_runtime_probe.py::_write_preview_frame()` to publish `preview_frame.jpg` via temp-file write + `os.replace(...)` atomic swap rather than writing the live JPEG path in place. Added a targeted Python unit test in `runtime/tests/test_mediapipe_runtime_probe.py` that proves the runtime writes a temp file first, atomically replaces the final preview path, and leaves no temp artifact behind.

Validation run in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python`:
- `python3 -m unittest runtime.tests.test_mediapipe_runtime_probe.MediaPipeRuntimeProbeTests.test_write_preview_frame_writes_temp_file_then_atomically_replaces_final_path`
- `python3 -m unittest runtime.tests.test_mediapipe_runtime_probe`

Owner-seam decision: **no tool-side presenter change was required in this slice**. The reproduced corrupt-image loop was driven by the vendor writing a live JPEG in place; once preview publication is atomic, the presenter no longer has to defend against the same transient partial-file condition on every revision. Any future residual churn would be a separate hardening slice, not part of this narrow owner-correct repair.

---

### Task 3: QA the long-running boxing-scene preview path

**Bead ID:** `aerobeat-tool-camera-tracking-f5x`
**SubAgent:** `primary`
**Role:** `qa`
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`
**Prompt:** QA the long-running boxing-scene preview path after the fix from the same boxing validation repro surface. Verify the error accumulation is gone or materially reduced, confirm fans/CPU churn no longer spike under the same repro, and report whether any actual memory/resource growth remains. Claim bead `aerobeat-tool-camera-tracking-f5x` on start.

**Folders Created/Deleted/Modified:**
- `.plans/`
- QA artifacts only if needed

**Files Created/Deleted/Modified:**
- this plan
- optional nondurable QA notes/artifacts if needed

**Status:** ✅ Complete

**Results:** 2026-06-06 22:24 EDT — QA completed on the consumer repro surface and **did not clear the slice**. The consumer workbench is definitely exercising the landed vendor change from `e6b69ee`: `.testbed/addons.jsonc` installs `aerobeat-vendor-mediapipe-python` from the sibling repo via `source: "symlink"`, and the consumer-installed `runtime/mediapipe_runtime_probe.py` matched the vendor repo copy byte-for-byte. Because the symlinked install was already current, **no dependency refresh was needed and `godotenv-sync` was not run**.

Exact QA repro used:
- Repo/runtime: `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking`
- Scene: `res://scenes/boxing_proving.tscn` from the hidden workbench `.testbed/`
- Command: `godot --headless --path .testbed res://scenes/boxing_proving.tscn`
- Short smoke run: 25s captured in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.temp-preview-fix-qa/smoke.log`
- Timed long-run validation: 3 minutes sampled every 15s, artifacts under `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.temp-preview-fix-qa/longrun-20260606-221537/`

Observed behavior after the vendor change:
- The original corrupt-preview-file Godot error shape from `REF-01` (`Error loading image`, `ERR_FILE_CORRUPT`, `Condition "src_image_len == 0"`) **did not appear** in either the smoke run or the 3-minute run.
- However, the run now fails in the vendor runtime during preview publication with repeated startup-time JSON health errors: `OpenCV(4.13.0) ... could not find a writer for the specified extension in function 'imwrite_'`.
- The error shape is consistent with the atomic preview helper writing to a temp path that ends in `.tmp` rather than `.jpg`, which prevents OpenCV from inferring an image writer from the filename extension.
- In the 3-minute run, the boxing harness printed `Boxing harness live`, but the runtime emitted two `runtime_probe_exception` JSON errors at `2026-06-07T02:15:39Z` and `2026-06-07T02:15:41Z`; the log contained 29 total lines and 2 preview-publication failures, so **the old multi-minute error accumulation loop was not reproduced in this headless fixture run because the runtime fails earlier under the new publish path**.

Resource / churn assessment from the timed run:
- Godot process RSS stayed flat at `145992 KB` from 15s through 180s.
- `%CPU` settled from `6.4` at 15s down to `4.1` by 2-3 minutes and then stayed flat.
- This run does **not** show ongoing memory growth or a worsening long-run churn pattern, but it also does **not** validate the fix as acceptable because preview publication is currently broken by the new temp-write path.
- Fan/noise could not be meaningfully assessed from this headless host run; only CPU/RSS/process stability were measured.

Truthful QA conclusion:
- The previous preview-frame corrupt-read accumulation appears materially reduced in this repro path because the runtime no longer writes the live JPEG in place.
- **But the bug is not resolved enough to clear QA**: the landed atomic publish path currently introduces a new preview-frame failure mode (`cv2.imwrite` cannot write the temp filename), so the slice remains blocked pending a follow-up fix in the vendor helper.
- No durable repo changes were required for QA setup; artifacts were left nondurable under the consumer repo’s `.temp-preview-fix-qa/` folder and were not committed.

2026-06-06 22:33 EDT — Reran the **same consumer boxing repro surface after the temp-extension fix** now landed in vendor commit `b380fe0`, again without any dependency refresh because the workbench still points at the sibling vendor repo via `.testbed/addons.jsonc` `source: "symlink"` and the installed `runtime/mediapipe_runtime_probe.py` is the same file as `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/runtime/mediapipe_runtime_probe.py` (`samefile == true`). Exact rerun:
- Repo/runtime: `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking`
- Scene: `res://scenes/boxing_proving.tscn` from `.testbed/`
- Command: `godot --headless --path .testbed res://scenes/boxing_proving.tscn`
- Artifacts: `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.temp-preview-fix-qa-rerun/longrun-20260606-222914/`

Rerun outcome:
- **Preview publication now succeeds again.** The session snapshot for `/home/derrick/.local/share/godot/app_userdata/AeroBeat Camera Tracking Testbed/mediapipe_python_runtime_bridge/sessions/session-1780799380.85908-1061613/runtime_snapshot.json` contains a populated `preview_descriptor` with `image_path`, `image_revision`, `image_format: "jpg"`, `image_width: 960`, and `image_height: 540`; the sibling `preview_frame.jpg` exists on disk and `last_error` is `null`.
- The old corrupt-preview signature from `REF-01` stayed gone: no `ERR_FILE_CORRUPT`, no `Condition "src_image_len == 0"`, and no `Error loading image` lines appeared in either the 25s smoke log or the 180s long-run log.
- The temp-extension regression also stayed gone: no `runtime_probe_exception`, no `could not find a writer for the specified extension`, and no `imwrite_` errors appeared in the rerun logs.
- **But there is still unacceptable long-run churn on this headless repro surface.** Process samples in `ps-samples.csv` show Godot pinned near one full core while RSS climbed steadily for the entire 3-minute run: `159628 KB / 84.6% CPU` at 15s, `228208 KB / 96.1% CPU` at 60s, `317224 KB / 98.0% CPU` at 120s, and `404524 KB / 98.6% CPU` at 180s.
- Because preview publication is now working and the old file-corruption loop is absent, this remaining churn is **not** the same corrupt-preview or temp-extension failure mode. It still blocks QA from calling the slice healthy, and audit should **not** proceed yet on a "fully resolved" claim.

2026-06-06 23:14 EDT — Reran QA **after the tool-side polling fix** from tool commit `b290f00`, again confirming the consumer workbench is on the live sibling repos via `.testbed/addons.jsonc` `source: "symlink"` and direct `samefile` checks for both:
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.testbed/addons/aerobeat-tool-camera-tracking/src/CameraTracking.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.testbed/addons/aerobeat-vendor-mediapipe-python/runtime/mediapipe_runtime_probe.py`

Because both addon installs already resolve to the latest sibling repo files, **no dependency refresh was needed and `godotenv-sync` was not run** for this rerun either.

Exact post-polling-fix QA repro used:
- Repo/runtime: `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking`
- Artifact root: `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.temp-post-polling-fix-qa/20260606-225629/`
- Boxing command: `godot --headless --path .testbed res://scenes/boxing_proving.tscn`
- Flow command: `godot --headless --path .testbed res://scenes/flow_proving.tscn`
- Sampling method: 180-second runs with process samples every 15 seconds for the Godot parent plus spawned `mediapipe_runtime_probe.py` child, captured in each scene folder's `ps-samples.csv`; logs captured as `godot.log`.

Post-polling-fix rerun outcome:
- **Preview correctness remains fixed.** Both scene logs only reached their normal harness-live lines (`[ProvingHarness][Boxing] Boxing harness live` and `[ProvingHarness][Flow] Flow harness live`). Neither log contained the old corrupt-preview signature from `REF-01` (`Error loading image`, `ERR_FILE_CORRUPT`, `Condition "src_image_len == 0"`) or the temp-extension regression signature (`runtime_probe_exception`, `could not find a writer for the specified extension`, `imwrite_`).
- Latest runtime snapshots under `/home/derrick/.local/share/godot/app_userdata/AeroBeat Camera Tracking Testbed/mediapipe_python_runtime_bridge/sessions/` still show `last_error: null` and populated `preview_descriptor` objects that point at real `preview_frame.jpg` files with `image_format: "jpg"`, so the preview corruption bug stayed fixed during the rerun.
- **The polling fix did not materially reduce the headless churn enough to clear QA.** Godot still saturates roughly one CPU core and its RSS keeps climbing for the full 180-second window in both repro scenes:
  - Boxing `ps-samples.csv`: `164096 KB / 88.8% CPU` at 15s → `223156 KB / 96.5% CPU` at 60s → `300340 KB / 98.4% CPU` at 180s.
  - Flow `ps-samples.csv`: `221012 KB / 88.8% CPU` at 15s → `446632 KB / 96.5% CPU` at 60s → `748856 KB / 98.0% CPU` at 180s.
- Before/after comparison versus the pre-polling-fix diagnosis artifacts in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.temp-churn-diagnosis/` shows only a small short-run change at the 60-second mark, not a material behavior change:
  - Boxing Godot at 60s: `235652 KB / 96.3% CPU` before → `223156 KB / 96.5% CPU` after.
  - Flow Godot at 60s: `462428 KB / 96.4% CPU` before → `446632 KB / 96.5% CPU` after.
- The vendor child baseline also remains essentially unchanged, which matches the earlier diagnosis that the vendor runtime is its own secondary seam:
  - Boxing Python at 60s: `550976 KB / 210% CPU` before → `557864 KB / 213% CPU` after.
  - Flow Python at 60s: `472644 KB / 283% CPU` before → `469996 KB / 282% CPU` after.

Truthful QA conclusion after the post-polling-fix rerun:
- **Preview corruption is still fixed** and the temp-extension regression remains fixed.
- **The bug is not QA-clear overall.** The tool-side polling fix from `b290f00` did not materially change the long-run churn shape on the two required headless consumer repro surfaces, so audit should still not treat the overall bug as resolved.
- The next slice should stay focused on the already-materialized vendor baseline/performance bead (`aerobeat-vendor-mediapipe-python-06l`) rather than treating it as optional follow-up, because the remaining measured churn is now dominated by the vendor runtime/high-baseline seam after preview correctness and the first tool polling seam were both addressed.

---

### Task 3B: Repair atomic temp-extension regression in vendor preview publish path

**Bead ID:** `aerobeat-tool-camera-tracking-82a`
**SubAgent:** `primary`
**Role:** `coder`
**References:** `REF-05`, `REF-06`
**Prompt:** Repair the regression introduced by the first atomic preview publish fix: OpenCV cannot infer the writer when the temp filename loses the `.jpg` extension. Keep the atomic publish behavior, but make the temp-write path preserve a writable image extension so preview publication works again. Keep this narrow and owner-correct in `aerobeat-vendor-mediapipe-python`, then hand back to QA on the same boxing validation repro surface.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/runtime/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/runtime/tests/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/runtime/mediapipe_runtime_probe.py`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/runtime/tests/test_mediapipe_runtime_probe.py`
- this plan

**Status:** ✅ Complete

**Results:** 2026-06-06 22:28 EDT — Repaired the vendor atomic-preview regression narrowly in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python` by keeping the atomic `os.replace(...)` publish path but changing the temp image path construction so it preserves the final file extension. `_write_image_atomic(...)` now writes preview temps as `preview_frame.<pid>.<time_ns>.jpg` instead of `preview_frame.jpg.<pid>.<time_ns>.tmp`, which restores OpenCV encoder inference while preserving same-directory atomic replacement semantics. Updated the targeted unit test to assert both behaviors: the write still targets a distinct temp file and the temp filename still ends with `.jpg`.

Validation run in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python`:
- `python3 -m unittest runtime.tests.test_mediapipe_runtime_probe.MediaPipeRuntimeProbeTests.test_write_preview_frame_writes_temp_file_then_atomically_replaces_final_path`
- `python3 -m unittest runtime.tests.test_mediapipe_runtime_probe`

Commits:
- `b380fe0` — Preserve JPEG extension during atomic preview writes

Next handoff: QA should rerun immediately against the same boxing validation repro surface because the prior blocker was specifically the temp-extension regression now fixed in the vendor owner seam.

---

### Task 3C: Diagnose sustained CPU/RSS churn after preview-frame race fix

**Bead ID:** `aerobeat-tool-camera-tracking-8fg`
**SubAgent:** `primary`
**Role:** `coder`
**References:** `REF-02`, `REF-05`, `REF-06`
**Prompt:** The corrupt-preview bug is now fixed, but QA still shows sustained long-run CPU/RSS churn in the headless boxing repro (`84.6% CPU / 159628 KB` at 15s rising to `98.6% CPU / 404524 KB` at 180s). Diagnose the dominant owner seam for that remaining churn truthfully. Determine whether it is primarily preview-related, vendor-runtime-related, consumer-scene-related, or some combination. Keep this as a diagnosis-first slice; do not mix it with YAML optimization work unless the evidence proves that is the direct cause.

**Folders Created/Deleted/Modified:**
- `.plans/`
- optional nondurable profiling/artifact folders if needed

**Files Created/Deleted/Modified:**
- this plan
- optional nondurable diagnosis artifacts if needed

**Status:** ✅ Complete

**Results:** 2026-06-06 22:50 EDT — Diagnosis completed without durable code changes. The remaining churn is **not preview-related as the dominant seam** and **not boxing-scene-specific**. It is a **combination** of (1) a shared tool/contract poll loop that drives the Godot-side churn and (2) a separate vendor-runtime baseline cost floor that remains high even with preview publication disabled.

Exact evidence gathered:
- Shared consumer/tool repro comparison in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.temp-churn-diagnosis/`:
  - Boxing scene run `boxing-20260606-223809/ps-samples.csv` via `godot --headless --path .testbed res://scenes/boxing_proving.tscn` showed Godot rising from `169040 KB / 88.8% CPU` at 15s to `235652 KB / 96.3% CPU` at 60s, while the spawned Python runtime sat around `544536–550976 KB / 210–216% CPU`.
  - Flow scene run `flow-20260606-223809/ps-samples.csv` via `godot --headless --path .testbed res://scenes/flow_proving.tscn` showed the same Godot-side churn shape despite a different consumer scene: `225444 KB / 88.7% CPU` at 15s to `462428 KB / 96.4% CPU` at 60s, with Python still around `456892–472644 KB / 274–283% CPU`.
  - Because both scenes reproduce the same Godot-side saturation, the issue is **not specific to the boxing scene’s debug shell**.
- Tool seam inspection proves an uncapped poll path in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTracking.gd`: `_process()` calls `_refresh_from_backend_if_running(true)` every process frame, and that calls `_backend.get_tracking_frame()` each frame while running.
- Vendor bridge inspection shows that backend getter path reaches `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/src/MediaPipePythonCameraTrackingBackend.gd::_refresh_runtime_snapshot_if_running()` and then `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/src/MediaPipePythonRuntimeBridge.gd::poll_snapshot()`, which rereads/parses the runtime snapshot file each time. There is **no cadence limit in the continuous-session refresh path**, so headless uncapped `_process()` turns into uncapped snapshot polling.
- Direct vendor-runtime comparison isolated preview cost in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/.temp-churn-diagnosis/vendor-preview-compare-20260606-224641/` by running `runtime/mediapipe_runtime_probe.py` directly for 60s with identical replay input and only toggling `preview.enabled`:
  - `preview-on/ps-samples.csv`: `542884 KB / 217% CPU` at 15s to `545400 KB / 210% CPU` at 60s.
  - `preview-off/ps-samples.csv`: `541204 KB / 208% CPU` at 15s to `550292 KB / 201% CPU` at 60s.
  - Preview publication changes the runtime cost only slightly, so **preview is a secondary cost, not the dominant remaining churn owner**.

Truthful owner recommendation:
- **Primary immediate fix seam:** `aerobeat-tool-camera-tracking` (`src/CameraTracking.gd`) should stop polling the vendor backend at uncapped frame rate during continuous sessions. This is the clearest owner-correct explanation for the Godot-side ~1-core saturation and steady RSS growth visible in both flow and boxing headless repros.
- **Secondary follow-up seam:** `aerobeat-vendor-mediapipe-python` still has a high continuous-runtime floor (~200% CPU and ~540–550 MB RSS over 60s) even with preview disabled, so vendor profiling/optimization is warranted as a separate slice after the shared polling seam is fixed.
- **Not recommended as the next owner seam:** boxing-scene-specific UI/debug cleanup or preview correctness work; the evidence did not make either the dominant cause of the remaining churn.

Follow-up work materialized:
- `aerobeat-tool-camera-tracking-1nv` — Rate-limit CameraTracking backend polling in continuous sessions
- `aerobeat-vendor-mediapipe-python-06l` — Profile continuous MediaPipe runtime CPU/RSS baseline with preview correctness fixed

This makes Task 3C diagnosis-complete and fix-ready: the tool-side polling bead is ready to launch immediately, and the vendor baseline bead should remain a separate downstream performance slice.

---

### Task 3D: Rate-limit continuous CameraTracking backend polling

**Bead ID:** `aerobeat-tool-camera-tracking-1nv`
**SubAgent:** `primary`
**Role:** `coder`
**References:** `REF-05`, `REF-06`
**Prompt:** Implement the narrowest owner-correct fix in `aerobeat-tool-camera-tracking` so continuous sessions do not poll the backend snapshot on every `_process()` frame. Cadence-gate `_refresh_from_backend_if_running(true)` enough to stop uncapped headless polling churn while preserving live tracking correctness, preview behavior, and explicit freshness paths for public getters / replay controls.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/tests/`
- `src/`

**Files Created/Deleted/Modified:**
- `src/CameraTracking.gd`
- `.testbed/tests/test_CameraTracking.gd`
- this plan

**Status:** ✅ Complete

**Results:** 2026-06-06 23:00 EDT — Landed the tool-owner fix in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking` by cadence-gating continuous `_process()` polling in `src/CameraTracking.gd` to a default 33 ms interval instead of reparsing backend snapshots every render frame. The new behavior is intentionally narrow:
- `_process()` now calls `_refresh_from_backend_if_running(true, false)` so continuous polling is allowed only when the refresh interval has elapsed.
- Explicit freshness paths still bypass the cadence gate by forcing refreshes through the existing public contract surfaces (`get_playback_status()`, `get_replay_transport_capabilities()`, `get_replay_transport_status()`, replay step/seek), preserving state truth when a consumer explicitly asks for it.
- Signal-driven updates remain immediate because backend `tracking_updated` still flows through `_on_backend_tracking_updated(...)` without waiting for the cadence gate.

Targeted regression coverage was added in `.testbed/tests/test_CameraTracking.gd`:
- preserved the existing continuous-update test by setting the test backend interval override to `0` so the original per-call semantics still prove the non-gated path when desired.
- tightened the getter-caching test to run under a nonzero interval.
- added `test_camera_tracking_rate_limits_continuous_process_polling_but_forces_explicit_refreshes`, which proves repeated `_process()` calls inside the interval only poll once while explicit public refresh getters still force backend reads immediately.

Validation run in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`:
- `godot --headless --path .testbed --script addons/aerobeat-vendor-godot-unit-test/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gtest=res://tests/test_CameraTracking.gd -gexit`
- Result: `40/40` tests passed.

Commits:
- Pending

QA handoff: **yes, QA should rerun immediately** against the same headless boxing and flow repro surfaces because this slice directly changes the diagnosed primary Godot-side churn owner seam after preview correctness was already fixed.

### Task 3E: Reduce vendor baseline cadence defaults after preview correctness fix

**Bead ID:** `aerobeat-vendor-mediapipe-python-06l`
**SubAgent:** `primary`
**Role:** `coder`
**References:** `REF-05`, `REF-06`
**Prompt:** Profile the remaining vendor-owned continuous runtime baseline after the preview corruption and temp-extension bugs are fixed, then land the narrowest owner-correct vendor change that materially reduces sustained CPU/RSS churn without reopening the preview bug or widening into unrelated tuning.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/runtime/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/runtime/tests/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/src/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/.testbed/tests/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/runtime/mediapipe_runtime_probe.py`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/src/MediaPipePythonConfig.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/runtime/tests/test_mediapipe_runtime_probe.py`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/.testbed/tests/test_mediapipe_python_runtime_bridge.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/README.md`
- this plan

**Status:** ✅ Complete

**Results:** 2026-06-06 23:39 EDT — Diagnosed the remaining vendor baseline by differential replay profiling from the vendor repo instead of guessing. Using the same boxed replay input as the earlier direct-runtime probe, I compared vendor-owned runtime knobs under `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/.temp-churn-diagnosis/`:
- `vendor-runtime-knob-sweep-20260606-2306/` showed preview/state writes are secondary costs (`baseline` `553196 KB / 215% CPU` at 60s vs `state_5_preview_5` `551176 KB / 203% CPU`), but the largest trustworthy owner-side lever is continuous tracking cadence, not the already-fixed preview publish path.
- `vendor-runtime-fps-sweep-20260606-2319/` showed lowering vendor cadence has a material direct-runtime effect while preserving the same owner boundary: `baseline_30_30_30` measured `547048 KB / 212% CPU` at 60s, `tracking_20_state_20_preview_10` measured `547056 KB / 207% CPU`, and `tracking_15_state_15_preview_10` measured `545428 KB / 184% CPU`. An even lower `tracking_10_state_10_preview_5` run reached `545600 KB / 122% CPU`, but that was a larger behavioral step than needed for this slice.

Landed the narrowest durable fix in `aerobeat-vendor-mediapipe-python`: reduced the **default** vendor continuous-session cadence from `30/30/30` to `15/15/10` for tracking/state/preview. This keeps all existing knobs and override paths intact, but makes the default runtime cheaper on the current consumer repros without changing the already-correct preview publication semantics.

Repo-local validation in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python`:
- `python3 -m unittest runtime.tests.test_mediapipe_runtime_probe`
- `godot --headless --path .testbed --script addons/aerobeat-vendor-godot-unit-test/gut_cmdln.gd -gtest=res://tests/test_mediapipe_python_runtime_bridge.gd -gexit`

Consumer repro confirmation in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking` proved the live request path now picks up the reduced vendor defaults with no dependency refresh because `.testbed/addons.jsonc` still uses sibling-repo symlinks:
- 60s artifacts: `.temp-vendor-default-cadence-qa/20260606-232144/`
- 180s artifacts: `.temp-vendor-default-cadence-qa-180s/20260606-232423/`
- Both boxing and flow runtime `request.json` files now show `tracking_max_fps=15`, `state_update_max_fps=15`, and `preview_max_fps=10`.
- Vendor-child CPU fell materially on the flow repro (`282%` at 60s before → `131%` after, `139%` at 180s) and modestly on boxing (`213%` at 60s before → `195%` after, `193%` at 180s). RSS stayed roughly flat in the vendor child (~`454-551 MB`) instead of being the dominant rising surface.
- Truthful limitation: the overall consumer Godot parent still shows substantial long-run churn, especially on flow RSS, so this slice improves the vendor baseline seam but does **not** prove the full cross-repo bug is QA-clear by itself.

QA handoff: **yes, QA should rerun immediately** on the same 180-second boxing + flow surfaces because the vendor-owner baseline request path is now materially cheaper and the next measured pass can separate remaining Godot/tool/consumer churn from the vendor floor more honestly.

### Task 3A: Optional follow-up — expose preview-frame performance knobs via YAML

**Bead ID:** `Pending`
**SubAgent:** `primary`
**Role:** `coder`
**References:** `REF-03`, `REF-05`, `REF-06`
**Prompt:** After the preview-frame correctness fix is QA-cleared, audit which preview-frame publication settings are currently hard-coded or otherwise not fully exposed through the relevant YAML/config surfaces. Then implement the owner-correct config exposure for performance-sensitive knobs Derrick specifically called out, such as preview resolution, compression/quality, and any closely related publication settings that materially affect runtime cost. Keep this as a separate optimization slice from the correctness repair, and use `godotenv-sync` if dependency refreshes are needed during validation to avoid unnecessary Godot UID/import noise.

**Folders Created/Deleted/Modified:**
- `.plans/`
- vendor/runtime and config surfaces as appropriate after audit

**Files Created/Deleted/Modified:**
- Pending; owner seam to be proven during the follow-up audit
- this plan

**Status:** ⏳ Pending

**Results:** Added from Derrick feedback on 2026-06-06 22:11 EDT as a distinct optimization follow-up. Do not mix this into the correctness bugfix QA/audit gate.

---

### Task 4: Independently audit final readiness for the preview-frame bug

**Bead ID:** `aerobeat-tool-camera-tracking-1yt`
**SubAgent:** `primary`
**Role:** `auditor`
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`
**Prompt:** Independently audit the preview-frame bug fix. Confirm the root cause diagnosis matches the evidence, confirm the fix lives in the correct owner seam across input/tool/vendor, and confirm the long-running boxing-scene repro is clean enough to land. Claim bead `aerobeat-tool-camera-tracking-1yt` on start and close it only if the slice is truly done.

**Folders Created/Deleted/Modified:**
- `.plans/`
- audit artifacts only if needed

**Files Created/Deleted/Modified:**
- this plan
- optional nondurable audit notes/artifacts if needed

**Status:** ⏳ Pending

**Results:** Pending.

---

## Final Results

**Status:** ⚠️ Planned / Not Yet Executed

**What We Built:** Created a fresh owner-repo plan for the new preview-frame error-loop / possible resource-churn bug, with screenshot evidence and Derrick's repro notes recorded for the next clean session.

**Reference Check:** `REF-01` and `REF-02` are captured directly in this plan so the next session can begin from the actual evidence instead of memory. `REF-03` / `REF-04` record the likely owning seam in the tool repo.

**Commits:**
- Pending

**Lessons Learned:** Treat this as a fresh workstream. Do not assume "memory leak" until the preview read/write error loop and its resource effects are separated and measured.

---

*Drafted on 2026-06-06*