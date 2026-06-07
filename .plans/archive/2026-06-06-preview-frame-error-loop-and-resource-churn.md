# AeroBeat Preview Frame Error Loop And Resource Churn

**Date:** 2026-06-06
**Status:** Complete
**Last Updated:** 2026-06-07 00:20 EDT
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

2026-06-06 23:42 EDT — Completed the required **post-vendor-cadence-fix 180-second QA rerun** on the consumer repro surface and the bug is **still not QA-clear**.

Refresh / code-truth check before rerun:
- Consumer repo: `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking`
- Tool repo at rerun: `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking` @ `f753bf1` (contains `b290f00` polling fix plus plan-only follow-up commit)
- Vendor repo at rerun: `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python` @ `0c8dfe6`
- `.testbed/addons.jsonc` still installs both addons from sibling repos with `source: "symlink"`.
- Direct `os.path.samefile(...)` checks confirmed the consumer-installed addon files are the same live files as:
  - `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTracking.gd`
  - `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/runtime/mediapipe_runtime_probe.py`
- Because the consumer testbed was already on the live sibling repos, **no dependency refresh was needed and `godotenv-sync` was not run**.

Exact rerun commands / artifacts:
- Artifact root: `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.temp-vendor-cadence-rerun-qa/20260606-233512/`
- Boxing command: `godot --headless --path .testbed res://scenes/boxing_proving.tscn`
- Flow command: `godot --headless --path .testbed res://scenes/flow_proving.tscn`
- Sampling method: 180-second runs with process samples every 15 seconds for both the Godot parent and spawned `mediapipe_runtime_probe.py` child, captured in each scene folder’s `ps-samples.csv`; logs captured as `godot.log`; runtime snapshots copied as `runtime_snapshot.json`.

Preview correctness / corruption truth gate:
- `rg` across the fresh artifact root found **no** `Error loading image`, `ERR_FILE_CORRUPT`, `Condition "src_image_len == 0"`, `runtime_probe_exception`, `could not find a writer for the specified extension`, or `imwrite_` lines.
- Boxing runtime snapshot: `last_error: null`, populated `preview_descriptor`, and a real `preview_frame.jpg` at `/home/derrick/.local/share/godot/app_userdata/AeroBeat Camera Tracking Testbed/mediapipe_python_runtime_bridge/sessions/session-1780803313.80639-1047647/preview_frame.jpg`.
- Flow runtime snapshot: `last_error: null`, populated `preview_descriptor`, and a real `preview_frame.jpg` at `/home/derrick/.local/share/godot/app_userdata/AeroBeat Camera Tracking Testbed/mediapipe_python_runtime_bridge/sessions/session-1780803500.26872-984515/preview_frame.jpg`.
- Conclusion: **preview corruption remains fixed** and the temp-extension regression remains fixed during the fresh 180-second rerun.

Before/after metrics versus the pre-cadence-fix post-polling QA baseline in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.temp-post-polling-fix-qa/20260606-225629/`:
- Boxing at 60s:
  - Godot: `223156 KB / 96.5% CPU` before → `221284 KB / 96.5% CPU` after
  - Vendor child: `557864 KB / 213% CPU` before → `548540 KB / 198% CPU` after
- Boxing at 180s:
  - Godot: `300340 KB / 98.4% CPU` before → `372180 KB / 98.8% CPU` after
  - Vendor child: `558680 KB / 212% CPU` before → `550968 KB / 195% CPU` after
- Flow at 60s:
  - Godot: `446632 KB / 96.5% CPU` before → `485960 KB / 82.1% CPU` after
  - Vendor child: `469996 KB / 282% CPU` before → `470204 KB / 134% CPU` after
- Flow at 180s:
  - Godot: `748856 KB / 98.0% CPU` before → `1167620 KB / 84.5% CPU` after
  - Vendor child: `471576 KB / 281% CPU` before → `478456 KB / 140% CPU` after

Truthful QA conclusion from the rerun:
- The vendor cadence change **materially improved vendor-child CPU**, especially on flow (`282%` → `134%` at 60s; `281%` → `140%` at 180s) and modestly on boxing (`213%` → `198%` at 60s; `212%` → `195%` at 180s).
- However, the consumer-level bug is **still not QA-clear** because the Godot parent still shows sustained long-run churn and continued RSS growth in both scenes, with the flow repro now ending materially higher in RSS despite lower CPU.
- Audit should **not** proceed yet on a “bug resolved” claim. Another fix slice is required, focused on the remaining Godot/tool/consumer churn seam rather than the already-fixed preview corruption path.

### Task 3D: Diagnose remaining Godot parent RSS churn after vendor cadence fix

**Bead ID:** `aerobeat-tool-camera-tracking-wsd`
**SubAgent:** `primary`
**Role:** `coder`
**References:** `REF-02`, `REF-05`, `REF-06`
**Prompt:** The preview corruption bug is fixed and the vendor baseline cadence fix materially reduced vendor-child CPU, but QA still shows sustained long-run Godot parent churn/RSS growth on both `boxing_proving` and `flow_proving`, especially flow. Diagnose the dominant remaining owner seam truthfully. Determine whether the remaining growth is primarily in shared tool-side Godot structures, consumer-scene behavior, testbed/headless harness behavior, or another cross-repo seam. Keep this diagnosis-first and narrowly focused on the parent-process churn that remains after the vendor fixes.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.temp-parent-churn-diagnosis/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.beads/`

