# Matched startup trace — 2026-10-08

Latest listening confirmation (2026-10-09): the user reports clean THX, New
Line and main-menu music after the pacing correction. Slight EA roughness
remains unclassified; full audio/video synchronization is still unverified.

Latest audio pacing follow-up (2026-10-09): a same-build coarse/high-resolution
wait comparison reduces empty output-queue observations at submission 400
from 130 to 5, restoring near-nominal sample delivery without changing guest
clocks or buffer size. The full high-resolution run completes startup at
38.297 s / UI 4040 ms; empty observations stop increasing after startup and
there are no full-queue rejections. Debug/Release APU checks pass 5455, including
thread lifecycle. Subjective smoothness and synchronization still need user
verification. See [latest trace evidence](FRONTEND_STATE_TRACE.md). The original
[first-working-audio checkpoint](WORKING_AUDIO_CHECKPOINT.md) is preserved.

Working-audio checkpoint (2026-10-09, latest): the user confirms audio is
audible but choppy. APU IRQ delivery, shared ISR/synchronization locking and
explicit contiguous voice-table backing restore audio processing beyond the
previous trap. The full bounded run completes startup at 38.329 s / UI 4020 ms.
Debug and Release APU checks pass 5452. Queue starvation is the next audio
investigation, not a proven complete diagnosis. See the
[checkpoint record](WORKING_AUDIO_CHECKPOINT.md); earlier missing-IRQ and
unproven voice-table-backing statements below describe the pre-fix build.

Current follow-up (2026-10-09): completed native display captures demonstrate
legal, EA, THX, New Line and textured menu. A subsequent software-FPU xemu run
reaches queue completion, with a near-real-time movie interval; earlier slow
reference runs are not a stable wall-time baseline. Paired final pixels remain
unverified because emulator screenshot capture is unavailable in this setup.

Audio output is now repaired and tested (5435 checks in Debug and Release):
nonzero guest samples reach XAudio2 instead of being cleared, and the mixer
advances at the produced sample rate. A bounded run still completes startup at
38.859 s. Remaining movie silence now has a specific upstream boundary: VP
processing stops in trapped mode, `set_irq` stays pending, and the standalone
runtime never delivers the APU interrupt to the registered vector-5 DSOUND ISR.
Proper interrupt delivery is the next implementation target, not gate forcing.
Mercenaries' split-memory/DSP findings also warrant audit but are not yet a
proven ThirdAge cause. See [current evidence](FRONTEND_STATE_TRACE.md); older
unresolved-status paragraphs below refer to earlier builds.

Reference correction (2026-10-09): the recent extra xemu movie-preparation wait
is traced to its fast-FPU mode rounding the audio-resource integer during FILD.
With only `perf.hard_fpu = false` changed, the integer stays intact, the original
audio-ready callback executes, and playback begins at UI 3540 ms, matching the
native milestone. Do not add a native delay or emulate this rounding. Host audio,
full-frame playback and exact hardware timing remain unverified. See the newest
[evidence and controlled comparison](FRONTEND_STATE_TRACE.md).

Clock diagnosis correction (2026-10-09): original control flow deliberately
skips normal UI updates in active movie states 4/5. New mid-playback samples
show the UI clock frozen in **both** xemu and native; xemu's extra UI time
accumulates during preparation. Endpoint differences below are real, but do
not establish a missing timer-service bug during playback. Native counters are
consistent with the nominal 1022-frame, 30000/1001-fps stream. Fresh xemu runs
are below real time and report no default audio device, so their wall times
cannot establish parity. See the latest [trace notes](FRONTEND_STATE_TRACE.md).

Latest follow-up (2026-10-09): EXP, ARL and bounded relative constant reads now
cover the later program starting at slot 12. A bounded light run emits no
vertex/combiner rejection diagnostics, completes the queue at 38.609 s and has
inspected textured-menu captures. Evaluating flat, texture-free combiners once
per triangle restores the legal interval to about 2.8 s (from about 6.6 s),
without changing guest gates. Movie/UI-clock divergence remains unresolved;
this is not emulator timing parity or complete scene-rendering verification.
See the latest [trace notes](FRONTEND_STATE_TRACE.md). Older rejection counts
and timing observations below describe earlier builds.

