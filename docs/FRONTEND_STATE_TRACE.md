# Front-end state trace (2026-10-01; xemu comparison 2026-10-03)

## Extended listening confirmation (2026-10-09, latest)

The user reports THX, New Line Cinema and main-menu music sound clean after
the pacing correction. EA alone has slight apparent static; source-video
quality is a hypothesis, not verified. Do not generalize this report into
complete audio fidelity or synchronization parity.

`audio-ea-listening-native` reaches queue completion at 38.375 s / UI 4040 ms
and continues for 30 seconds at the menu, stopping its owned process at
68.390 s without relaunch. This corrects the earlier short listening window:
prior runs generally stopped two seconds after queue completion, rather than
before the menu. No implementation changes were made during this pass.
Before changing EA decoding/mixing, compare equivalent EA audio with the
original source or emulator. Preserve the working general audio path.

## Audio pacing correction after the working checkpoint (2026-10-09, latest)

The first working-audio checkpoint remains documented separately. Subsequent
same-build tests isolate the coarse host wait as a major output-starvation
source; this is not yet user-confirmed elimination of every audible defect.

- `audio-coarse-control-native` selects only `RECOMP_APU_COARSE_WAIT=1`.
  At submission 400: 130 empty-queue observations, zero full rejections,
  span 9456 ms across 399 intervals, maximum gap 36939 us.
- `audio-hires-wait-native`, same build with that variable absent: at submission
  400, five empty observations (unchanged after attempt 100), zero full
  rejections, span 8511 ms and maximum gap 22027 us. The measured average
  interval is approximately 21.331 ms, close to 1024/48000 seconds. This
  comparison changes host waiting only, not sample rate, buffer sizes, guest
  script clocks, resource gates or command acknowledgements.
- The APU thread now uses its own high-resolution waitable timer for the
  existing 256-sample deadlines and releases the APU lock while waiting.
  Creation failure retains the previous condition-variable path; the named
  environment switch selects that path for controlled comparisons. The timer
  is closed on thread exit. The sleep-accounting accumulator now measures
  actual elapsed throttle time rather than effectively the final loop check.
- Full run `audio-hires-full-native` completes queue index 15 at **38.297 s,
  UI 4040 ms**, then stops at **40.312 s**. At attempt 1850, empty observations
  remain six (all accrued near startup), full rejections remain zero, span is
  39442 ms and maximum gap 21897 us. No crash or unresolved-call diagnostics
  occur. Nine completed-display samples agree across double reads; the menu
  image was inspected and retains the textured background/logo/menu.
- APU regression suite passes **5455 checks in Release and Debug**, including
  actual background-thread start, sample delivery and shutdown with a silent
  fake sink. The Release suite also passes with the coarse-wait fallback.
  Lifecycle tests deliberately do not assert scheduler-dependent throughput.

Proven: the measured recurring starvation largely disappears with accurate
host waiting, while startup still completes. Unverified: subjective smoothness,
audio/video synchronization, complete voice resampling/effects and all other
DMA memory domains. The existing DSP stub and mixdown remain limitations.
All bounded runs are stopped. No generated probes, commit or push were made.

## Working audio checkpoint (2026-10-09, latest)

The user confirms audible audio for the first time, with lag/choppiness.
APU interrupt delivery plus an explicit contiguous voice-table backing repair
now let the game's original ISR service traps and resume voice processing.
The previous missing-interrupt diagnosis below describes the pre-fix build.
The Mercenaries split-memory lead is now proven specifically for ThirdAge's
voice table, not for every DMA domain. APU regression tests pass 5452 checks
in Debug and Release; the full bounded run reaches queue completion at
38.329 s / UI 4020 ms without crash or unresolved-call diagnostics.

The first interrupt-enabled run exposed a crash; adding interrupt
synchronization alone did not restore VP progress. Comparing CPU and low-RAM
voice-table links then established the stale-bank mismatch. Explicit bank
binding removes that mismatch and the repeated idle traps in the verified run.
Audio still needs pacing/fidelity work: the final short diagnostic records
many empty device-queue observations with no full-queue rejection. No pacing
change was made before the user's checkpoint request. See the detailed
[working-audio checkpoint](WORKING_AUDIO_CHECKPOINT.md). Tests are stopped and
the working tree is preserved, without commit or push.

## Audio output repaired; pending APU interrupt blocks VP processing (2026-10-09, latest)

### Proven in the current build

- XAudio2 initializes successfully at 48 kHz, stereo, 16-bit. Earlier logs
  reporting no audio backend are historical, not the current explanation.
- Before the fix, `audio-boundary-native` recorded nonzero guest peaks (219,
  838, 658) but zero output peaks, with no mixer voices and mute disabled.
  `mcpx_apu_monitor_frame` cleared the completed 256-sample guest block and
  generated a full backend buffer every 256-sample interval instead.
- The monitor now preserves each completed guest block, mixes only 256 samples
  per interval, accumulates 1024 samples for XAudio2 / 2048 for waveOut, and
  clears the consumed block afterward. Rejected buffers are not replayed;
  waveOut buffers still owned by the device are not overwritten.
- The deterministic `tests/apu_monitor` harness links the real core, DSP
  passthrough and mixer to a fake XAudio2 sink. **5,435 checks pass in both
  Debug and Release**, covering ordered guest samples, stereo signs, stale
  buffer clearing, mute, mixer position/rate, rejection, invalid sizes and
  256/1024/2048-sample delivery. The waveOut device path is not live-verified.
  The Release game build succeeds. A missing `stdlib.h` declaration for
  `getenv` in the MMIO hook was also repaired.
- `audio-preserved-native` now records nonzero output accepted by XAudio2:
  guest/output peaks 173/238, 455/508, 579/813, each `submitted=1`.
  Startup queue index 15 is reached at 38.859 s, UI 4040 ms; the owned process
  stops at 40.891 s. This proves sample delivery, not perceived audio quality
  or complete movie sound.
- Sparse follow-ups isolate the remaining silence upstream of output.
  `audio-voice-source-native` runs six active non-stream VP voices during the
  legal interval, then VP processing ceases while output continues.
  `audio-trap-source-native` observes FECTL change from `0x100F` to `0x1FEF`
  (trapped mode, requested trap reason); IEN is `0xD9`, ISTS remains `0x60`,
  and `set_irq` remains true. The global interrupt bit and trap status bit
  have not been published by `update_irq`. Later FE writes can overwrite the
  method/argument registers, so those periodic values do not identify the
  original trapping voice.
