# Session-manifest replay parity checklist

Slice 4 adds a real second `source.kind = session_manifest` replay branch.

- **B-mode** = `replay_contract.replay_mode = saved_tracking_frames`
- **A-mode** = `replay_contract.replay_mode = video_reinference`

The package family stays unified: both modes start from the same saved-session root and the same public manifest entrypoint (`session_manifest.json`). The replay mode decides whether tracking replays saved normalized frames directly or re-runs the vendor/video tracking path from the packaged source video.

## What QA should prove

1. **Same entrypoint, different branch**
   - Start from `source.kind = session_manifest` in both cases.
   - Confirm `playback_status.manifest_path` is the same manifest path for both runs.
   - Confirm B-mode reports `replay_mode = saved_tracking_frames`.
   - Confirm A-mode reports `replay_mode = video_reinference`.

2. **B-mode stays deterministic**
   - Confirm backend/frame metadata resolves through saved-frame replay (`backend = saved_session_replay` on observed tracking frames).
   - Confirm exact transport is still advertised:
     - `transport_mode = exact_owned_frame_index`
     - `can_step_forward = true`
     - `can_step_backward = true`
     - `can_seek_frame = true`
   - Confirm pause / step / seek still behave deterministically.

3. **A-mode is the real video/vendor/tracking path**
   - Confirm observed tracking frames come from the vendor replay lane (`backend = mediapipe_python`).
   - Confirm `playback_status.entrypoint` points at the packaged source video path.
   - Confirm A-mode does **not** claim exact saved-frame transport when it only has approximate time-based replay.
   - Confirm the manifest still surfaces saved-session metadata (`truth_linked`, `truth_contract`, `source_contract`, `session_source_kind`).

4. **Useful parity, not fake exactness**
   - Compare B-mode and A-mode on the same session package.
   - Check at least:
     - first tracked landmark ID matches
     - landmark counts are in the same rough range
     - first-frame landmark positions are directionally close enough for a sanity check
     - truth metadata stays attached in both runs
   - Do **not** require bit-identical coordinates or exact frame-addressed seek parity from A-mode.

5. **Unified package shape**
   - Confirm no alternate A-mode-only folder layout was introduced.
   - `session_manifest.json`, `tracking/pose_frames.jsonl`, and optional `source/source_video.*` remain the shared package family.

## Headless proof script

Run this from the tracking repo root:

```bash
godot --headless --path .testbed \
  --script res://qa_session_manifest_dual_mode_parity.gd
```

Expected output includes:

- `QA_SESSION_MANIFEST_DUAL_MODE_REPORT=...`

The report captures:

- B-mode observed frame + transport facts
- A-mode observed frame + transport facts
- same-manifest-path evidence
- whether A-mode resolved to the packaged source video entrypoint
- a small parity checklist with pass/fail booleans

## Interpreting failures

- If B-mode loses exact transport, Slice 4 regressed Slice 3 and is a fail.
- If A-mode starts without `backend = mediapipe_python`, the manifest branch is bypassing the intended vendor/video path and is a fail.
- If A-mode needs a different entry flow than `source.kind = session_manifest`, the replay architecture is forked and is a fail.
- If A-mode claims exact frame stepping without proving it, the transport metadata is dishonest and is a fail.
