# Chip Saved-Session Replay Dependency Repair

**Date:** 2026-06-13
**Status:** Complete
**Last Updated:** 2026-06-13 12:50 EDT
**Blocked Reason:** None
**Agent:** `pico`

---

## Goal

Investigate the Godot parse failure on chip when opening the AeroBeat testbed project and repair the missing `aerobeat-tool-camera-recording` dependency path or sync contract so the saved-session replay backend loads cleanly.

---

## Overview

Chip currently fails while parsing `SavedSessionReplayBackend.gd` because it preloads `res://addons/aerobeat-tool-camera-recording/src/manifest/SessionManifestV1.gd`, and that file is not present in the synced project layout on chip. This could be a repo-code issue, a sync/wiring issue, or a missing addon dependency in the consumer project.

The repair needs to be evidence-driven. First confirm the exact repo/project layout on chip and compare it with the expected local workspace state. Then implement the narrowest correct fix in the owning repo(s), validate locally and on chip, and capture the result in this plan before handing back to Derrick.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Saved-session replay backend that raises the parse error | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/SavedSessionReplayBackend.gd` |
| `REF-02` | Recording addon manifest class expected by the preload | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-recording/src/manifest/SessionManifestV1.gd` |
| `REF-03` | Active AeroBeat umbrella plan for broader camera-tracking work | `/home/derrick/.openclaw/workspace/projects/aerobeat/.plans/2026-06-10-boxing-pose-classifier-and-recording-plan.md` |

---

## Tasks

### Task 1: Diagnose chip layout and ownership of the failure

**Bead ID:** `aerobeat-tool-camera-tracking-4x0`
**SubAgent:** `primary` (for `research`)
**Role:** `research`
**References:** `REF-01`, `REF-02`, `REF-03`
**Prompt:** Inspect the chip-side AeroBeat testbed layout and the local repo state to determine why `SavedSessionReplayBackend.gd` cannot preload `aerobeat-tool-camera-recording/src/manifest/SessionManifestV1.gd`. Claim the bead on start, gather concrete evidence about whether the problem is missing synced addon content, broken path expectations, or consumer dependency wiring, and leave a concise repair recommendation with exact affected repo paths.

**Folders Created/Deleted/Modified:**
- None.

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.testbed/addons.jsonc` (identified as missing consumer mount)
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/SavedSessionReplayBackend.gd` (confirmed hard preload dependency)
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/SessionManifestReplayBackend.gd` (confirmed hard preload dependency)

**Status:** ✅ Complete

**Results:** The recording addon content is present on chip globally and inside the tracking repo's own testbed, so the failure is not caused by a broken sync. The failing consumer is `aerobeat-input-camera-tracking/.testbed`, which mounts `aerobeat-tool-camera-tracking` but does not mount `aerobeat-tool-camera-recording` in `.testbed/addons.jsonc`. Because the tracking replay backends use unconditional parse-time preloads into `res://addons/aerobeat-tool-camera-recording/...`, Godot fails immediately when the tracking addon loads without that companion addon mounted. Narrow repair path: add the missing recording addon mount in the consumer testbed first; longer-term optionality decision remains whether `aerobeat-tool-camera-tracking` should replace hard preloads with lazy/optional loading if replay support is intended to stay optional for consumers. Validated against `REF-01` and `REF-02`.

---

### Task 2: Implement and validate the narrow repair

**Bead ID:** `aerobeat-tool-camera-tracking-979`
**SubAgent:** `primary` (for `coder`)
**Role:** `coder`
**References:** `REF-01`, `REF-02`
**Prompt:** Implement the minimal correct fix for the missing saved-session replay dependency identified in Task 1. Claim the bead on start. If code or sync metadata changes are needed, make them in the owning repo(s), run the strongest repo-local validation available, and capture exactly what changed and why.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.testbed/addons/` (generated via sync; not patched directly)

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.testbed/addons.jsonc`

**Status:** ✅ Complete

**Results:** Implemented the narrow repair by adding the missing `aerobeat-tool-camera-recording` symlink mount to the consumer workbench manifest at `aerobeat-input-camera-tracking/.testbed/addons.jsonc`; no source changes were needed in `aerobeat-tool-camera-tracking` because the failure was confirmed to be consumer wiring, not an owning-repo sync defect. Validation used the consumer repo’s documented refresh command, `/home/derrick/.openclaw/workspace/scripts/godotenv-sync --repo /home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking`, which regenerated `.testbed/addons/` and created the expected `aerobeat-tool-camera-recording` symlink. After sync, `godot --headless --path .testbed --quit` booted the hidden workbench successfully instead of failing on the previously missing replay dependency path, which is the strongest local proof available short of chip-side QA. A targeted headless load script also confirmed the recording addon files now exist under `res://addons/...`; it emitted an existing `SavedSessionValidator.gd` parse warning during standalone script load, but that did not block project boot after the consumer mount was restored. Stronger conclusion for the plan: the immediate chip parse failure is repaired by consumer wiring alone; optional/lazy dependency refactors remain out of scope for this bead. Validated against `REF-01` and `REF-02`.

---

### Task 3: Verify the fix on chip and independently audit the result

**Bead ID:** `aerobeat-tool-camera-tracking-xts`
**SubAgent:** `primary` (for `qa` then `auditor`)
**Role:** `qa` / `auditor`
**References:** `REF-01`, `REF-02`
**Prompt:** First perform QA by validating that the synced project on chip now loads past the prior parse failure and that the saved-session replay dependency resolves correctly. Then perform an independent audit pass against the diagnosis, diff, and validation evidence; close only the audit bead if the repair is genuinely complete.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.testbed/addons/` (local regenerated symlink tree)

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.testbed/addons.jsonc` (verified as fixed locally but still stale on chip)

**Status:** ✅ Complete

**Results:** QA/audit first confirmed chip was still failing because it had the stale consumer `.testbed/addons.jsonc`. The missing manifest entry was then landed properly by committing/pushing the local consumer manifest fix in `aerobeat-input-camera-tracking` as commit `d298cb3`, running `/home/derrick/.openclaw/workspace/scripts/git-sync --repo aerobeat-input-camera-tracking` on chip, then running `/home/derrick/.openclaw/workspace/scripts/godotenv-sync --repo /home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking` on chip. Chip now generates `.testbed/addons/aerobeat-tool-camera-recording` correctly, and `/home/derrick/.local/bin/godot --headless --path .testbed --quit` on chip exits successfully instead of reproducing the missing-path parse failure. Audit conclusion: the original bug is fixed end-to-end. Existing runtime warnings from MediaPipe/TFLite during project boot do not block correctness for this repair.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** We diagnosed the chip parse failure to a missing consumer addon mount, added `aerobeat-tool-camera-recording` to `aerobeat-input-camera-tracking/.testbed/addons.jsonc`, committed and pushed that narrow fix, synced chip, regenerated the consumer addon mounts there, and verified that the chip workbench now boots past the original missing-path replay dependency error.

**Reference Check:** `REF-01` and `REF-02` satisfied for diagnosis, implementation, and chip-side verification. No deviation from the narrow repair path.

**Commits:**
- `d298cb3` - Add camera recording addon to testbed mounts

**Lessons Learned:** For consumers that mount `aerobeat-tool-camera-tracking`, replay backends currently impose a hard parse-time dependency on `aerobeat-tool-camera-recording`; consumer workbench addon manifests must include both until/unless the tracking repo later adopts lazy optional loading.