**Files Created/Deleted/Modified:**
- this plan
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.temp-parent-churn-diagnosis/monitor_fixture_timeline.gd`
- nondurable monitor logs / `ps.csv` artifacts under `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.temp-parent-churn-diagnosis/`

**Status:** ✅ Complete

**Results:** 2026-06-06 23:50 EDT — Diagnosis completed without durable code changes. The dominant remaining owner seam is **not** the shared tool repo and **not** vendor-child baseline anymore; it is the **consumer testbed / headless harness in `aerobeat-input-camera-tracking`**, specifically the shared base proving harness keeping an **unbounded per-pose fixture state timeline** in memory during long-running validation scenes.

Exact evidence gathered:
- Code inspection in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.testbed/scripts/proving_harness.gd` shows `_on_pose_updated()` calls `_record_fixture_state_snapshot("pose_updated")` on every pose update. `_record_fixture_state_snapshot()` appends to `_fixture_state_timeline` with no cap or prune path, and each entry duplicates nested dictionaries for `gesture_states`, `ready`, `flow`, and `boxing_debug`.
- The same harness file initializes `_fixture_state_timeline` as a long-lived array and only clears it on explicit harness reset. That means a normal 3-minute headless validation run continuously accumulates retained debug snapshots in the Godot parent.
- I proved the retention live with a nondurable monitor script at `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.temp-parent-churn-diagnosis/monitor_fixture_timeline.gd`, run against the actual consumer scenes:
  - Boxing command: `godot --headless --path .testbed --script /home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.temp-parent-churn-diagnosis/monitor_fixture_timeline.gd -- res://scenes/boxing_proving.tscn`
  - Flow command: `godot --headless --path .testbed --script /home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.temp-parent-churn-diagnosis/monitor_fixture_timeline.gd -- res://scenes/flow_proving.tscn`
- Live boxing evidence from `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.temp-parent-churn-diagnosis/boxing-20260606-234800/`:
  - `_fixture_state_timeline` grew `407 → 850 → 1271 → 1698` entries at `15s → 30s → 45s → 60s`.
  - Serialized fixture report size grew `2,481,514 → 5,262,569 → 7,906,277 → 10,585,919` bytes over the same window.
  - Parent RSS grew in lockstep in `ps.csv`: `152752 KB → 174440 KB → 207876 KB → 252724 KB` while CPU stayed high (`81.6% → 95.4%`).
- Live flow evidence from `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.temp-parent-churn-diagnosis/flow-20260606-234800/`:
  - `_fixture_state_timeline` grew much faster: `1492 → 3213 → 4844 → 6443` entries at `15s → 30s → 45s → 60s`.
  - Serialized fixture report size ballooned `9,920,007 → 21,645,443 → 32,762,544 → 43,651,255` bytes by 60s.
  - Parent RSS followed the same shape in `ps.csv`: `184920 KB → 250016 KB → 312960 KB → 372616 KB` with CPU `82.6% → 95.7%`.