Movie follow-up (2026-10-09): AY8 sampling, independent texture stages/UVs and
bounded register-combiner execution are implemented. Native captures now show
EA/THX imagery in the initial test and THX/New Line imagery plus the textured
menu in the optimized repeat. The repeat's first observed menu sample is
43.140 s, not timing parity; sparse external surface samples are not complete
window playback verification. User reports presentation flicker ceased in
the preceding presentation-only pass. Four later vertex-program-12 rejection
messages remain. See the newest [trace notes](FRONTEND_STATE_TRACE.md); older
statements below about absent movie rendering describe earlier builds.

Latest presentation follow-up: per-draw publication has been replaced with
completed-frame capture at the existing flip boundary, and converted-buffer
access is synchronized. Both Debug/Release ownership regressions pass and a
bounded native repeat still reaches the textured menu. User-visible flicker
resolution is not yet verified. Movie planes contain recognizable decoded
imagery, but AY8/multi-texture/combiner rendering remains unimplemented. See
the latest sections of [FRONTEND_STATE_TRACE.md](FRONTEND_STATE_TRACE.md).

2026-10-09 rendering follow-up: the bounded vertex-program interpreter now
executes the captured UI subset. A separate 40-second native verification
shows the legal logo and textured main menu instead of the prior broad gray
regions. These are externally sampled guest surfaces, not a paired xemu final
pixel comparison or proof of flicker-free presentation/movie playback. The
renderer coverage audit and detailed verification are recorded at the top of
[FRONTEND_STATE_TRACE.md](FRONTEND_STATE_TRACE.md). The historical statements
below about absent vertex-program execution describe the pre-fix capture.

Follow-up: the confirmed control-flow gaps are now repaired and the observed
startup queue completes. Legal-screen frame cadence is approximately 60 Hz;
movie/UI-clock divergence and rendering remain open. GPU semaphore completion
now replaces Third Age's five-bit mirror, and GET follows actual push-stream
consumption, including backwards jumps. Startup still completes around 38 s;
the user still observes flicker and incorrect gray/white/checkerboard regions.
See the latest section
of [FRONTEND_STATE_TRACE.md](FRONTEND_STATE_TRACE.md). The results below
describe the pre-fix paired capture, retained as the comparison baseline.

## Outcome

A sequential xemu/original and native/recomp trace now compares startup
milestones, resource/script activity, and sampled GPU submissions. It provides
stronger evidence for a renderer execution problem on the legal screen, while
independently confirming movie-clock divergence and unresolved post-movie
callbacks. **This is a bounded semantic comparison, not an exhaustive trace of
every task, instruction, resource byte, or draw through a verified menu frame.**

No production fix or resource/state override was introduced for this test.
Temporary generated-code probes were removed afterward and Release rebuilt
successfully. The existing C4717 recursion warning for `sub_0017F840` remains.
No game was relaunched after cleanup. Both owned diagnostic processes stopped.
Existing uncommitted work was preserved; nothing committed or pushed.

## Proven matches

| Compared evidence | Result |
| --- | --- |
| First 32 sampled resource-dispatch type values | Same ordered sequence |
| UI parser input prefixes | Same set of 11 unique 160-byte prefixes |
| Initial script request | `title_screen` / `_level0` in both |
| Opening script command | `titl_open=1` at UI clock 40 in both |
| Initial completion command | `titl_ac=1` at UI clock 60 in both |
| Legal callback / logo request | UI clocks 100 / 120 in both; same `/instance2/logo/i` request |
| Legal completion / movie request | `titl_ac=1` at 3440; movie callback at 3460 in both |
| Post-movie script request | `/iTitleScreen/i` in both |

The xemu capture recorded 13 UI parser entry observations versus 11 native,
but only 11 unique input prefixes in each. Repeated debugger observations and
scheduling differences prevent interpreting this as two extra resource loads.
Matching prefixes do not establish full-payload equality or a complete
header-to-activation proof for every package.

For the first eight GPU submissions per phase, compared after removing memory
addresses from the selected state comparison:

| Phase | Shader instruction upload groups | Texture format sets / transform modes | Selected draw layouts | Constant load/write sequence |
| --- | --- | --- | --- | --- |
| Early startup | Match | Match | No captured draws | Match, 22 writes |
| Legal | Match | Match | Match | Match, 179 writes |
| Movie entry | Match | Match | Match | Match, 108 writes |
| Post-movie entry | Match | Match | Differ later in sample | Differ, 367 vs 384 writes |

Legal and movie-entry samples include DXT1 (`0x0C`), DXT23 (`0x0E`), and
linear A8 (`0x1F`) texture formats. Post-movie samples include DXT45 (`0x0F`).
The same 8-instruction and 10-instruction vertex-program upload groups occur
in both runs. Shader instructions were compared separately from constants:
method range `0x0B00..0x0B7C` is program upload, while `0x0B80..0x0BFC` is
constant upload. Combining these ranges produces misleading program hashes.

