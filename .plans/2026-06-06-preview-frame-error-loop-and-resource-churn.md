# AeroBeat Preview Frame Error Loop And Resource Churn

**Date:** 2026-06-06  
**Status:** Draft  
**Last Updated:** 2026-06-06 21:58 EDT  
**Blocked Reason:** None  
**Agent:** `pico`

---

## Goal

Investigate and fix the preview-frame load/error loop in the boxing testing scene that appears after leaving the scene running for several minutes and may be causing CPU/resource churn on lower-power hardware.

---

## Overview

Derrick reported that when the boxing test scene is left running for a few minutes on Chip's laptop, errors accumulate in the terminal and the fans kick on. The first-pass diagnosis is **not yet a confirmed memory leak**. The strongest immediate seam is a repeated preview-image load failure loop in the tool-owned preview presenter path.

The likely owner is `aerobeat-tool-camera-tracking` because the error seam points at `src/CameraTrackingPreviewPresenter.gd::_update_preview_texture()`, which repeatedly loads a preview image from disk. The screenshot evidence suggests the preview image can be read while corrupt/partial or otherwise unavailable, causing repeated image-load failures and likely log/CPU churn. The next session should prove whether this is purely a hot error loop, a producer/consumer file-race, actual memory/resource accumulation, or some combination.

The slice should stay narrow and truth-oriented: reproduce, identify whether preview writes are atomic, harden the preview load path against transient corrupt files, reduce repeated identical error spam, and verify whether there is any real memory/resource growth over time.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Derrick's screenshot showing accumulated preview/image-load errors after leaving the boxing test scene running | `/home/derrick/.openclaw/workspace/.temp/nerve-uploads/2026/06/07/image-cd8391a7.png` |
| `REF-02` | Derrick's repro description: leave the boxing test scene running for a few minutes on Chip's laptop, errors accumulate, fans kick on, suspected memory leak | User report in current session on 2026-06-06 21:47 EDT |
| `REF-03` | Tool-owned preview presenter seam that loads preview images from disk | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingPreviewPresenter.gd` |
| `REF-04` | Likely preview presenter update path around `_update_preview_texture()` | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingPreviewPresenter.gd` |

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

**Bead ID:** `Pending`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`  
**Prompt:** Reproduce the boxing-scene preview-frame error accumulation, determine whether the dominant issue is (a) preview image read/write race, (b) repeated identical error loop/log spam, (c) real memory/resource accumulation, or (d) a combination. Capture exact evidence and the smallest trustworthy diagnosis.

**Folders Created/Deleted/Modified:**
- `.plans/`
- any nondurable repro artifact folders if needed

**Files Created/Deleted/Modified:**
- this plan
- optional nondurable repro notes/artifacts if needed

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 2: Harden preview-frame load/write behavior in the owning tool seam

**Bead ID:** `Pending`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01`, `REF-03`, `REF-04`  
**Prompt:** Implement the narrowest owner-correct fix in `aerobeat-tool-camera-tracking` so the preview presenter and preview producer no longer enter a hot failure loop on transient/corrupt preview frames. Prefer atomic write/read behavior, repeated-failure suppression/backoff, and truthful error handling over cosmetic masking.

**Folders Created/Deleted/Modified:**
- `src/`
- `.plans/`
- targeted tests if available

**Files Created/Deleted/Modified:**
- likely `src/CameraTrackingPreviewPresenter.gd`
- any direct preview-producer seam discovered during repro
- this plan

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 3: QA the long-running boxing-scene preview path

**Bead ID:** `Pending`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`  
**Prompt:** QA the long-running boxing-scene preview path after the fix. Verify the error accumulation is gone or materially reduced, confirm fans/CPU churn no longer spike under the same repro, and report whether any actual memory/resource growth remains.

**Folders Created/Deleted/Modified:**
- `.plans/`
- QA artifacts only if needed

**Files Created/Deleted/Modified:**
- this plan
- optional nondurable QA notes/artifacts if needed

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 4: Independently audit final readiness for the preview-frame bug

**Bead ID:** `Pending`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`  
**Prompt:** Independently audit the preview-frame bug fix. Confirm the root cause diagnosis matches the evidence, confirm the fix lives in the correct owner seam, and confirm the long-running boxing-scene repro is clean enough to land.

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