- This explains why flow still ends materially higher than boxing after the vendor cadence fix: the owner seam is **shared harness retention**, but the retained per-entry payload is heavier in the flow scene, so the same unbounded timeline amplifies flow RSS faster.
- Owner recommendation: the next fix belongs in `aerobeat-input-camera-tracking`’s shared `.testbed/scripts/proving_harness.gd`, not in `aerobeat-tool-camera-tracking` or `aerobeat-vendor-mediapipe-python`. The harness should cap/prune/disable continuous fixture timeline capture during long-running headless validation, and any full-fidelity capture mode should be explicit/on-demand rather than always-on.
- Materialized follow-up bead: `aerobeat-input-camera-tracking-b00` — `Bound proving-harness fixture timelines to stop headless Godot RSS churn`.
- Fix-slice readiness: **yes**. The seam is concrete and owner-correct enough for an immediate implementation slice in the consumer repo.

2026-06-06 23:59 EDT — Landed the consumer-owner implementation slice for bead `aerobeat-input-camera-tracking-b00` in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking`.
- Changed `.testbed/scripts/proving_harness.gd` so fixture timeline capture is **bounded by default** instead of unbounded on every pose update. New default behavior keeps all non-pose snapshots, retains only the most recent `240` `pose_updated` snapshots, and reports capture metadata (`mode`, pose snapshot limit, seen/retained/dropped counts) in `get_fixture_capture_report()`.
- Added explicit runtime escape hatches for debugging instead of silent removal of observability: `AEROBEAT_FIXTURE_STATE_TIMELINE_MODE=full` keeps full-fidelity continuous capture, `events_only` disables continuous pose snapshots while preserving event snapshots, and `AEROBEAT_FIXTURE_POSE_STATE_TIMELINE_LIMIT=<n>` overrides the bounded pose snapshot cap.
- Added focused regression coverage in `.testbed/tests/unit/test_proving_harness_fixture_timeline.gd` proving both the bounded default behavior and the explicit full-capture mode.
- Validation run in the consumer repo: `godot --headless --path .testbed --script addons/aerobeat-vendor-godot-unit-test/gut_cmdln.gd -gtest=res://tests/unit/test_proving_harness_fixture_timeline.gd -gexit` → `2/2 passed`.
- QA should rerun immediately on the same boxing + flow long-run headless repro surfaces, because this slice directly changes the diagnosed dominant Godot-parent RSS owner seam.

2026-06-07 00:13 EDT — Completed the required **post-consumer-fixture-retention-fix QA rerun** on the same headless consumer repro surfaces, and this time the long-run churn bug is **QA-clear**.

Refresh / code-truth check before rerun:
- Consumer repo: `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking` @ `ea3b034`
- Tool repo at rerun: `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking` @ `aa10141`
- Vendor repo at rerun: `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python` @ `0c8dfe6`
- `.testbed/addons.jsonc` still installs both addons from sibling repos with `source: "symlink"`.
- Direct `os.path.samefile(...)` checks confirmed the consumer-installed addon files are the same live files as the sibling repo sources for `src/CameraTracking.gd` and `runtime/mediapipe_runtime_probe.py`.
- Because the consumer testbed was already on the live sibling repos, **no dependency refresh was needed and `godotenv-sync` was not run**.

Exact rerun commands / artifacts:
- Artifact root: `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.temp-post-consumer-fixture-fix-qa/20260607-000111/`
- Boxing command: `godot --headless --path .testbed res://scenes/boxing_proving.tscn`
- Flow command: `godot --headless --path .testbed res://scenes/flow_proving.tscn`
- Sampling method: 180-second runs with process samples every 15 seconds for both the Godot parent and spawned `mediapipe_runtime_probe.py` child, captured in each scene folder’s `ps-samples.csv`; logs captured as `godot.log`.
- Fixture-capture truth gate: separate 60-second headless scene captures using nondurable helper script `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.temp-post-consumer-fixture-fix-qa-capture.gd`, producing `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.temp-post-consumer-fixture-fix-qa/20260607-000111/boxing-fixture-report.json` and `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.temp-post-consumer-fixture-fix-qa/20260607-000111/flow-fixture-report.json`.