Selected legal draws switch between transform modes 4 and 6. Programmable
draws include a float3 attribute 0 and packed-color attribute 1, without a
separate float2 texture-coordinate attribute in that captured layout. The
current bring-up renderer does not execute the uploaded vertex programs and
uses position/texture-coordinate heuristics. This is a specific renderer
coverage gap worth investigating, not proof that the observed gray pixels
have only one cause.

## Proven differences

- The movie-request UI clock is 3460 in both, but the post-movie callback sees
  7580 in xemu versus 3520 in the recomp. The earlier minimally instrumented
  timing test also showed this divergence; this heavily observed test is not
  a replacement wall-clock benchmark.
- xemu executes `0x001FAEB7` at queue index 13. The native run logs it as an
  unresolved indirect call.
- xemu reaches `0x00016E60` at queue index 14. The native run repeatedly logs
  that callback as unresolved and remains at index 14 during its four-second
  observation window.
- Post-movie selected draw ordering/constants differ within the first eight
  submissions. The first differing constant-sequence entry is a constant-load
  index, not a demonstrated corrupt shader constant. Different UI progress
  and submission boundaries must be ruled out before calling this a bug.

The xemu capture ends on entry to the final callback; it does not prove that
callback returned or that a correctly rendered menu frame appeared. Native
`titl_so=1` and `titl_si=1` observations occur after that endpoint and must not
be described as commands missing from xemu.

## Coverage and limitations

- The corrected xemu capture arms at XBE entry `0x00035326`; the earlier
  pilot started too late for initial resource loading and is not the loader
  baseline. Xbox BIOS execution is not traced.
- Sites cover stream parser `1F4A20`, header acceptance `189300`, assembly
  enqueue `E4500`, consumer `1FC2F0`, dispatch `E6F40`, UI parser `B2600`,
  script request `216860`, script command `B7B80`, stream callback `DB620`,
  selected title callbacks, and GPU submission points `22C1CC` / `22C27B`.
  The probes are entry observations, not full return/completion tracing.
- xemu limits each site to 32 observations per phase and GPU sites to eight;
  native limits are 128 and 32 respectively. The GPU comparison uses eight
  from each run. Hitting a cap is not evidence that later work did not occur.
- xemu: 392 records, 32 submission observations, 31 nonempty payloads,
  42,540 captured pushbuffer bytes. Native: 1,751 records, 128 nonempty
  submissions, 184,228 pushbuffer bytes. One xemu empty submission has no
  captured payload. Pushbuffer wraps and segments over 256 KiB are not copied.
- No texture pixels, external vertex buffers, decoded movie frames, audio
  output, all-thread scheduling history, or final framebuffer pairs were
  captured. Movie-entry samples are transition draws, not proof that EA,
  THX, and New Line frame rendering matches throughout playback.
- `DB620` appears in native observations but not the xemu sample; differences
  in I/O service paths and debugger/thread coverage require investigation.
  Absence alone is not proof the native callback is incorrect.
- Breakpoints pause execution and perturb interrupts/scheduling. Absolute
  frame counters and host durations from these traces cannot establish a
  pacing fix. Use the earlier sparse timing comparison for that purpose.
- Raw register/allocation addresses are not directly comparable. Generated
  register locals can also differ from original register snapshots.

## Recommended next work

1. Inspect and lift the observed unresolved `1FAEB7` and `16E60` entries,
   then verify the startup queue actually completes. Do not force completion.
2. For the gray legal logo, select one matching programmable draw and capture
   its texture bytes, vertex inputs, constants, and expected shader outputs.
   Implement the missing shader/texture-coordinate behavior against that
   fixture instead of adding another screen-position heuristic.
3. Trace movie update/presentation and UI-clock servicing across equivalent
   decoded-frame milestones. The clock and duration divergence are separate
   from proving that a movie draw is rendered correctly.
4. Extend comparison through a verified menu frame after queue completion,
   including texture contents and the menu background's rendering path.

Private ignored evidence is under `dump/analysis`: `matched-xemu.bin`,
`matched-recomp.bin`, their JSON metadata/logs, normalized summaries,
`matched-comparison.json`, and collector/parser helpers. These contain
game-derived memory and must remain excluded from Git. The analysis can be
repeated offline with `compare_matched.py`; recollecting native traces would
require deliberately reinstalling the now-removed temporary probes.
