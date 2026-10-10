# Working-audio checkpoint — 2026-10-09

User-confirmed milestone: **audio is audible for the first time**, but laggy
and choppy. Preserve this local state before further audio changes.
This is a documented working-tree checkpoint, not a commit or Git tag.

## Verified state

- Release game build succeeds. APU monitor/IRQ/voice-backing regression suite
  passes **5,452 checks in both Release and Debug**.
- The monitor preserves guest audio and accumulates correctly sized host
  buffers without advancing the mixer faster than the generated sample rate.
- The APU publishes pending status and exposes a level-triggered interrupt
  source. The existing guest-stack timer thread delivers it to the registered
  vector-5 handler without holding the APU lock. Polling does not acknowledge
  the source; the game's original ISR services it.
- `KeSynchronizeExecution` and delivered ISRs share a per-vector host lock.
  This adds mutual exclusion, not complete Xbox IRQL/preemption semantics.
- Voice-table reads and writes now use an explicitly supplied contiguous bank.
  The bounded adapter applies only to voice-table records, not all physical
  memory. It checks bounds/alignment and never falls back from an invalid
  explicit-bank address into low RAM. Other DMA domains remain unchanged.
- In `audio-irq-backing-native`, CPU voice-table pointer `0x80498000` and the
  APU's masked-low table had different link words: the game removed voices in
  its actual bank while low RAM retained old links. This caused stale repeated
  idle notifications. The repaired run services interrupts, returns FECTL to
  running mode (`0x1F0F`), and continues producing nonzero movie-interval audio.
- Full bounded run `audio-irq-bank-full-native` reaches startup queue index 15
  at **38.329 seconds, UI 4020 ms** and is stopped at **40.340 seconds**.
  No crash or unresolved-call diagnostics occur in that run. Completed display
  copies include legal, movie logos and menu; the menu image was inspected and
  retains textured background, gold logo and menu text. All nine sampled
  display copies agreed across two reads, without an observer-held lock.

## Known remaining defect: choppy audio

The user reports audible lag/choppiness; do not label audio complete.
The already-running bounded `audio-queue-baseline-native` diagnostic was
allowed to finish at this checkpoint. At attempt 400 it records:

- No full-queue rejections (`full=0`).
- 138 observations of an empty device queue before submission (`empty=138`).
- 9,505 ms between first and 400th submission; largest inter-submit gap
  approximately 40,903 microseconds. A nominal 1024-sample, 48-kHz interval is
  approximately 21,333 microseconds.

These measurements support output starvation/pacing investigation; they do not
prove the sole cause of the audible defect. No pacing change was implemented.
The next controlled comparison should measure scheduler wake latency, actual
sample throughput and queue occupancy before changing buffer depth or timing.
Voice resampling is still simplified, GP/EP DSP execution remains stubbed,
and SGE/SSL/notifier/payload backing has not received this voice-table fix.
Audio fidelity and movie synchronization remain unverified.

## Guardrails and local artifacts

- No forced front-end gates, trap clears or new command acknowledgements.
- The pre-existing title DSP doorbell workaround remains; this checkpoint
  does not validate it as real DSP command execution.
- All owned test processes are stopped; no relaunch loop or scheduled launch.
- Private logs, captures, dump bytes, generated game code and analysis remain
  excluded from Git. No generated-code probes were added.
- Existing uncommitted changes are preserved. Nothing was committed or pushed.
- Preserve both the root working tree and dirty `vendor/xboxrecomp` checkout
  together; the runtime fixes live in that nested checkout. The existing root
  changes are broader than this checkpoint and must not be discarded.

See [front-end trace](FRONTEND_STATE_TRACE.md) for chronological evidence and
[startup comparison](STARTUP_COMPARISON.md) for the emulator timing caveats.