Preview correctness / corruption truth gate:
- Fresh `rg` across the new boxing + flow logs found **no** `Error loading image`, `ERR_FILE_CORRUPT`, `Condition "src_image_len == 0"`, `runtime_probe_exception`, `could not find a writer for the specified extension`, or `imwrite_` lines.
- Both logs still reached their normal harness-live lines (`[ProvingHarness][Boxing] Boxing harness live` and `[ProvingHarness][Flow] Flow harness live`).
- The newest corresponding runtime session snapshots under `/home/derrick/.local/share/godot/app_userdata/AeroBeat Camera Tracking Testbed/mediapipe_python_runtime_bridge/sessions/` both show `last_error: null`, populated `preview_descriptor` objects, and real `preview_frame.jpg` files on disk.
- Conclusion: **preview corruption remains fixed** and the temp-extension regression remains fixed during the fresh rerun.

Before/after metrics versus the pre-consumer-fix QA baseline in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.temp-vendor-cadence-rerun-qa/20260606-233512/`:
- Boxing at 60s:
  - Godot: `221284 KB / 96.5% CPU` before → `150280 KB / 96.5% CPU` after
  - Vendor child: `548540 KB / 198% CPU` before → `469376 KB / 142% CPU` after
- Boxing at 180s:
  - Godot: `372180 KB / 98.8% CPU` before → `150280 KB / 98.7% CPU` after
  - Vendor child: `550968 KB / 195% CPU` before → `477276 KB / 136% CPU` after
- Flow at 60s:
  - Godot: `485960 KB / 82.1% CPU` before → `142440 KB / 82.9% CPU` after
  - Vendor child: `470204 KB / 134% CPU` before → `471956 KB / 131% CPU` after
- Flow at 180s:
  - Godot: `1167620 KB / 84.5% CPU` before → `144396 KB / 85.0% CPU` after
  - Vendor child: `478456 KB / 140% CPU` before → `473988 KB / 128% CPU` after

Fixture retention / capture-report truth gate:
- Boxing `boxing-fixture-report.json` reports `state_timeline_capture.mode="bounded"`, `pose_snapshot_limit=240`, `pose_snapshots_seen=3660`, `pose_snapshots_retained=240`, `pose_snapshots_dropped=3420`, and `state_timeline_len=243` at the 60-second capture point.
- Flow `flow-fixture-report.json` reports `state_timeline_capture.mode="bounded"`, `pose_snapshot_limit=240`, `pose_snapshots_seen=9035`, `pose_snapshots_retained=240`, `pose_snapshots_dropped=8795`, and `state_timeline_len=243` at the 60-second capture point.
- These counters prove the new bounded-retention policy is actually engaged during live runs, not just configured in code.

Truthful QA conclusion from the rerun:
- **Yes — the bug is QA-clear now.** The preview corruption bug stayed fixed, the vendor child remains materially improved from the earlier owner-side cadence work, and the previously dominant Godot parent RSS churn is gone on both required 180-second consumer repro surfaces after the consumer harness retention fix.
- The Godot parent still burns a high steady-state CPU core in these headless proving scenes, so there is room for future optimization work, but the measured long-run **growth/churn** problem that blocked QA is no longer present in this slice.
- Audit can proceed immediately on the resolved preview/resource-churn workstream.

---

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

**Status:** ✅ Complete

**Results:** 2026-06-07 00:20 EDT — Independent audit passed. I verified the root-cause chain and final owner seams against the actual landed code, commit history, regression tests, and saved QA artifacts across all three touched repos rather than relying on summaries.

Audit evidence checked:
- **Vendor preview corruption fix owner seam:** `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/runtime/mediapipe_runtime_probe.py` at commits `e6b69ee` and `b380fe0` now publishes `preview_frame.jpg` through `_write_image_atomic(...)` and preserves the `.jpg` suffix on the temp path before `os.replace(...)`, which matches the diagnosed partial-file race and also fixes the temporary extension regression. The targeted regression coverage in `runtime/tests/test_mediapipe_runtime_probe.py` passed again during this audit via `python3 -m unittest runtime.tests.test_mediapipe_runtime_probe` (`38 tests`, `OK`).
- **Tool polling-churn fix owner seam:** `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTracking.gd` at commit `b290f00` now rate-limits continuous `_process()` polling through `_refresh_from_backend_if_running(true, false)` with a 33 ms cadence gate while preserving forced refreshes on explicit public getter / replay-control paths. Regression coverage in `.testbed/tests/test_CameraTracking.gd` includes `test_camera_tracking_rate_limits_continuous_process_polling_but_forces_explicit_refreshes`; the full targeted suite passed again during this audit (`40/40 passed`).
- **Consumer parent-RSS churn fix owner seam:** `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.testbed/scripts/proving_harness.gd` at commit `ea3b034` now bounds long-lived pose snapshot retention by default, exposes explicit debug escape hatches (`AEROBEAT_FIXTURE_STATE_TIMELINE_MODE`, `AEROBEAT_FIXTURE_POSE_STATE_TIMELINE_LIMIT`), and reports retained/dropped counters through `get_fixture_capture_report()`. The focused regression suite in `.testbed/tests/unit/test_proving_harness_fixture_timeline.gd` passed again during this audit (`2/2 passed`).
- **Saved QA artifact truth check:** I independently checked the fresh post-fix artifact roots in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.temp-post-consumer-fixture-fix-qa/20260607-000111/` and the immediately prior pre-consumer-fix baseline in `.temp-vendor-cadence-rerun-qa/20260606-233512/`. The new logs contain no `Error loading image`, `ERR_FILE_CORRUPT`, `src_image_len == 0`, `runtime_probe_exception`, `could not find a writer for the specified extension`, or `imwrite_` signatures. The saved 180-second process samples confirm the claimed stabilization: Boxing Godot `372180 KB / 98.8%` before → `150280 KB / 98.7%` after; Flow Godot `1167620 KB / 84.5%` before → `144396 KB / 85.0%` after.
- **Bounded-retention live truth gate:** I read the saved fixture-capture reports `boxing-fixture-report.json` and `flow-fixture-report.json` under the same QA artifact root and confirmed the fix was active during live runs, not just present in code: both report `mode="bounded"`, `pose_snapshot_limit=240`, and only `243` retained timeline entries after 60 seconds despite thousands of seen pose snapshots (`3660 seen / 240 retained / 3420 dropped` for boxing; `9035 seen / 240 retained / 8795 dropped` for flow).
- **Runtime snapshot truth gate:** The latest corresponding runtime session snapshots under `/home/derrick/.local/share/godot/app_userdata/AeroBeat Camera Tracking Testbed/mediapipe_python_runtime_bridge/sessions/` show `last_error = null`, populated `preview_descriptor` objects, and real `preview_frame.jpg` files on disk, which matches the QA claim that preview publication and preview correctness both remained healthy in the final rerun.

