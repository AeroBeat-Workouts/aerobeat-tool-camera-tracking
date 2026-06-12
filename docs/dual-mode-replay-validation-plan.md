# Dual-mode replay validation plan

Slice 5 is the **milestone-closure gate** for the shared saved-session replay substrate.

It does **not** add a new replay architecture. It proves the agreed **C-complete** end state on top of the already-landed slices:

- **B-mode**: deterministic `saved_tracking_frames`
- **A-mode**: `video_reinference` through the packaged source video and the vendor/video tracking lane
- **Same family rule**: both branches must be exercised from the same saved-session package family rooted by one `session_manifest.json`

## Closure goal

A representative saved session must produce machine-checkable evidence that:

1. the package validates structurally as a B-mode session,
2. the same package family validates structurally after switching to A-mode,
3. B-mode still proves deterministic replay controls,
4. A-mode still proves the real vendor/video replay lane,
5. source/truth metadata stays attached in both branches,
6. and the overall package family did **not** fork just to make A-mode work.

## Evidence path

The committed proof flow writes one evidence bundle rooted at a chosen session directory.

Default root:

- `user://qa_session_manifest_dual_mode`

Recommended repo-local QA root:

- `<tracking-repo>/.tmp/dual-mode-validation/session`

Evidence artifacts written there:

- `session_manifest.json`
- `tracking/pose_frames.jsonl`
- `source/source_video.mp4`
- `truth/timing_truth.yaml`
- `dual_mode_validation_report.json`

The JSON report is the canonical Slice 5 machine-readable evidence artifact.

## Commands

### 1) Run the committed dual-mode closure proof

From `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`:

```bash
godot --headless --path .testbed \
  --script res://qa_session_manifest_dual_mode_parity.gd \
  -- --session-root ../.tmp/dual-mode-validation/session \
     --report-path ../.tmp/dual-mode-validation/session/dual_mode_validation_report.json
```

Expected stdout includes:

- `QA_SESSION_MANIFEST_DUAL_MODE_REPORT=...`
- `QA_SESSION_MANIFEST_DUAL_MODE_REPORT_PATH=...`

### 2) Re-run the committed tracker replay tests

From the same tracking repo:

```bash
godot --headless --path .testbed \
  --script addons/aerobeat-vendor-godot-unit-test/gut_cmdln.gd \
  -gtest=res://tests/test_saved_session_replay.gd \
  -gexit
```

This suite now includes the explicit same-family Slice 5 closure test:

- `test_dual_mode_validation_report_proves_c_complete_same_family_round_trip`

### 3) Independently validate the saved-session package with the recording repo validator

From `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-recording`:

```bash
godot --headless --path .testbed \
  --script res://addons/aerobeat-tool-camera-recording/scripts/validate_saved_session.gd \
  -- --session-root /home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.tmp/dual-mode-validation/session
```

This is the structural cross-check that the same package family is still a valid saved-session contract, independent of the tracking replay runner.

## Checklist

The report must pass all of these booleans under `comparison.checklist`:

- `recording_validator_passed_for_b_mode`
- `recording_validator_passed_for_a_mode`
- `same_manifest_entrypoint`
- `same_saved_session_family`
- `b_mode_exact_saved_frames`
- `b_mode_controls_proved`
- `a_mode_vendor_video_path`
- `a_mode_exact_seek_not_claimed`
- `truth_metadata_preserved`
- `parity_landmark_id_match`
- `parity_landmark_count_match`
- `parity_first_landmark_x_within_0_15`

The milestone-closure summary bit is:

- `comparison.c_complete_ready == true`

## What each closure check means

### Structural validation in both modes

- `recording_validator_passed_for_b_mode`
  - proves the package is a valid saved-session contract before replay runs from saved tracking frames
- `recording_validator_passed_for_a_mode`
  - proves the same package family remains structurally valid after switching the manifest replay contract to `video_reinference`

### Same-family replay proof

- `same_manifest_entrypoint`
  - both runs start from the same `session_manifest.json`
- `same_saved_session_family`
  - both runs use the same session root rather than separate B-only and A-only packages

### Deterministic B-mode proof

- `b_mode_exact_saved_frames`
  - the transport advertises `exact_owned_frame_index`
- `b_mode_controls_proved`
  - pause, seek, step forward, step backward, play, and pause-after-play all succeed against saved frames with the expected frame indices

### Real A-mode proof

- `a_mode_vendor_video_path`
  - observed tracking frames come from `mediapipe_python`, and the manifest delegate entrypoint resolves to the packaged `source/source_video.mp4`
- `a_mode_exact_seek_not_claimed`
  - A-mode stays honest about approximate time-based replay instead of pretending it can do saved-frame exact stepping

### Useful parity proof

- `truth_metadata_preserved`
  - timing-truth linkage survives on both branches
- `parity_landmark_id_match`
  - the same landmark identity survives the two branches for the first observed sample
- `parity_landmark_count_match`
  - the first observed sample does not fork into a different landmark-cardinality contract
- `parity_first_landmark_x_within_0_15`
  - A-mode stays directionally close to the B-mode reference on the same package without pretending exact numeric identity

## Audit interpretation

Slice 5 passes only when the saved-session family can be judged complete at the agreed C end state:

- B-mode is still deterministic,
- A-mode is still real,
- both come from the same manifest-backed package family,
- and the machine-readable report says `c_complete_ready = true`.

If any of those checks fail, the milestone is not closed yet.
