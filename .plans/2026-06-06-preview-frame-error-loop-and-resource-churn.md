# AeroBeat Preview Frame Error Loop And Resource Churn

**Date:** 2026-06-06
**Status:** In Progress
**Last Updated:** 2026-06-06 22:28 EDT
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