Audit verdict:
- **Preview corruption bug fixed:** yes.
- **Temp-extension regression fixed:** yes.
- **Vendor baseline reduced enough for this addressed bug slice:** yes — the vendor cadence change materially reduced the vendor floor and removed it as the dominant blocker for this plan, even though future optimization remains possible.
- **Parent RSS churn bug fixed by bounded fixture retention:** yes.
- **Unresolved blocker remaining for this specific plan:** none.

Landability decision: this plan is now truthfully landable and can be archived once the coordinating orchestrator performs its normal wrap-up/commit flow.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** Root-caused and resolved a cross-repo preview-frame corruption / churn workstream. The final landed state combines: (1) atomic vendor preview publication with preserved `.jpg` temp extension, (2) tool-side cadence-gating of continuous backend polling, (3) vendor default cadence reduction to lower the continuous runtime floor, and (4) consumer-side bounded fixture retention to eliminate the dominant remaining Godot parent RSS churn.

**Reference Check:** `REF-01` / `REF-02` matched the original failure shape and repro surface; `REF-03` / `REF-04` correctly identified the tool seam involved in the polling path; `REF-05` was the truthful consumer repro surface used for QA; `REF-06` was the correct lower-layer owner seam for the atomic preview publication fix and cadence-baseline work.

**Commits:**
- `e6b69ee` - Publish preview frames atomically
- `b380fe0` - Preserve JPEG extension during atomic preview writes
- `0c8dfe6` - Reduce default MediaPipe runtime cadence
- `b290f00` - Rate-limit continuous camera tracking backend polling
- `ea3b034` - Bound proving harness fixture timeline capture

**Lessons Learned:** The initial screenshot really was pointing at a true preview-file race, but that was only one layer of the overall churn story. Separating owner seams across vendor/tool/consumer was necessary: fixing preview correctness alone did not remove the long-run RSS growth, and the final blocker lived in the consumer proving harness’s unbounded debug retention rather than the preview code itself.

---

*Completed on 2026-06-07*