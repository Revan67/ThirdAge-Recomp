# Project status

Reviewed October 9, 2026. This records the **menu/audio source checkpoint** and
its matching runtime submodule revision. Generated game code and user-supplied
assets remain local; fresh-clone generation is not yet turnkey.

## Verified milestone

The native recomp progresses through loading ring, legal splash, EA, THX and
New Line videos to a textured main menu. The startup queue completes around
38 seconds on the development host. A subsequent listening run stays at the
menu for 30 seconds before stopping. The user reports clean THX, New Line and
main-menu music; EA has possible slight static that remains unclassified.

Rendering evidence includes completed-display-copy captures, not just reads
of in-progress guest surfaces. Double reads agreed in the inspected runs, but
the observer held no render lock and final-pixel parity with xemu is unverified.
No proprietary captures, logs or game code are included in the public docs.

## Verification

- Release game executable builds successfully.
- APU monitor/IRQ/backing/lifecycle suite: **5,455 checks pass in Debug and
  Release**; Release also passes with the old-wait fallback selected.
- Earlier renderer verification: vertex program 1,246 checks in Debug and
  Release; combiner 1,106 and framebuffer ownership 308 checks in Release.
  These are recorded runs, not a claim that every suite was rerun together.
- Same-build audio comparison at 400 submissions: old host wait has 130
  empty-queue observations versus five with the high-resolution wait, with
  zero full-queue rejections in both. The full corrected run stops accruing
  empty observations after startup and completes the menu transition.
- Extended listening run: startup completes at 38.375 seconds / UI 4040 ms;
  the process is stopped at 68.390 seconds. Last queue sample at 3,150
  submissions has four empty observations and zero full rejections.

The local-checks badge in the README reports this dated verification. There
is currently no GitHub Actions workflow or published release. Host timing is
not a cross-machine benchmark, and user listening is not bit-exact audio proof.

## Known limitations

- Gameplay, controller navigation and New Game transitions are not yet verified.
- General 3D coverage, perspective/depth/stencil behavior and full shader
  fidelity remain investigation areas; reaching the menu is not a playability claim.
- GP/EP DSP execution remains stubbed. The pre-existing title DSP doorbell
  workaround is not proof of real command execution or effects support.
- Explicit contiguous-memory backing is repaired for voice-table records.
  SGE/SSL/notifier/payload domains still need their own provenance audits.
- Full voice resampling and audio/video synchronization are unverified.
- EA-only audio roughness needs comparison with the original before changing
  the now-working general audio path.
- xemu fast-FPU mode changes an audio-resource identifier in this startup path.
  Use the documented software-FPU reference and compare equivalent milestones;
  do not copy that rounding bug or slow native playback to match a slow run.
- Generated game code and private analysis are intentionally absent from Git;
  fresh-clone generation/build reproducibility is still incomplete.

## Next milestone

Test **New Game → opening scene → first controllable gameplay** in a bounded
run. Check input, loading transitions, 3D scene/camera, dialogue and effects.
Investigate the first incorrect transition; do not force guest states or gates.

## Publication checklist

For this checkpoint and future publications:

1. Review root and runtime changes separately; preserve existing unrelated work.
2. Exclude game dumps/assets, generated game code, Ghidra databases, logs,
   captures, saves, credentials and machine-specific configuration.
3. Review and publish the runtime changes to the public fork, then pin that
   reachable runtime commit in the parent repository. Do not publish a pointer
   to an unpublished commit or assume dirty submodule content travels with it.
4. Review the public docs and README, then commit/push only with approval.
5. Resolve the root-license choice separately; do not infer it from the runtime.
6. Add CI/release/license badges only when those underlying facilities exist.

## Evidence navigation

- [Front-end trace](FRONTEND_STATE_TRACE.md): latest findings first; older
  black-screen, missing-IRQ and timing diagnoses are historical.
- [Startup comparison](STARTUP_COMPARISON.md): emulator/native milestones and
  reference caveats; older sections describe older builds.
- [Working-audio checkpoint](WORKING_AUDIO_CHECKPOINT.md): first audible-audio
  milestone, before the later pacing correction. Preserve as a historical record.
- [Intake](INTAKE.md): original input and early bring-up findings, not current status.