- Static inspection confirms the standalone frame loop never consumes
  `set_irq`; `update_irq` is only called on ISTS writes. Its PCI interrupt
  functions are no-ops. The installed reference's
  [APU frame loop](https://github.com/xemu-project/xemu/blob/fc24584ce88f0915ad7f04775bb7712c2e3f49ee/hw/xbox/mcpx/apu/apu.c)
  consumes `set_irq` and updates the interrupt line before rechecking gates.
- ThirdAge connects vector 5 to original DSOUND ISR `0x0021F56E`, which calls
  `0x0021F4D2`: it reads `0xFE801000`, requires global status bit 0, acknowledges
  status, and calls `0x0021F3B5` for trap bit `0x10`. Vector 6's handler
  `0x002242F9` instead reads the AC97 aperture. These distinctions come from
  decoding the original image, not assuming all audio shares one vector.

### Next boundary and unverified hypotheses

Implement and test actual APU status publication and level-triggered delivery
to the registered vector-5 ISR on an existing guest-stack execution context.
Do not call guest code while holding the APU lock, clear FECTL to bypass the
handler, or acknowledge commands merely to obtain progress. Verify the original
handler services the trap and returns VP processing before attributing all
movie silence to this defect. DSP GP/EP execution is still a passthrough stub;
full movie audio, effects and audible synchronization remain unverified.

Mercenaries' updated `KERNEL_AUDIT.md` identifies an independent split-memory
risk: CPU contiguous uploads and masked low-RAM DSP reads can address different
backing. ThirdAge also has a separate contiguous bank, while `apu_shim.h` and
stream ADPCM reads mask into low RAM. This is a relevant audit target, **not a
proven cause for ThirdAge's remaining silence**. Mercenaries' validated scratch
transfers and bounded DSP probes are not a running DSP; no title addresses,
bootstrap programs or forced command acknowledgements were imported. Its older
`THIRDAGE_KERNEL_AUDIT.md` is historical and does not describe this build.

### Additional completed startup verification

- Completed-display-copy captures (not live guest render targets) demonstrate
  legal logo, EA Games/Challenge Everything, THX, New Line and textured menu.
  Seven double-read pixel copies agreed in each inspected capture run, but no
  observer lock was held. Black samples between logos are not established bugs.
- Vertex-upload accounting now avoids reporting consumed uploads as unhandled:
  distinct unhandled methods fell 245 to 188. Vertex checks pass 1246 in Debug
  and Release; combiner checks 1106 and framebuffer ownership checks 308 pass
  in Release. This accounting change is not a new rendering feature.
- A later software-FPU xemu repeat reaches post-movie setup at 52.187 s,
  final callback entry at 52.609 s, then queue index 15 by 54.625 s. Its movie
  interval is approximately 34.14 s: the earlier below-real-time run is not a
  stable baseline. Native UI endpoints vary by one 20-ms step between runs;
  exact instruction/timing parity is not established.
- Installed xemu rejects QMP `screendump` with CommandNotFound. The desktop
  screenshot helper also failed initialization; no paired emulator pixels were
  captured, so final-pixel parity remains unverified.

All diagnostic runs were bounded and their owned processes stopped without
relaunch. Logs, image data and observer scripts remain private/ignored. No
temporary generated-code probes were added; no commit or push was made.

## Movie preparation mismatch traced to xemu fast FPU (2026-10-09, latest)

The extra preparation wait in the recent emulator comparison is **not a reason
to delay the recomp**. A controlled xemu repeat with only `perf.hard_fpu = false`
preserves the audio-resource identifier, reaches the original audio-ready
callback and enters playback promptly. No guest resource, gate, clock, callback
or recomp runtime was changed for this experiment.

### Proven

- Both implementations prebuffer promptly: current frame -1, buffered frame 10,
  total 1022. In the original instructions, `0x001A0B84` sets buffer-ready,
  and `0x00193C50` requests audio. The longer wait occurs after these milestones.
- The original hexadecimal parser `0x000F5610` uses `%x`, zero-extends the parsed
  32-bit integer into a 64-bit local and executes `FILD` at `0x000F5693`.
  In the default xemu run, memory still contains the exact parsed integer before
  and after this instruction, but ST0 immediately afterward has lost low bits
  (rounded to single precision). The caller's subsequent integer conversion at
  `0x00194176` therefore returns a different resource identifier.
- These observations use execution breakpoints at `0x000F5693`, `0x000F5696`,
  `0x00194176` and `0x0019417B`, memory reads and separate GDB ST0/control-word
  reads. The installed build's register XML confirms ST0 register `0x19`, packet
  byte offset 100, and control register `0x21`, offset 180. The observed control
  word is `0x003F`. Do not decode this build's ST0 at the usual byte offset 64.
- Installed xemu is 0.8.136, commit
  `fc24584ce88f0915ad7f04775bb7712c2e3f49ee`. Its
  [fast translation path](https://github.com/xemu-project/xemu/blob/fc24584ce88f0915ad7f04775bb7712c2e3f49ee/target/i386/tcg/translate.c)
  selects an f32/f64 wrapper for integer loads; its
  [software FILD helper](https://github.com/xemu-project/xemu/blob/fc24584ce88f0915ad7f04775bb7712c2e3f49ee/target/i386/tcg/fpu_helper.c)
  instead temporarily maximizes precision. Intel specifies that FILD loads the
  integer without rounding errors in the
  [instruction reference](https://cdrdv2-public.intel.com/782156/325383-sdm-vol-2abcd.pdf).
  The recomp's double conversion preserves this 32-bit identifier exactly;
  this does not establish full 64-bit integer/extended-precision x87 coverage.
- Default/fast-FPU reference: transition to active playback occurs with elapsed
  approximately 4.003 s and UI time 7840 ms in `movie-fild-boundary-xemu`,
  consistent with the original four-second fallback rather than prebuffering.
- Software-FPU reference: the integer survives FILD and the caller conversion
  unchanged. `0x000FD258` executes the audio-event ready store at UI 3540 ms and
  elapsed approximately 0.133 s. The active-state store at `0x000FD3F9` follows
  at UI 3540 ms and elapsed approximately 0.150 s. The preceding native run
  observes active playback at UI 3540 ms and elapsed approximately 0.100 s.
  These are equivalent milestones, not instruction-exact timing parity.
- A subsequent sparse software-FPU run (`startup-soft-fpu-xemu`) reaches
  post-movie setup at 90.609 s with UI **3540 ms**, current frame 1020, buffered
  frame 1022, total cleared and movie state zero. It then enters the final
  startup callback at 91.797 s with UI 4020 ms and stops. This verifies the
  corrected reference beyond preparation; entry to that callback is not proof
  of its completion or a rendered main menu. The roughly 57-second movie
  interval still demonstrates below-real-time emulator throughput, not a
  reason to slow native playback.
- The existing native phase run observes startup-queue completion at UI
  **4020 ms**, the same value observed at the corrected emulator's final
  callback entry. These are adjacent, not identical, instruction milestones;
  this removes the earlier multi-second UI-clock discrepancy without proving
  exact callback timing or execution equivalence.

### Interpretation and remaining uncertainty

The controlled result attributes the changed identifier and extra preparation
wait to this xemu fast-FPU comparison, rather than a missing recomp buffer or
continuously advancing UI-clock service. Future reference captures should record
the FPU mode and use software FPU for this startup path. Do not round the native
identifier or introduce a four-second wait to reproduce the fast-FPU result.

Unverified: original Xbox hardware timing, audible playback (both environments
report an unavailable host audio backend), all-frame presentation and remaining
3D renderer behavior. The native audio-ready store itself has not been directly
breakpointed; native state samples and original control flow support, but do not
replace, a direct callback trace. This is not a claim that every xemu arithmetic
difference or every startup timing difference is resolved.

Private evidence: `movie-preparation-native`, `movie-preparation-xemu`,
`movie-audio-id-xemu`, `movie-fild-boundary-xemu`, `movie-fild-soft-fpu-xemu`
under ignored `dump/analysis/`. Both new emulator experiments were bounded,
stopped their owned processes and did not relaunch. There were no generated-code
probes, runtime edits, commits or pushes in this follow-up.

Verification follow-up: the third, full-startup software-FPU run was also
bounded and stopped. The focused FPU lifter/reverse-operation/branch suite
passes **18 tests**. Broad unittest discovery completes the available 137
tests but reports seven module-import errors because the existing project
environment lacks pytest; this is not a clean full-suite pass. The bundled
Python was initially unsuitable because it also lacks Capstone, so focused
verification uses the existing project virtual environment. Neither environment
was modified. Root and vendor whitespace checks pass; private probes/configs
and logs remain Git-ignored.

## Movie/UI-clock diagnosis corrected by phase samples (2026-10-09, latest)

The small native UI-clock advance during the movie is **not, by itself, a
missing timer-service bug**. Targeted original disassembly and new phase samples
show that the game deliberately omits ordinary UI updates during active movie
states 4/5. Earlier endpoint-only comparisons conflated preparation and playback.
Do not force UI time forward or add a compensating delay based on those endpoints.

### Proven

- Original `0x000B12D0`, specifically `0x000B1345` through `0x000B136C`, checks
  movie enable/activity and state `0x002FD380`. States 4/5 skip the call to the
  normal UI updater `0x000B7ED0`. Generated control flow matches that branch.
- Both native and xemu use UI mode `0` at `0x00329C7C`; the UI updater supplies
  fixed 20-ms steps in this mode. `0x000B5F40` advances `0x00310514` by script
  steps. The UI timer is not a continuously running host-time clock.
- `movie-frame-state-native`: active-state samples at 3.500 through 37.375 s
  progress from frame counter 4 to 1019 while UI time is **constant at 3520 ms**.
  Movie elapsed time progresses from approximately 0.17 to 34.03 s. Preparation
  state 3 is visible at 3.281 s, then active state 4 by 3.500 s.
- `movie-frame-state-xemu`: movie request at 37.937 s has UI time 3460 ms;
  at 42.953 s, it is still preparation state 3, frame counter -1, UI time
  6660 ms. At 47.969 s it is active state 4, frame 51, UI time **8040 ms**.
  Subsequent five-second samples through frame 974 keep UI time at 8040 ms.
  Post-movie setup also sees 8040 ms. Thus the extra UI time in this run
  accumulates before active playback, not throughout the movie.
- Native and xemu both report 1022 total frames and approximately 29.97003 fps,
  consistent with the local VIDH fields (1022, 30000/1001). Nominal stream
  duration is approximately **34.101 s**. Both runs end with current counter
  1020, buffered counter 1022, total cleared to zero and movie state zero.
  Matching counters do not prove every frame was drawn or audible.
- The native run completes its startup queue at 38.844 s and stops at 39.875 s.
  The sampled xemu run reaches entry to the final startup callback and stops at
  102.281 s. A separate sparse xemu clock-state run also reached that callback
  and stopped at 102.922 s. Both native diagnostic runs and both xemu runs were
  bounded, stopped their owned processes and did not relaunch.

### Interpretation and remaining uncertainty

The active-playback UI pause is consistent between implementations and supported
by original control flow. The absolute post-movie UI-clock mismatch is now
localized to unequal preparation progress, not evidence for a broken continuously
advancing UI timer. Native playback counter progression is consistent with the
nominal stream duration; do not slow it to match an emulator wall-clock run.

These fresh xemu runs report no default audio device and visibly measured
counter progression is below real time (about 18-19 frames/s during the sampled
active phase). Their roughly 63-second request-to-post-movie interval is **not**
a replacement for the earlier approximately 38-second emulator measurement.
Audio-device failure, host throughput and debugger interruptions are confounds;
none alone is proven to cause the slowdown. Five-second interrupts perturb the
run; all-state reads are paused snapshots in xemu but non-atomic in native.

Still unverified: why preparation state 3 lasts longer in xemu (decode/prebuffer,
I/O, audio readiness or another gate), exact presentation/audio timing, all-frame
playback and hardware-equivalent startup timing. Preparation comparisons should
use readiness/counter/state milestones, not equal host durations. No runtime
clock, guest gate or callback was changed in this investigation.

Private evidence remains ignored under `dump/analysis/`: `movie-clock-state-*`,
`movie-frame-state-*`, `MovieClockReview.java` and `ghidra-targeted/movie-*.txt`.
The Ghidra project was opened read-only. Some automatically created function
boundaries in auxiliary decompilations are unreliable; the UI-skip finding was
cross-checked against original instruction disassembly and generated control
flow rather than trusting those decompilations alone. No generated-code probes,
commit or push.

## Later vertex program and solid-color cost repaired (2026-10-09, latest)

The later native menu capture contains a 61-instruction vertex program starting
at slot 12. Its previously unsupported operations include EXP, ARL and relative
constant reads. The paired xemu capture ends before this program is submitted;
absence there is not evidence that the original game does not use it.

The bounded interpreter now implements EXP's four outputs, ARL's address
register, and relative constant indexing. Sources read the old address register
before paired operations commit. Invalid constant indices and non-finite or
extreme address-register inputs fail safely rather than indexing host memory.
ARL uses floor, consistent with the
[NVIDIA vertex-program specification](https://registry.khronos.org/OpenGL/extensions/NV/NV_vertex_program.txt).
This deliberately does not copy xemu's added 0.001 rounding heuristic. Exact
NV2A edge-case equivalence remains unverified; the specification alone does not
prove Xbox constant-bank bounds or exceptional-value behavior.

For triangles with flat color and no sampled textures, the renderer now runs
the submitted combiner once per triangle, instead of repeating identical work
for every pixel. Textured draws retain per-pixel execution. This optimization
depends on the current flat-color rasterizer and must be revisited when color
interpolation is implemented; it does not bypass a guest state or resource gate.

### Verification

- Vertex-program regression: **1,164 checks pass in Debug and Release**, including
  EXP, negative/boundary ARL, paired old-address reads and invalid indices.
- Combiner regression: **1,106 checks pass in Debug and Release**, including
  flat-path equivalence and the textured-path exclusion guard. Framebuffer
  ownership regression: **308 Release checks pass**. Release game build succeeds.
- Before the solid-color optimization, `startup-vsh12-expanded` completes the
  startup queue at 42.860 s, with no vertex/combiner rejection or unresolved-call
  diagnostics found. Its single background-only surface sample does not establish
  complete menu rendering.
- After optimization, `startup-flat-combiner-hoist` reaches legal index 7 at
  0.672 s and movie index 9 at 3.484 s (2.812 s interval). The corresponding
  pre-optimization interval was about 6.6 s. Queue completion is **38.609 s**,
  compared with 42.860 s in the preceding light run. These are externally polled
  equivalent milestones, not exact instruction timestamps or xemu timing parity.
- Six non-atomic menu-surface captures sample both observed render targets at
  39.609, 40.609 and 41.609 s. Inspected final captures show the textured backdrop,
  gold logo and New Game / Load Game / More options intact. They are guest
  surfaces, not window screenshots or proof that every 3D draw is correct.
- No vertex/combiner rejection, unresolved-call, fatal or crash diagnostic was
  found in the bounded optimized run. The owned process stopped at 43.641 s;
  no relaunch loop. No temporary generated-code probes, commit or push.

### Still open

The movie interval remains about 34 s while the guest UI clock advances only
from about 3500 to 3540 ms. Reduced renderer cost does **not** resolve this
divergence. Exact emulator-relative movie timing, audio and complete playback
still require comparison. LOG/LIT and other unsupported vertex-program state,
perspective-correct interpolation, interpolated diffuse/specular, clipping,
depth/stencil/alpha tests and filtering remain coverage gaps. Acceptance of the
later shader is not evidence that all its geometry is correct. Game/scene
rendering beyond startup has not been demonstrated in this pass.

Private instructions, captures, logs and observer scripts remain ignored under
`dump/analysis/`; public regression fixtures are synthetic, not copied shaders.

## Movie texture/combiner rendering implemented (2026-10-09, latest)

User reports flicker appears to have ceased after completed-frame presentation.
This supports that diagnosis for the observed pass, not a long-run guarantee.

The active software renderer now retains all four texture stages independently,
including each stage's dimensions, pitch, address modes and CONTROL0 enable.
Linear AY8 (`0x1B`) sampling replicates one byte into RGBA, following the local
xemu format table, rather than the unrelated packed-nibble D3D upload helper.
Texture coordinates are fetched independently for each stage (attributes or
vertex-program outputs), rather than reusing stage 0's UVs for every plane.

A bounded, title-independent register-combiner evaluator now consumes the
submitted input/output words, constants and final combiner. It handles the
eight input mappings, multiply/dot/sum/mux, signed intermediate clamping,
output bias/scales, blue-to-alpha and simultaneous RGB/alpha pre-stage reads,
shared/unique constants and final A*B+(1-A)*C+D / EF / V1+R0 inputs. The movie
uses its actual submitted five-stage program, not a forced YUV conversion or
front-end/resource override. Single-texture UI also uses submitted combiners,
which visibly changes the previously dark legal/menu colors.

### Verification and observed results

- Release build succeeds. New synthetic format/combiner regression: **593
  checks pass in both Release and Debug**. Includes all AY8 byte values, field
  routing, signed mappings, dot/mux, simultaneous writes, unique constants,
  final inputs, and rejection of unsupported state. The tests contain no
  original game shaders or assets.
- Existing vertex-program regression: 880 checks pass; framebuffer ownership
  regression: 308 checks pass in Release after integration.
- First bounded run (`combiner-movie-visual`) has inspected captures of the EA
  Games animation and THX logo in color, replacing the white rectangle, then
  reaches queue index 15 and a textured menu at approximately 67.437 seconds.
  It stopped at approximately 68.6 seconds. Generic per-pixel arithmetic was
  initially too expensive; this run is not a timing-parity success.
- Finite normalized-color min/max arithmetic was then inlined, avoiding
  repeated C-runtime calls. A stage-0 enable recomputation triggered by other
  stage updates was also corrected to preserve CONTROL0 enable semantics.
- Follow-up (`combiner-movie-refined`) has inspected THX at approximately
  19.734 s, New Line animation at 27.765/31.781 s and the New Line Cinema logo
  at 35.812 s. It reaches index 15 and the textured, brighter menu in the first
  observed menu sample at 43.140 s. Four menu samples end at 44.250 s and the
  owned process stopped at 44.281 s. Some sparse movie samples are black;
  non-atomic guest-surface reads and transition frames prevent concluding
  that those samples represent a display defect. EA was not visibly captured
  in this refined run's sparse samples; it was demonstrated in the first run.

The first observed menu sample improves from about 67 s to 43 s, but these
are instrumented native surface samples, not exact callback timings. The
previous pre-combiner queue-completion result was about 38 s. Remaining CPU
rendering cost and the previously identified movie/UI-clock divergence are
still open. No claim is made that correct colors restore timing parity.

### Remaining coverage limits

- Supported texture shader modes are NONE and PROJECT2D only. Fog inputs and
  invalid/specialized combiner state are rejected rather than silently treated
  as supported. No unsupported-combiner diagnostic was seen in the refined run.
- Four vertex-program rejection messages for program start 12 appear later
  in the refined run. The earlier vertex interpreter is still a subset; these
  omitted draws need targeted inspection. A visible menu is not complete
  rendering coverage.
- Colors remain flat per triangle; secondary/specular color is currently zero
  in the combiner caller. Perspective-correct interpolation/projective texture
  W, filtering, depth/stencil/alpha tests, full texture addressing and accurate
  fixed-point arithmetic remain unimplemented or partial.
- Actual window smoothness, initial white-box outcome, audio, exact colors,
  complete intro playback and long-run stability need user/paired verification.

Private captures/logs/scripts remain ignored under `dump/analysis/combiner-*`.
Both owned game processes stopped; no relaunch loop, generated-code probe,
commit or push. Next: visible repeat and performance/milestone comparison,
then targeted read of rejected vertex program 12 and remaining rendering gaps.

## Isolated completed-frame presentation repair (2026-10-09, latest)

The renderer no longer publishes a window image at each geometry batch END.
It now synchronously captures the last drawn surface at the existing
`FLIP_STALL` boundary, retaining that surface's drawing pitch rather than
borrowing the possibly changed pitch of the next target. Flip counters and
guest semaphore/queue logic were not changed. This is the existing bounded
bring-up flip model, not complete hardware scanout timing or buffer ownership.

The GDI presenter now protects completed pixels and metadata with an SRW lock.
It never scans live guest RAM in the window thread, including before the first
completed frame. Fixed-lifetime storage replaces the window-thread allocation
that the producer could race with during close. Image dumps take a protected
snapshot before writing the file. User-close suppression is retained; close
does not permit routine renderer calls to reopen the window.

Verification:

- Release build succeeds.
- New synthetic framebuffer ownership regression: **308 checks pass in both
  Release and Debug**. Covers two concurrent publishers versus readers,
  immutable published pixels after guest memory reuse, 32-/16-bit conversion,
  and explicit-close suppression without opening a test window.
- One bounded `presentation-flip-visual` startup run ended at approximately
  40.16 seconds with its owned process terminated and no relaunch. Four legal
  samples preserve the logo/legal text. Four menu samples at 39.016-40.125 s
  have queue index 15/15 and retain the textured menu.
- The sampled final presentation-log tail alternates surfaces `0x80230000`
  and `0x80104000`, each with 253,563 nonzero pixels and brightest RGB `7F7F6F`.
  This is consistent with completed menu publication, but pixel coverage is
  not a full frame hash or proof of flicker-free visible playback.

Proven: per-batch publication and the converted-buffer read/write/lifetime
races are removed from this path; startup/menu progress is retained.
Unverified: user-visible flicker outcome, hardware-equivalent flip semantics,
exact frame pixels, and long-run stability. The diagnostic PNGs are external
guest-surface samples, not screenshots of the protected GDI copy. Movie texture
sampling/combiners and timing were deliberately unchanged to isolate this fix.
The earlier coverage table below describes the pre-repair audit.

No generated-code probes, guest state overrides, commit or push. Private
evidence remains ignored under `dump/analysis/presentation-flip-visual*`.
Next priority: movie AY8 sampling, per-stage texture/UV state and actual
register-combiner execution, with synthetic coverage before integration.

## Renderer coverage audit and vertex-program verification (2026-10-09)

The legal-logo texture was read from the running recomp and independently
decoded: it contains the intact LOTR / The Third Age logo. Offline evaluation
of the matched xemu/recomp vertex inputs gives the same logo rectangle,
approximately (251,58)-(395,186), and generated UVs (0,0)-(1,1). The old
renderer instead used raw (0..256) positions, found no UV attribute, and drew
an untextured gray shape. This identifies the missing vertex-program stage
for that draw; it is not a diagnosis of every movie/menu artifact.

A bounded vertex-program interpreter is now integrated. Release builds and
880 synthetic checks pass in both Release and Debug. It supports the captured UI arithmetic subset;
unsupported programs are rejected rather than drawn with raw positions.
The isolated in-game verification below demonstrates improved legal/menu pixels.
Private texture and numerical evidence
remain under ignored `dump/analysis`; no original game shader tokens or assets
were added to the public tests.

### Core renderer gaps to retain as follow-up work

| Stage | Confirmed implementation limit | Causal status / priority |
| --- | --- | --- |
| Vertex programs | Subset only; relative addressing, context writes and some special functions unsupported | Verify the new legal-logo path first; broader coverage remains unverified |
| Pixel processing | Fixed texture-times-color operation, not the game's register-combiner program; single sampled texture stage | Compare affected startup draws after vertex verification |
| Movie texture formats | Active sampler lacks linear AY8/AL8 (`0x1B`), which the movie path binds | Confirmed exercised gap; requires multi-stage/combiner support as well |
| Presentation | Per-draw-batch publication; shared converted frame buffer lacks synchronization | Incomplete-frame/race risk established in code; causality for observed flicker unproven |
| Fragment tests / blending | No depth, stencil or alpha test in the pixel-writing path; limited blend factors | Needed for broader rendering; exact startup dependencies not yet audited |
| Interpolation / sampling | Flat vertex color, affine UVs, nearest sampling; incomplete address/filter behavior | General fidelity gaps, not isolated causes of current artifacts |

These gaps are an implementation audit, not an exhaustive hardware audit or
proof that every missing feature is exercised during startup. Movie/UI-clock
divergence remains a separate unresolved issue. Do not change these additional
stages until the vertex-program change has been tested in isolation.

### Isolated in-game result

`vertex-program-visual` ran once, bounded to 55 seconds with a 60-second
watchdog, and terminated its owned process at 40.157 seconds. The verifier
read guest draw surfaces externally; its PNGs are non-atomic surface samples,
not screenshots of the window or a completed-frame xemu pixel comparison.
No presentation, combiner, filtering or fragment-test change accompanied it.

- Four legal-phase samples at approximately 0.625-1.735 seconds show the gold
  LOTR / The Third Age logo above the legal text, replacing the gray rectangle.
- Four menu-phase samples at approximately 39.032-40.125 seconds, with startup
  queue index 15/15, include a textured background, large gold logo and readable
  New Game / Load Game / More options. The inspected menu sample no longer has
  the previous broad gray/checkerboard region.
- No unsupported vertex-program diagnostic or unresolved-call message was
  found in this run's log. That is bounded-path coverage, not full shader or
  startup correctness. Existing audio-device/file diagnostics remain.
- Movie frames were not captured. Correct movie playback, exact colors and
  blending, window flicker, frame ownership and timing parity remain unverified.

All captures/logs/scripts remain ignored under `dump/analysis`. No owned game
process remains, no generated-code probe was added, and nothing was committed
or pushed. Next work can isolate presentation and movie rendering separately;
the vertex-program change has now demonstrated a visible legal/menu benefit.

### Remaining symptom-to-gap investigation (2026-10-09)

User's visible repeat confirms: legal/menu logo is present, flickering persists
but is less severe, initial startup has a white box, and no movies are visible.
The user authorizes individually initiated test relaunches as needed, never a
relaunch loop. The hidden-launch repeat was stopped and replaced with a visible
instance; the bounded visible repeat subsequently ended.

Two independent diagnostic launches ended at their 14- and 32-second bounds.
They changed no production renderer code. Existing `RECOMP_TEX_STATE` and
unhandled-method diagnostics supplied movie-period state, and external reads
sampled the indicated guest textures and draw surface. Report state is not an
atomic draw snapshot; the first 8-second sample preceded the first full texture
report and had no useful texture registers.

The useful movie-period samples show three linear `0x1B` textures:

- stages 0 and 1: 320x256, byte pitch 320;
- stage 2: 640x512, byte pitch 640;
- combiner control `0x00011105` (five stages), shader-stage program `0x421`,
  and nontrivial color input/output words. These methods are unhandled by the
  active renderer, which samples only texture stage 0 and modulates by color.

The xemu reference maps linear AY8 to a single byte replicated into all RGBA
channels. Our active `sample_texture()` has no `0x1B` case and returns failure,
causing the per-pixel fallback to the vertex color. A similarly named AL8
conversion in the separate D3D resource path uses packed nibble semantics;
that path is not this renderer, and should not be copied without verification.

At approximately 12/20 seconds, sampled chroma bytes were uniformly 128 and
luma was near 16. At 28.015 seconds, all three planes contain varying data;
the stage-2 grayscale image visibly depicts New Line Cinema's filmstrip logo.
The corresponding externally sampled draw surface is a solid white rectangle
within the viewport. This proves delivery of recognizable decoded movie image
data to guest memory for at least that sampled frame. It does not validate the
entire movie decoder, every logo, video timing, or exact chroma/order/conversion.

| Remaining symptom | Most relevant demonstrated gap | What is not yet established |
| --- | --- | --- |
| Movies replaced by white rectangle | Unsupported AY8 sampling plus missing multi-texture/register-combiner execution; decoded imagery exists | Correct combiner output, UV sets, chroma order and complete movie playback |
| Legal/menu flicker | Per-batch publication and unsynchronized shared presentation buffer | Causal isolation via completed-frame/synchronized presentation test |
| Initial white box | Pixel combiner and texture-enable semantics, plus unfinished-frame presentation, are candidates | Exact offending early draw and intended pixel output |
| Movie/UI clock mismatch | Separate scheduling/servicing divergence from prior paired trace | Whether correct rendering changes throughput/timing; no assumption that it fixes clock logic |

The executor also computes texture validity from address/dimensions/pitch,
without honoring `SET_TEXTURE_CONTROL0` enable or shader-stage selection. Thus
stale disabled-stage sampling is another concrete state-handling gap, but its
causal relationship to the initial white box is not proven. Filtering, depth,
stencil and perspective support remain general follow-ups; this pass supplies
no evidence that they are the primary movie/flicker blockers.

Next isolated changes: completed-frame presentation/buffer ownership for
flicker, then verified AY8/multi-texture/combiner execution for movies. Do not
replace the game's combiner with a title-specific forced YUV conversion.
Private evidence: `movie-gap-audit.json`, `movie-plane-gap-check*` logs/JSON/PNGs
and observer scripts under ignored `dump/analysis`. All owned diagnostic
processes stopped. No commit, push, generated-code probe or automatic relaunch.

## Command-driven GPU completion (2026-10-08, latest)

The Third Age five-bit pattern-reference completion workaround is now disabled
at its registration in `src/main.c`. The shared helper remains available for
other callers, but this title no longer registers it. Shader execution and
movie timing were deliberately unchanged in this pass.

### Evidence and implementation

- Original instructions at `0x0022F048` assign the completion allocation to
  device `+0x30`; `0x0022F18F` creates DMA handle 8 from that same pointer.
  `0x0022BC43` emits semaphore release, and `0x0022BE90` compares its buffer
  against the low five progress bits in PGRAPH. These were independently
  disassembled from the original XBE, not inferred solely from lifted code.
- All 25 captured xemu and 95 captured recomp releases had a corresponding
  matching low-five-bit pattern write. Different capture limits explain why
  these counts are not directly comparable; no decoder gaps were reported.
- The executor now handles `0x01A4`, `0x1D6C`, and `0x1D70`: resolve the bound
  handle through RAMHT/PRAMIN, validate channel, DMA class/direct-entry format,
  destination alignment and full-dword bounds, then publish the full release
  value after earlier synchronous raster work. No game address is hardcoded.
- GET is no longer mirrored to PUT before reading commands. The reader starts
  from actual GET, retains partial packet state, follows old/new jumps and
  one-level CALL/RETURN, and has a per-poll work budget. Malformed commands
  stop consumption; unconsumed data is not acknowledged. First submissions
  and backwards buffer jumps are no longer skipped by a `put > last_put` gate.
- The scanner's incorrect `0x1D6C` stencil-clear label was corrected.

References: [xemu v0.8.136 semaphore implementation](https://github.com/xemu-project/xemu/blob/v0.8.136/hw/xbox/nv2a/pgraph/pgraph.c#L2642),
[PFIFO consumption](https://github.com/xemu-project/xemu/blob/v0.8.136/hw/xbox/nv2a/pfifo.c#L270),
and the updated Mercenaries audit/validated direct-frame decoder. This remains
a bounded single-channel bring-up implementation, not complete PFIFO, tiled
memory, paged DMA, or asynchronous host-GPU completion emulation.

### Verification and observed limits

- Release build succeeds. New push-stream/DMA regression: **1,585 checks pass
  in both Release and Debug**, including all tested packet split positions,
  bounded resume, nonincrementing methods, full counter values across five-bit
  wraps, backward jumps, CALL/RETURN, invalid streams and DMA bounds.
- Existing frame-clock regression passes 149,722 checks; PCRTC CTest passes.
- `startup-semaphore-owned`: queue reaches 15/15 at 38.097 s, diagnostic ends
  at 41.139 s. The first 16 logged releases correctly resolve handle 8 through
  instance `0x11B0` to this run's guest `0x80000000`, values 5 through 35.
  No rejected release, command-stream fault or unresolved-call failure logged.
- `startup-semaphore-wrap-check`: queue reaches 15/15 at 38.053 s. Four
  one-shot jump reports include three backwards jumps, with consumed GET
  reaching the sampled PUT. This demonstrates real buffer-wrap progress, not
  just the synthetic tests. This is a lightly instrumented run, not a new
  paired xemu comparison or a zero-diagnostic timing measurement.
  It stopped at 98.094 s with no logged crash, unresolved call, rejected release
  or stream fault, passing the older 88.75 s crash endpoint without reproducing
  it. One bounded non-reproduction does not establish long-run stability.
- User's visual observation: legal screen flickers and still has a gray box;
  subsequent white box; menu has a cyclic flashing checkerboard, apparently
  counterclockwise. Correct final pixels are **not** demonstrated. No claim
  is made that this visual pattern is new or caused by the completion change.

Proven: startup progresses with real semaphore releases and without the
five-bit completion writer; backward command-buffer jumps are consumed.
Unresolved: movie UI clock still reaches only 3560 at post-movie setup and
startup duration is essentially unchanged. Shader-generated UVs remain a
confirmed missing renderer capability. Displaying an unfinished surface is
another possible explanation for flicker, not a verified diagnosis.

Private evidence remains ignored under `dump/analysis`. No generated-code
probes were added, no game assets were changed, and nothing was committed or
pushed. Both owned test processes stopped; no automatic relaunch occurred.
Next rendering work should compare one legal-logo draw's numerical
vertex outputs/texture pixels and completed-versus-presented surface ownership.

## Startup completion repaired; frame cadence corrected (2026-10-08, latest)

Two control-flow repairs now let the observed startup queue reach index 15
of 15, rather than remain at index 14:

- `0x00016E60` is an independent final queue callback, confirmed from original
  instructions and the xemu trace. It adjusts the context and tail-calls
  `0x001F2FB0`. It is now seeded, generated, and present in dispatch.
- **Correction to the earlier callback description:** `0x001FAEB7` is not an
  independent callback. It is a local switch arm in `0x001FAE90`. A byte-map
  switch has only one pointer-table entry, rejected by the lifter's previous
  two-entry minimum. The lifter now accepts a single pointer only at an
  already decoded local instruction, with pointer-sized indexed addressing.
  It emits a guarded local goto and retains indirect fallback for other
  runtime targets. This does not expand function ownership or seed the arm
  as a separate function. Five synthetic regressions cover the new rule.

The control-flow-only run completed the queue around 57.03 s, with no logged
unresolved indirect calls. Timing remained slow, isolating this improvement
from the subsequent scheduler change.

The frame scheduler now uses an absolute fractional 60 Hz QPC deadline grid
and short blocking high-resolution timer wakes, replacing `Sleep(10)` plus
`now + 16`. Late polls no longer accumulate phase drift, and a delayed poll
asserts at most one interrupt rather than replaying missed frames in a burst.
This remains a 60 Hz bring-up mode, not full video-mode/50 Hz emulation.
The ordinary-timer fallback is present but has not been benchmarked. Generic
periodic kernel timers and audio scheduling are not claimed fixed.

| Observed metric | Before frame-clock change | After | xemu reference |
| --- | --- | --- | --- |
| Legal phase | approx. 4.25 s | approx. 2.8 s | 2.795 s |
| Legal counter cadence | approx. 40/s | 60.12/s sampled | 60.10/s |
| Movie-request to post-movie wait | approx. 51.37 s | approx. 34.19 s | 38.095 s, callback-to-callback |
| Startup queue completion | 57.03 s after control-flow repairs | 38.02 s | Not timed through callback return |

Native milestones are externally polled every 20 ms and are approximate;
index 10 follows movie request and index 13 follows post-movie setup. The
movie interval is now shorter than xemu's, not equivalent. UI clock remains
near 3520 during native movie playback versus thousands of milliseconds of
additional progress in xemu. **Frame cadence is improved; movie timing and
UI-clock servicing are still unresolved.**

### Startup call coverage audit

A separate bounded diagnostic added first-hit-only logging to every one of
the 130 generated unresolved-target stubs. It completed the queue at 38.13 s
and ran four more seconds, ending at 42.16 s. No stub hit or unresolved
indirect-call failure was recorded. This supports coverage of the exercised
boot path; it does not identify every possible startup call, prove all
translated instructions are correct, cover alternate/input-dependent paths,
or validate all kernel/GPU/audio implementations. The compiler still reports
unimplemented instructions and generated stubs exist for unexercised paths.
The previous longer-run UI crash has not been retested to its old endpoint.

### Renderer follow-up narrowed, not yet implemented

Offline decoding of the matched legal submissions confirms the same
10-instruction program explicitly writes texture-coordinate output 0 using
two dot products of position-derived inputs and constants. It also computes
position and diffuse color. The shorter 8-instruction program lacks those
texture-coordinate output writes. The current software renderer does not
execute either program; it fetches presumed UV attributes instead. Thus
shader-generated UVs are a confirmed missing capability, although texture
content, numerical shader outputs, and the exact gray-logo draw still need
an end-to-end fixture before claiming the visual fault is resolved. No
renderer behavior was changed in this pass.

### Verification and cleanup

- Release build passes; existing unrelated warnings remain.
- All 137 runnable unittest-based compiler tests pass. Seven additional
  pytest-dependent modules could not be imported because pytest is absent;
  those modules are not included in the passing count.
- 149,722 synthetic frame-clock checks pass in both Release and Debug,
  including fractional periods, jitter, delayed polls, and no catch-up burst.
- Existing PCRTC regression executable: 60,057 checks, no failures. Existing
  topology executable: 445 checks pass.
- All temporary stub-audit probes were removed and the clean Release binary
  rebuilt. No generated-code probes remain. Diagnostic processes stopped;
  no automatic relaunch, commit, or push occurred.

Private ignored evidence: `startup-controlflow-fixed`,
`startup-frameclock-fixed`, and `startup-stub-audit` JSON/log sets under
`dump/analysis`, plus `inspect_legal_program.py` for offline shader inspection.
Next priorities: shader-output/texture fixture for the legal logo, then movie
update/presentation versus UI-clock servicing at matched frame milestones.

## Matched startup/state/GPU comparison (2026-10-08, latest)

See [STARTUP_COMPARISON.md](STARTUP_COMPARISON.md) for the bounded paired trace.
Resource type samples and UI parser input prefixes match, and startup script
commands align through the legal screen. The first eight legal-screen GPU
submissions also match in shader instruction upload groups, shader constants,
texture format sets, and selected vertex layouts. This strengthens the case
for a renderer execution gap without proving full texture/vertex equality.

Movie UI-clock divergence and unresolved native calls to `1FAEB7` / `16E60`
are independently reproduced. The trace is sampled, not an exhaustive
all-task or complete-menu-frame comparison. No runtime fix was made during
this pass. Temporary generated-code probes were removed, Release rebuilt,
and diagnostic processes stopped; private captures remain ignored.

## Emulator timing comparison and longer-run limits (2026-10-08, latest)

**Startup is much faster after the interrupt fix, but timing does not yet
match the original in xemu.** The user's visual inspection also supplied a
screenshot with readable New Game / Load Game / More text over a gray
rectangle. This establishes visible menu UI, not correct rendering or a
successfully completed startup queue.

A clean xemu run and a subsequent recomp run were performed sequentially.
The previously launched inspection process was still consuming CPU after
its window disappeared; it was stopped with explicit user approval. The
first xemu measurement overlapped that background process and was retained
only as a repeatability check (legal interval 2.788 s). The clean repeat is
the baseline below. Neither run received gameplay input or state overrides.

| Phase / counter | xemu original | Recomp |
| --- | --- | --- |
| Legal-screen phase to movie request | 2.795 s, 168 frame updates | approx. 4.217 s, 168 frame updates |
| Movie request to post-movie setup | 38.095 s | approx. 51.295 s |
| Frame counter during legal phase | 60.10 updates/s | 39.84 updates/s |
| Final startup callback | `0x00016E60` reached | repeatedly unresolved at index 14 |

These are **execution milestones, not video-recorded visible transition
times**. xemu used sparse one-shot GDB execution breakpoints at `0x16F60`,
`0x16F30`, `0x16EA0`, and `0x16E60`; host time spent stopped handling the
debugger was excluded. It reached legal at 16.994 seconds from emulator
launch (including boot), movie request at 19.792 s, post-movie setup at
57.890 s, and final callback at 58.307 s. The unobserved `0x16F80` callback
is not required to claim those four milestones; the clean test ended at
`0x16E60`, not at a separately verified rendered-menu frame.

The recomp was sampled externally every 20 ms, with counters retained every
200 ms. It reached legal wait/index 7 at 0.667 s, movie request/index 9 at
4.884 s, post-movie wait/index 13 at 56.179 s, and final/index 14 at
57.191 s. Native polling can miss brief callbacks: legal wait follows the
legal callback, and index 13 follows the post-movie callback at index 12.
Consequently the native phase times are approximate, not identical
instruction-boundary measurements. The large timing differences exceed
that sampling uncertainty. Different boot paths make total launch-to-menu
wall time an unsuitable direct comparison. Individual EA/THX/New Line
visible durations were not separately measured.

The coarse host timer (`Sleep(10)` scheduler, `now + 16` vblank gate) is a
credible remaining pacing cause, but this pass did not change or isolate
that implementation. Movie duration also differs; it is not proven to be
entirely explained by vblank cadence. UI clock values diverge across the
movie phase (original 3460 -> 8260 ms; recomp 3460 -> 3560 ms at the sampled
post-movie state), so do not assume only presentation speed differs.

Longer execution exposed previously untested problems:

- One unresolved call to `0x001FAEB7`, then repeated unresolved calls to
  `0x00016E60` (836 logged). The latter entry is absent from generated
  declarations/dispatch and leaves the startup queue at index 14.
- A later access violation reading guest `0xC7000278`, with native RIP RVA
  `0x892C36`, resolving against the current Release map to
  `sub_000B0080+0x236`. The run ended around 88.75 seconds, before its
  120-second collection limit. A causal link from either unresolved call
  to this crash is **not established**.

Thus the earlier short post-fix runs correctly showed no recorded crash
through their movie-request endpoint; they did not establish later startup
stability. No implementation, seed, clock, or generated code was changed
during this timing comparison. All emulator/game processes are stopped;
nothing committed or pushed. Private evidence remains ignored:
`startup-timing-xemu.json`, `startup-timing-xemu-clean.json`,
`startup-timing-recomp-clean.json`, and corresponding logs. The first xemu
run timed out waiting for an additional callback after already recording
the four useful milestones; the clean repeat ended at the final callback.

Next work: correct the remaining pacing mismatch, inspect/lift the two
unresolved targets, and independently diagnose the UI crash. Menu rendering
still needs the missing texture/shader path; it is not the only remaining
problem.

## Startup timing fix: preserve and acknowledge frame interrupts (2026-10-08)

**The movie-request milestone now occurs at about five seconds, not three and
a half minutes.** This is a runtime interrupt fix, not a forced title flag,
script clock adjustment, or direct splash callback.

### Evidence and cause

External native instruction-pointer profiles (`slow-profile`,
`slow-profile-detail`) found roughly 98% of main-thread samples in
`0x001C09E0`. The sampled native offsets resolve to the original
`0x001C0A70` loop, waiting for `MEM32(0x30AF68) - previous >= 1`.
`0x000BF1E0`, installed as the vertical-blank callback, copies the delivered
frame count into that word. In the detailed baseline, the counter advanced
31 to 76 over 18.24 wall seconds: approximately 2.47 updates/second.

The GPU acknowledgement thread also spent most sampled time looking up
`RECOMP_PATTERN_TRACE` in the environment. Caching this startup option removed
the lookup hotspot, **but did not restore frame progress**: the isolated
`cached-pattern-profile` counter advanced 28 to 56 over 18.27 seconds.
Sampling perturbs scheduling, and these percentages are instruction-pointer
sample frequencies, not exact CPU-attribution percentages. Separate thread
CPU times showed that both busy threads consumed nearly one core each.

The decisive defect was ownership of interrupt status: the acknowledgement
poll cleared `PMC_INTR_0` and `PCRTC_INTR_0` independently of the timer thread
asserting and delivering vblank. It could erase a pending interrupt before
the guest ISR saw it. Removing the clear alone is insufficient: the guest
handler at `0x00231C90` writes PCRTC's W1C acknowledgement, then waits for the
master pending bit to clear. Plain memory turns that acknowledgement into a
set, not a clear. Logging/scheduling changed the race window, explaining why
wall-time-only comparisons were misleading.

### Implemented behavior

- Cache the pattern trace option once on the GPU-service thread.
- On Windows x64, back the NV2A aperture with two views of one mapping.
  Keep the guest PCRTC page read-only; a narrow MOV-store exception handler
  updates its writable device alias without temporarily unprotecting the
  guest page. Guest reads remain direct.
- Model PCRTC pending writes as write-one-to-clear, and derive its master
  pending bit from pending AND enabled. Device vblank assertion uses the
  alias, rather than going through the guest W1C store path.
- Exclude source-owned PCRTC and PGRAPH master bits from legacy polling;
  use atomic masked acknowledgement for the remaining bits. No game state,
  UI time step, or timer cadence was modified.

Register semantics were checked against the local xemu reference's
`hw/xbox/nv2a/pcrtc.c`. This is not a complete NV2A register implementation.
Unknown store instructions fail visibly rather than being skipped. Other
hosts, or an aperture setup failure, retain an explicitly logged legacy
fallback; this Windows fix has not been validated on other hosts.

### Controlled verification

| Run | Equivalent milestone |
| --- | --- |
| Earlier `legal-ui-time` | Queue index 10 at 210.87 s; `logo.vid` opened |
| `pcrtc-owned` | Queue index 10 at 5.078 s; `logo.vid` opened |
| `pcrtc-owned-profile` | Queue index 10 observed at 4.618 s; no recorded crash through 8.54 s |
| Final Release `pcrtc-final` | Queue index 10 at 5.085 s; `logo.vid` opened |

The post-fix profile's frame count advanced 20 to 163 between 0.505 and
4.100 wall seconds (about 39.8 Hz); UI time advanced 180 to 3,060 ms.
This is a large improvement, **not proof of exact 60 Hz timing**. The
existing timer's coarse cadence and busy polling remain future work.
The follow-up was still at queue index 10 at its last sample; no rendered
movie or main menu is claimed. The gray logo/programmatic rendering issue
also remains separate. The final run's first eight framebuffer dumps show
early loading-ring frames, not a newly verified complete legal logo.

All runs were bounded and their owned processes stopped afterward. No
unresolved call or crash was recorded in the post-fix logs. These are
external snapshots, not atomic traces. Release builds pass; the new
synthetic PCRTC test passes 60,057 checks in both Release and Debug,
including real write-fault/W1C paths and repeated init/shutdown. All 132
compiler tests, 445 topology checks, and 289 fixed-transform grid cases
also pass. No generated game probes were added or remain. Existing dirty
changes are preserved; nothing committed or pushed. Private profiles and
frame evidence remain under ignored `dump/analysis`.

Next: follow decoding/presentation after the now-prompt movie request;
do not return to treating the legal queue wait as an unresolved deadlock.

## Natural legal-screen completion and movie request (2026-10-07, historical)

**The probe-free recomp now demonstrably advances past the legal-screen
wait without changing any game state or injecting a callback.** The previous
short-run index-7 boundary was not a deadlock in this tested build.

The `legal-ui-time` diagnostic was capped at 240 wall-clock seconds and
configured to stop its owned process as soon as the queue reached the next
milestone. External snapshots record:

| Wall time | Observed milestone |
| --- | --- |
| 15.09 s | 15 commands, queue index 7, completion flag 0 |
| 197.12 s | UI clock 3,240 ms; parent title frame 191; logo child frame 8 |
| 205.77 s | UI clock 3,420 ms; parent title frame 200 |
| 206.28 s | UI clock 3,460 ms; parent title frame 202 with play bit cleared |
| 206.29 s | Completion flag 1 while queue still at index 7 |
| 210.87 s | Queue index 10, completion flag cleared for the next wait |

The same run logs a successful open of `Data/Movies/logo/logo.vid`, consistent
with the index-9 callback `0x00016F30`. The collector then deliberately
terminates the process at its requested milestone (exit 1 from termination,
not a recorded game crash or watchdog expiration). No unresolved call or
crash was recorded. All diagnostic game/emulator processes are stopped.

This changes the next investigation: profile the very slow UI progression,
and follow actual video decoding/presentation after the successful movie
open. Opening the video is **not** proof of rendered intro movies or a menu.
The gray logo-area draw still requires its programmable rendering path.
Why the UI advances so slowly is not yet isolated; do not attribute all of
the cost to GPU rendering without a profile, or alter the script clock to
skip its waits. Earlier builds had independently proven compiler and stream
defects; this result does not invalidate those repairs.

Private evidence: `legal-ui-time-queue.json`, `legal-ui-time-timelines.json`,
`legal-ui-time-resources.json`, and `legal-ui-time.err.log`. These are external
snapshots, not atomic execution traces: observation times have sampling skew.
The exact `titl_ac` command text was captured in the original xemu comparison
below; the long probe-free recomp run proves the corresponding flag/queue
transition but does not itself log the command string or writer IP.

Release build, 132 compiler tests, 445 topology checks plus rectangle
coverage, and 289 fixed-transform grid cases pass. Temporary generated
probes are removed. Game data, Ghidra output and private logs remain ignored.
Existing uncommitted changes are preserved; nothing has been committed or pushed.

## Legal-screen rendering and startup wait investigation (2026-10-07)

The bounded `fixed-transform` run renders readable legal/copyright text from
the game's actual texture. The LOTR logo, movies, and main menu remain
unverified. A gray rectangle at the upper-left is still an incomplete
programmable draw, not evidence that the splash is fully rendered.

Two renderer defects were isolated without changing game states:

- NV2A primitive enums were shifted: mode 6 is a triangle strip, not a fan.
  Correct topology removes the notch in the gray four-vertex primitive.
  Synthetic tests cover 445 topology checks plus strip rectangle coverage.
- The legal-text quad uses fixed-function position transformation, with
  normalized XY, Z=0.1, a 576-by-448 composite transform, and viewport offset
  (32.53125, 16.53125). The previous screen-coordinate heuristic rejected it.
  The renderer now applies complete, unskinned affine fixed-function state,
  homogeneous division and the reference 1/16-pixel truncation. Synthetic
  tests cover 289 positions, matrix order, division and invalid inputs.
  This does not implement arbitrary perspective clipping or vertex programs.

The Release build and both synthetic renderer executables pass. The 75-second
run used optional draw diagnostics, not generated-code probes; it ended at
the watchdog (exit 3), without a recorded crash or unresolved call. A run
without the optional draw diagnostics has not yet reconfirmed this image.
Private evidence includes `fixed-transform-frame010.bmp`,
`fixed-transform.err.log`, and `fixed-transform-queue.json`.

The queue at `0x003153A0` still has 15 entries and stops at index 7. Entry 6
calls `0x00016F60` (legal-screen script request); entry 7 calls `0x0002DD10`,
which waits for the queue's first word to equal 1. That word remains 0 in the
sampled stalled state. The next objective is to identify the original writer
and compare its upstream trigger at this same startup milestone in xemu.
This wait is not explained merely by missing artwork. No completion flags,
front-end states or callbacks have been forced. Diagnostic processes are
stopped; no commit or push has been made.

### Exact legal-screen completion command (2026-10-07)

Two bounded original-game xemu comparisons reached `0x00016F60`, then
watched the completion word without changing it. In the second comparison,
`0x000B7B80` receives the literal name **`titl_ac`** and value **`1`** while
the title queue is at index 7. This spelling is observed, not a guessed
Ghidra symbol. The resulting write stops the watchpoint at `0x000B82E9`
(immediately after the write); the queue then clears the flag at index 8
and reaches `0x00016F30` at index 9. Private evidence:
`legal-xemu-watch.log` and `commands-xemu-watch.log`.

The targeted Ghidra/assembly trace is saved privately as
`ghidra-targeted/titl-ac.txt`:

1. `0x000B7B80` calls `0x000B8420` to resolve the four-character handler
   prefix (`titl`), then skips five characters (`titl_`) and dispatches the
   remaining property name through the handler's virtual method.
2. `0x000B8280` resolves the property descriptor. The descriptor observed in
   xemu at `0x00248DF8` contains name pointer `0x00254220` (`ac`), destination
   `0x003153A0`, and type 0 (integer). The remaining callback fields are zero.
3. Its integer arm at `0x000B82B6` parses the supplied string via `0x0007E14C`
   into a stack temporary. At `0x000B82E6`, `MOV [EBP],EAX` writes the parsed
   integer to the destination. The next IP is the observed `0x000B82E9`.
   Because the destination is indirect, a simple direct-xref search for
   `0x003153A0` misses this writer. Ghidra's inferred calling conventions also
   make the decompiled stack temporary misleading; the assembly and original
   watchpoint are the controlling evidence.
4. `0x0002DD10` returns 2 when that word equals 1, allowing the queue to advance.

Temporary recomp probes demonstrate that the same integer setter successfully
parses `1` and writes 1 during the **earlier** five-command startup phase.
That is not legal-screen completion. After the legal request the measured
recomp runs reach count 15/index 7 but never issue the later `titl_ac` command.
Thus the setter itself is not presently the demonstrated failing boundary.
Private evidence: `legal-setter`, `legal-commands`, `legal-native`, and
`legal-load` logs/queue snapshots (25--40 second watchdog-bounded runs).

The legal-screen script invokes native operation `0x000A4A50`, followed at
index 7 by `0x000A50E0`, whose string argument is **`logo_ntsc_eng.swf`**.
The latter follows the UI movie/resource-request path toward `0x00216860`.
This is distinct from the later `logo` video request at `0x00016F30`.
The user identifies the gray area as likely the LOTR logo above the legal
text. Its placement and this UI resource name support that interpretation,
but a direct match of that draw's texture to the logo remains unverified.

The next narrow comparison is loading/activation and timeline advancement of
`logo_ntsc_eng`, including the script operation that emits `titl_ac`. Do not
infer a timer defect or failed resource load solely from the absent callback.
Attempts to extend the original comparison to every native script operation
failed to establish a debugger connection; they provide no additional guest
evidence. Their owned emulator processes were stopped, not left paused.
No completion flag or callback was forced.

### Probe-free resource and timeline snapshots

The subsequent 60-second `legal-clean` run used only external read-only memory
sampling and framebuffer capture. Readable legal text is reconfirmed without
draw tracing or generated probes (`legal-clean-frame010.bmp`). Both
`title_screen` and `logo_ntsc_eng` appear in the UI resource registry at state 4,
the state reached after the state-3 processing branch in `0x00216BE0`.
Queue index remains 7. Thus the logo UI request is not simply absent or stuck
in its initial loading state. State 4 alone does not prove every later
binding, animation action or script has executed correctly.

The 40-second `legal-timelines` run walks the live UI clip hierarchy externally.
The logo clip is matched by its definition pointer to the ready
`logo_ntsc_eng` resource. It advances to zero-based frame 8 of 50, and its
play bit (`0x02000000` at backing-object +0x14) clears. The parent title
timeline continues advancing. The UI clock at `0x00310514` reaches only
1,420 ms after 39.8 seconds of wall time. A stopped logo clip is therefore
not proof of a stopped UI update loop or a timer deadlock; it may be an
intentional pause while the parent runs. A longer, milestone-bounded
probe-free comparison is required before treating equal-duration runs as
equivalent startup progress.

The Release rebuild after probe removal and all 132 compiler tests pass.
The synthetic topology and fixed-transform executables also pass again.

## Stream completion and script formatter repairs (2026-10-04)

Two additional defects are now directly demonstrated; neither requires
forcing a resource gate, front-end state, or splash callback.

### Duplicate stream completion

A private fixed-size, append-only native trace buffer records small milestones
without printing on every hit. An external collector samples it without
suspending the guest. Sequence numbers describe event order; collector times
are observation times, not precise event timestamps. The generated probes
are temporary and are removed by full regeneration after testing.

The baseline `buffered-io` trace contains 35 stream submissions at `0x001CED02`
but **70** calls to completion `0x00100E00`. In particular, sequence 73 marks
chapter offset `0x10000` ready using old GlobScen buffer contents, before that
read starts at sequence 75. A less-instrumented `buffered-startup` trace actually
parses that stale block. This is evidence of premature ownership transfer,
not simply a slow loader or missing GPU draw.

The game has two completion paths: `0x000DAFD0` invokes completion inline if
XAPI ReadFile succeeds immediately, while worker `0x000DB510` waits on its
event and invokes completion after GetOverlappedResult. The bridge completed
the host read synchronously, returned success, and signaled the event,
selecting both paths. The duplicate callback can find the *next* current
stream node at `[0x00291210]` and publish it before its read.

A bounded original-game xemu breakpoint at `0x0003377A`, immediately after
NtReadFile returns inside XAPI ReadFile, measured **STATUS_PENDING (`0x103`)**
for a 65,536-byte stream read. Private evidence: `xemu-read-status.log`.

The shared bridge now retains the guest asynchronous open mode per handle
(including duplicates). Successful event-based, non-APC reads on those
handles return pending; the guest IOSB retains final success/byte count and
is written before the event is signaled. Synchronous opens, eventless reads,
errors, and the existing APC path are unchanged. This is a bounded completion
model on a synchronous host backend, **not** a complete async-I/O scheduler.
Synthetic Windows thunk tests cover both open APIs, duplicate mode, data,
status, short reads, EOF, events, and stack cleanup.

With only this repair added, `buffered-pending` and `pending-crash-location`
each record **35 submissions, 35 completions, and 35 parsed blocks**. All
128-byte block-prefix fingerprints match the local dump at the expected
offset. All 11 fxpa UI resources are allocated, assembled, enqueued, dispatched,
and parsed successfully. The title package (type `0x61707866`, ID 10,
299,472-byte payload, header at chapter offset `0x93B34`) reaches that whole
chain, then `0x000B58F0` and script request `0x00216860` execute. Matching
prefixes prove those sampled bytes, not the entirety of every block.

### Narrow signed multiply corrupts the script formatter

The subsequent bounded run faults in `sub_000B5280`, called by
`sub_000AE2A0` from the `sub_000AA350` script-parser path. Its integer-to-text
loop contains **IMUL BL**. The compiler incorrectly emitted a full
EDX:EAX signed multiply instead of AL times signed BL into AX, clobbering the
division quotient retained in EDX. The loop can fail to terminate and write
far beyond its small stack buffer. This supplies a concrete corruption path
after script activation; it does not prove every earlier crash had this cause.

The lifter now handles byte and word one-operand IMUL at their actual widths,
preserving EDX for the byte form and upper register halves for the word form.
Three synthetic regression tests fail on the previous lowering and pass with
the repair; optimized execution covers 328,256 operand/alias/boundary cases.
The complete locally lifted formatter passes 30,003 comparisons with host
integer formatting, including INT_MIN/MAX, random values, stack balance,
preserved registers, and output-boundary checks. The existing full memmove
oracle still passes 65,792 cases. All 132 compiler unit tests pass.

Crash diagnostics now report ASLR-relative native addresses and bounded stack
candidates rather than filtering for a fixed image base. These are candidates,
not a native stack unwind. No unresolved-call repair or GPU change was needed
to identify this formatter defect.

The probe-free regenerated Release build succeeds. In `clean-pending-imul`,
the title queue changes from pointer/count zero and index 1000 to count 5,
index 1, then **count 15, index 7**. The user reports new gray geometry, also
present in saved `clean-pending-imul-frame014.bmp`: a flat polygon in the
upper-left of an otherwise black surface. This is demonstrated visual and
script-queue progress, **not** a verified LOTR splash or main menu.

The clean run reached its 150-second watchdog with no recorded crash or
unresolved call. It stopped with count 15/index 7, guest function `0x000DE290`,
and equal NV2A USER PUT/GET (`0x0002E5EC`). Process exit 3 is the watchdog
termination, not normal title shutdown. The external collector recorded zero
probe records because all generated probes had been removed. Both game and
xemu diagnostic processes are stopped; no relaunch is scheduled. Release
build, 132 compiler tests, both private routine oracles, and the synthetic
file-completion executable pass. The latter was run directly because CTest
is not installed in the bundled toolchain. The pre-existing `0x0017F840`
recursive-function build warning remains.

Later renderer reports include additional batches classified as having no
texture coordinates, while the only reported sampled texture remains the
128x128 loading-ring texture. This suggests a useful next comparison of
vertex attributes, texture-stage setup, transforms, and the responsible title
command at the equivalent xemu milestone. It does not establish that every
such batch requires a texture or that the remaining issue is exclusively GPU.
Splash, movies and main menu remain **unverified**. The
historical stalled-run conclusions below must not be mistaken for the latest
measured boundary. Private traces, maps, Ghidra output, and generated game code
remain ignored. No commit or push has been made.

## Rendering review and compiler repairs (2026-10-04)

The missing splash is **not yet established as a GPU rendering defect**.
The ring produces real framebuffer pixels, but the title script queue remains
empty in the measured stalled runs. Do not force front-end states or inject
the splash callback to conceal missing startup work.

This review corrects an earlier negative trace: the recomp **does enter**
`sub_000B12D0`, `sub_000B7ED0`, `sub_000B6330`, and `sub_00216ED0`.
Fresh flushed probes in `flags-baseline.err.log`, `wrapper-baseline.err.log`,
and `resource-count.err.log` demonstrate these calls. The previous absence of
driver-entry messages is not reliable evidence of a missing edge.

At `0x00216F09`, the recomp's list at `[0x00310518]` had count zero in all
12 sampled calls. At `0x00217172`, the saved count was zero and the pending
command range was empty, so the original branch skipped `sub_000A2990`.
An xemu breakpoint at the same first update found count one. A separate xemu
breakpoint at `sub_00216640` identified the inserted resource as `title_screen`,
state 4, called from return address `0x00216C97`.

Two concrete compiler defects were repaired in the shared tooling:

- SSE comparison followed by `LAHF` previously left AH unchanged. The lifter
  now transfers the comparison flags, including unordered/NaN, from saved
  operands while preserving the rest of EAX. The optimized execution test
  checks 2,560 combinations. Regeneration changes 530 such sites. A 120-second
  run with this repair alone still had an empty title queue and only the ring;
  it is a correctness fix, not by itself a demonstrated rendering solution.
- The CRT memory-copy routine at `0x0007E190` contains indexed branch tables
  with an unused slot zero and with negative indices. Forward-only discovery
  missed its alignment arms (`0x0007E200`, `0x0007E250`, etc.) and backward-copy
  arms (`0x0007E38C`, etc.). The generated routine tail-dispatched to unresolved
  addresses and failed to complete copies/restore its stack. Two diagnostic
  runs logged those unresolved targets and subsequently faulted. CFG recovery
  now follows direct branches around inline data, discovers contiguous local
  table targets on either side of the base, and reclaims explicitly targeted
  weak seeds. The previously added seed at `0x0007E434` is one such internal
  tail, not an independent callable routine. Known independent function
  boundaries remain barriers.

The full repaired copy routine passed 65,792 optimized native oracle cases
against host `memmove`: lengths 0..256, source/destination alignment, both
overlap directions, identical pointers, return value, preserved registers,
direction flag, and guest stack balance. This private test reads the user's
XBE locally; its generated code and input are not distributable repository
artifacts. Public regression tests use synthetic instruction fixtures only.

All 129 available unittest-based compiler tests passed, plus the standalone
intra-function indirect-jump and FPU-branch checks. Release compilation passed
with the pre-existing recursive-function warning for `sub_0017F840`.
The 120-second combined-fix run (`copy-fixed.err.log`) had no unresolved-call
messages or recorded crash, but still ended with title queue pointer/count
zero and index 1000. Thus the copy repair removes a verified corruption path;
it does **not yet establish a fix for the missing splash**. The resource
producer/completion path remains the next investigation boundary.

The subsequent 65-second probes narrow that boundary further. In
`pending-fixed.err.log` and `request-fixed.err.log`, the first eight updates
all had both completed count zero and pending-list head zero. No entry probe
fired in `sub_00216860` (request/lookup) during the latter run. This is not
evidence of a pending disk operation failing to complete: no job existed in
the sampled list. Xemu's first `sub_00216530` call came from `0x00216963` in
`sub_00216860`, with the string object containing `title_screen`. Its stack
also contained the outer request return address `0x000B5925`, in
`sub_000B58F0`. Compare the producer of that original request and the early
script/VM path before modifying asynchronous I/O or GPU presentation.

The last captured combined-fix framebuffer was black after the ring. The
temporary entry/count probes are removed for handoff; the shared compiler
repairs and their synthetic tests remain local and uncommitted.

The two crashing diagnostic runs (`resource-producer.err.log` and
`resource-producer2.err.log`) did not reach the new resource probes. Their
absence of resource messages must not be treated as further queue evidence.
All logs, framebuffer captures, emulator configuration and private test inputs
remain in ignored `dump/analysis`. No changes have been pushed.

## Original-game comparison in xemu

### Targeted Ghidra and package-delivery review (2026-10-04)

The local Ghidra review follows the resource producer, not a speculative GPU
patch. The original title package takes this path:

`0x001FC2F0` (consume parsed resources) -> `0x00184160` -> `0x00181770`
-> `0x000E6F40` (dispatch by resource type) -> `0x000B31D0`
-> `0x000B2E20` -> `0x000B2600` -> `0x000B58F0` -> `0x00216860`.

Xemu's `0x000B31D0` breakpoint receives a resource with type `0x61707866`
(`fxpa` in memory), ID 10 and payload length 299,472. The payload contains
`title_screen`. Ghidra confirms that `0x000B2600` parses the UI package and
then requests its script resource; it is not a GPU draw routine. Its generated
request gates match the inspected original instructions. No gate was forced.

A private structural scan locates this exact type/ID/length header in
`Data/Game/e98c/e98c03.scx` at file offset `0x00093B34`. It lies in the
64-KiB block starting at `0x00090000`. The scan finds 42 resource headers in
`GlobScen.scx` and 354 in `e98c03.scx`; header presence alone does not prove
that the runtime assembles, accepts, or dispatches the payload correctly.

The relevant earlier stages are `0x001F4A20` (consume stream packets),
`0x00189300` (header filters/allocation), and `0x000E4500` (enqueue an assembled
resource). Header selection includes mode flags, `0x00130CA0`, and an optional
expression check; changing any of these without an original/recomp mismatch
would hide the defect rather than fix it.

The 65-second `package-dispatch` run did enter `0x000E6F40` for several startup
resource types, but not `fxpa`. Its delivered `atbl` resources stopped at ID 6,
whereas the stepped xemu sample included IDs 1 through 18. However, a later
65-second `header-gates` run delivered all 18 and continued into the chapter
package. Its watchdog interrupted active parsing at chapter block `0x80000`,
before the title header's block. Thus absent callbacks in a fixed-duration
probe do **not** establish a permanent missing edge. Logging affects progress,
and the observed resource coverage varies between runs.

The completion-ring samples in `package-list` and `header-gates` showed empty
destination slots at the observed writes, not an observed unread-slot overwrite.
This does not rule out concurrency defects elsewhere. The next decisive check
was whether the title header reaches allocation, assembled-resource enqueue,
and type dispatch in that order. Earlier statements that streaming has finished
must not be generalized to every bounded run merely because file reads succeed.

The longer `header-long` run answered that check: resource type `0x61707866`,
ID 10, length 299,472 passed the header filter, allocated, reached type dispatch,
and returned parse-success from `0x000B2600` in first package slot zero. Ten
additional UI packages also parsed successfully. No gate was forced; these were
temporary logging probes. This disproves a permanently missing title-package
delivery edge in that build, but is not visual proof that the splash rendered.

Later in the same run, indirect calls to `0x000DB620` failed three times before
a native access violation. Ghidra confirms a standalone stream-service callback,
and original code at `0x000DB7C3` stores its address at object offset `+0x78`.
The old generated code included its instructions inside the preceding function
but did not expose its entry in dispatch. Added the runtime-confirmed entry to
`config/seed_functions.json`. The crash's causal relationship to those missed
calls remains unproven; validate callback dispatch and the downstream title
queue after rebuilding rather than claiming a rendering fix.

Regeneration now emits `sub_000DB620` independently and includes its dispatch
entry. It completed 14,088 translations with zero failures (one manual exclusion).
The clean Release build passed; all temporary generated-code probes were removed.
The 150-second `callback-verified` run recorded no unresolved-call messages or
crash, but still ended in `0x000DE290`, with title queue pointer/count zero and
index 1000. Its last captured draw surface was black. This is not evidence that
the repaired callback was exercised: the clean run did not demonstrate the same
later startup progress as the instrumented run. The logging-sensitive difference
makes stream scheduling/buffer ownership a useful next controlled comparison,
not a proven cause or justification for bypassing resource gates.

All 129 unittest-based compiler checks passed during this review, and the
regenerated memory-copy routine again passed 65,792 native oracle cases. The
pre-existing recursive-function compiler warning at `0x0017F840` remains.
Diagnostic processes were stopped, and no changes were committed or pushed.

Ghidra projects, mapped executable images, decompilation, packet scans and
debugger logs remain under ignored `dump/analysis`. None are public source.

The private XISO boots in xemu 0.8.136 with the user's locally staged boot
files. A visible, snapshot-mode run reached the copyright splash and then the
fully rendered main menu (New Game / Load Game / More). No input was needed.
The emulator was closed after the test. The boot files, disc image, and local
debugger probe remain under ignored `dump/analysis`; none belong in Git.

The user clarified the visual order: the recomp's loading ring appears after
the Xbox boot and **before** the Lord of the Rings splash. The xemu state sample
below was taken **at the later menu**, not at the matching post-ring moment.
Equal state numbers and flags across those samples do not establish equal
progress through startup. The missing output is first the splash, then menu.

At the visible menu, xemu's guest GDB stub reported manager state
`[0x0032DCF0] = 2` and active/resource flag `[0x0032DD50] = 1`.
Breakpoint `0x0015ECB0` fired with stack argument 0 (`event 0`); the return
address was `0x0013472F`, consistent with the frame-loop caller. Thus state 2
receiving event 0 is also normal at an already visible menu. The earlier
conclusion that a missing event 1 alone explains the black screen was too
strong. Event 1 may mediate another transition, but it is not required for the
menu image to appear in this observed run. Compare resource-manager outputs
and render submissions between original and recomp at matching points,
rather than forcing event 1.

A subsequent 90-second recomp run (`RECOMP_PEEK`, `RECOMP_FB_TRACE`, and the
watchdog; private log `dump/analysis/recomp-menu-compare.err.log`) measured
current/requested state `2/2` and the same `+0x88` flag value `1`. Thus this
flag alone does not distinguish post-ring from menu. The recomp submitted only eight draw
batches in its latest reported frame, seven sampling one 128x128 DXT texture,
and latched about 1,400 non-black pixels in the loading ring. At the watchdog,
NV2A USER PUT equalled GET, so no GPU work was queued. The likely gap is
upstream of presentation: post-ring splash/menu objects or draw commands were
not submitted. This is an inference, not yet a proven cause. Compare the
original and recomp at the **same visual phase**, then trace the first missing
resource or frame command producer.

The analogous xboxrecomp `DRAW_ARRAYS` bug is already fixed in this checkout:
`NV097_DRAW_ARRAYS` expands each submitted run into indices before the raster
batch is emitted. The eight ring batches prove that path can produce pixels;
there is no evidence yet that later splash/menu geometry is being silently
dropped by this specific missing method.

An earlier headless xemu test with `-display none` stayed at zeroed manager
fields for 55 seconds; the visible test demonstrates that this headless result
is not a reliable reference for game progression.

The dump contains `Data/Movies/logo/logo.vid`, and the XBE names `ShowLogo`,
`ShowLegalScreen`, and `ShowTitleScreen` script callbacks. There are duplicate
legal/title callback implementations in the XBE. A hardware breakpoint on the
**low-address** `sub_00016F60` (`ShowLegalScreen`) hit in xemu during startup,
while state was still 2. Its return address `0x000B85B7` identifies the
script-command executor `sub_000B8590`; that executor is called by
`sub_000B9290` (vtable adapter `sub_0002DCC0`). Breakpoints on the alternate
high-address callbacks and the `Data/Movies/%s/%s` path builder did not hit
during the same bounded boot. Do not assume a video-decoder failure merely
because `logo.vid` exists.

Temporary entry probes in the recomp confirmed it never enters
`sub_00016F60`, `sub_00016F80`, or even `sub_000B8590` during 55-75 second
bounded runs. The private logs are `dump/analysis/splash-probe.err.log`,
`scriptq-probe.err.log`, and `scriptq-entry.err.log`. The earlier file trace
reached `LoadOnce.scx`, `GlobScen.scx`, and `e98c03.scx`/`.sas`, but no movie.
The missing legal screen is therefore upstream of rendering and upstream of
script-command execution. Determine why title activation is not scheduled;
do not inject the legal callback or force the state number.
All temporary generated-code probes were removed and the clean executable
rebuilt after testing.

At original legal-screen dispatch, `ESI = 0x003153A0`, the script queue object:
its `+4` list pointer was `0x00D5B688`, `+8` count was 15, and `+0x10` current
index was 6. A 55-second recomp peek at the same static address instead found
list pointer 0, count 0, and `+0x10 = 1000` (private log
`dump/analysis/scriptq-memory.err.log`). This is the strongest divergence so
far: the legal command list does not exist in the recomp at the sampled time.
The queue is embedded at `+0x1A0` in the title object at `0x00315200`.
`sub_001E1AE0` constructs that object and initializes the empty queue,
including `+0x10 = 1000`. Thus the recomp state is consistent with construction
having happened but activation not having happened; it is not evidence that
the object is uninitialized. An xemu write-watchpoint showed the original
queue list pointer first become nonzero at `0x0002DFEC` and count first become
one at `0x000B9631`. These are reached through `sub_000B95B0` from the
title object's vtable callback `sub_0020DB30`. A breakpoint at that callback
hit with `ECX = 0x00315200` and the queue still empty. Its return address
`0x00016FDC` identifies dispatcher `sub_00016FD0`, which invokes vtable slot
`+0x28`; that dispatcher's return address `0x000B83F1` identifies the script
scheduler's indirect callback call in `sub_000B8280`/`sub_000B835B`.
Next compare whether the recomp reaches each of those two scheduler functions,
the indirect target `0x00016FD0`, and the title vtable target `0x0020DB30`.
The first absent edge is the actionable divergence. Copying a late xemu heap
pointer or directly calling the legal callback is not a valid fix.

The user's observed original boot order is: Xbox boot, loading ring, LOTR
splash, EA logo, THX, New Line Cinema logo, then main menu. The recomp currently
stops after the ring, so the **LOTR splash** is the first missing milestone.
Do not treat this first missing visual milestone as the first execution
divergence: compare startup from immediately after Xbox boot, including the
ring, resource loading, scheduler registration, and transition into the splash.

A temporary 55-second recomp trace at the scheduler's indirect dispatch,
`sub_00016FD0`, and `sub_0020DB30` logged no hits. A second, widened 40-second
trace also logged no entry into `sub_000B8280` itself. Both runs loaded
`LoadOnce.scx`, `GlobScen.scx`, and `e98c03.scx`/`.sas`. Private logs:
`dump/analysis/title-edge-20261003.err.log` and
`dump/analysis/scheduler-wide-20261003.err.log`. The generated-code probes were
removed afterward. Thus the next comparison is **upstream of the scheduler
entry**, not merely at its final callback. Both xemu-observed indirect targets
(`0x00016FD0`, `0x0020DB30`) already exist in the recomp dispatch table; a
missing compiled target alone does not explain this trace. Compare early
registration/call sites and object state before assuming a kernel timing bug.

## Early-boot execution comparison (2026-10-03)

The xemu breakpoint/return-address chain before the first splash is:

`sub_000B6330` (resource driver) -> `sub_00216ED0` (resource update,
return `0x000B63B7`) -> `sub_000A2990` (queued-command processing,
return `0x002171A7`) -> `sub_000AA350` (parser, return `0x000A2A03`)
-> global handler `[0x00310558] = sub_000B7B80` (return `0x000AA68E`)
-> `sub_000B8280` (scheduler, return `0x000B7BCB`) ->
`sub_00016FD0` -> `sub_0020DB30` -> legal/LOTR splash command.

In bounded recomp runs, the script handler registration at `sub_000B7D40`
did occur, but probes saw no entry into `sub_000B6330`, `sub_00216ED0`,
`sub_000A2990`, `sub_000AA350`, or `sub_000B7B80` before the watchdog.
Private logs: `boot-edge-20261003.err.log`, `parser-edge-20261003.err.log`,
`queue-edge-20261003.err.log`, and `driver-edge-long-20261003.err.log` under
`dump/analysis`. A shorter 35-second run stopped earlier in boot and is not
evidence of a missing edge. The then-inferred boundary was **handler
registered, resource-driver entry not observed** in the longer run; the
2026-10-04 review above disproves that inference. The following describes the
historical investigation, not the current known boundary. Next
trace who invokes `sub_000B6330` (including its wrappers at `0x000B7Fxx`),
and compare the triggering resource/worker state at matching boot phases.
Static callers include `sub_000B7ED0`, which calls the driver according to
mode `[0x00329C7C]` (with a fixed `0x14` tick when mode is zero); this routine
is called by `sub_000B1371`'s parent function. The alternate
`sub_000B7F90` path is called by the script scheduler around `0x000B91xx`.
Check whether `sub_000B7ED0` is entered and what `[0x00329C7C]` contains
before changing driver or kernel behavior.
Do not infer a kernel scheduling bug until that caller and its inputs differ.
All temporary generated-code probes were removed after testing.

For a second Xbox title, reuse the method rather than these game VAs:
establish a visible milestone order in xemu; breakpoint the earliest missed
game callback; walk return addresses backward to the first job/queue producer;
probe the same functions in the recomp with bounded runs; compare queue
registration, pending work, and completion state before changing a shared
runtime service. This separates a title-data issue from a runtime issue.

The visible loading ring now renders. After it disappears, the front-end is
still active, but no later image appears. The manager object is at guest VA
`0x0032DCC8` (derived vtable `0x002560A0`). Its current state is at `+0x28`,
requested state at `+0x2C`, and the active/resource flag at `+0x88`.

The normal boot trace reaches state 0, requests state 2, and repeatedly sends
event 0 to state 2 via `sub_001346C0` -> vtable slot `+0x60`
(`sub_0015ECB0`). State 2's handler `sub_000CDC20` requests state 3 when it
receives event 1. The observed frame loop never supplied that event.

A **temporary diagnostic build** converted one state-2 event 0 into event 1.
The manager requested state 3 and committed the transition. State 3 then
continued to receive event 0. Its handler `sub_000CDBC0` checks `+0x88` and,
when no task is active, queries the resource manager at `0x00328978`, writing
the result to manager `+0xB0`. A nonzero result requests state 5. Event 2
requests state 2. This run did not advance beyond state 3 within 70 seconds.
The forced event and all tracing were removed by regenerating source after the
run. The diagnostic log is private and excluded from Git:
`build/diag-20260930-213250.err.log`.

`sub_0015EC70` is an external event adapter: it reads event and argument fields
at message offsets `+8` and `+0xC`, calls the manager's slot `+0x60`, and writes
the dispatch result to an optional output pointer at message `+0x10`. It did
not appear in the successful state-2 trace. Static data at `0x0026F0B4` maps
IDs `0xDAC` through `0xE0F` to this adapter. The lookup routine is
`sub_000E8E70`; a second caller at `0x00189924` looks up an object's first
word and invokes the mapped callback with that object. This is a range-based
object callback table, not a direct event registration for the front-end.

A separate fan-out at `sub_000E8510` walks 20 `(event ID, callback)` pairs at
`0x0026F0D8` and invokes callbacks whose ID matches the message field `+8`
(or whose ID is `0xFFFFFFFF`). The table has no direct entry for
`sub_0015EC70`. The next investigation should trace the producer expected to
emit state-2 event 1, including this fan-out's callers and the object callback
path. Trace resource-manager slot 0 used by state 3 and the resulting `+0xB0`
value. Keep experimental changes out of generated sources in commits.

More specifically, event 1 enters `sub_0015ECB0`, invokes manager vtable
`+0xA4` (`sub_000EAEA0`, setting flag `+0x12C4`), then reaches the current
state handler through vtable `+0x68` (`sub_0001F590`). Event 0 takes the same
state-handler path without that extra action. A nested resource callback
`sub_001EAB00` can send event `0x12` to the manager, but `0x12` maps to the
dispatcher no-op branch; its later object-ID `0xDAC` callback is a distinct
path. Thus this callback is not yet evidence of the missing event 1. The
next live trace should instrument the source of event 1, not force the state
handler directly.

The game scene files `Data/Game/e98c/e98c03.scx` and `.sas` exist in the local
dump; the private dump must not be committed. Game runs for investigation
should use a hidden window and a watchdog. Closing a user-visible window must
not trigger any automatic relaunch.
