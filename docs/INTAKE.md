# Intake notes

## Disc filesystem

The verified disc contains 146 files totaling 4,069,003,712 bytes. Its root is
limited to `default.xbe` and `data/`.

Important data groups:

- `data/loadonce.scx`
- `data/game/globscen.sas` (751,861,760 bytes)
- `data/game/globscen.scx` (655,360 bytes)
- chapter pairs under `e01c`, `e02c`, `e03c`, and `e98c`
- 124 `.vid` movie files organized by chapter

The Xbox build uses `.scx`, not the `.scp`/`.scg` extensions documented for
the PS2 and GameCube builds. The `.sas` naming is shared.

## Static-analysis baseline

- 739,103 instructions in the initial linear sweep
- 13,816 detected functions
- 130,730 cross-references
- 2,802 strings
- 305 embedded jump tables resynchronized
- 597,279 instructions (80.8%) reachable in recursive validation
- 41 addresses installed in indirect-call slots
- 1,250 function addresses recovered from data tables

The first library-identification pass found no RenderWare strings or recognized
RenderWare functions. Current evidence therefore favors EA/Hypnos's custom
engine over the earlier provisional RenderWare classification. It found 893
validated C++ vtables, 8,785 virtual methods, and 1,029 functions inferred as
`thiscall`.

The executable contains explicit D3D, D3DX, DSOUND, XGRPH, and XPP code
sections. The `DOLBY` section is demand-loaded and must be included in later
analysis rather than treated as ordinary data.

## Immediate risks

1. Correct handling of `XeLoadSection`/`XeUnloadSection`.
2. Dolby and DirectSound/APU behavior.
3. Indirect calls from C++ vtables and Havok/engine callback tables.
4. Accurate x87 state across Havok and game logic.
5. The custom `.sas`/`.scx` streaming containers and `.vid` movie format.

## First translated build

The initial whole-program pass translated all 13,619 detected functions into
14 generated C chunks and produced a working 64-bit Windows executable. The
first instrumented run mapped all 13 XBE sections, initialized the 64 MiB guest
address space, resolved all 117 kernel imports used by this XBE, entered title
startup, and exercised save/profile and demand-loaded section paths.

The first confirmed coverage gap is an indirect-call target at `0x0007E434`.
Static vtable analysis had identified it as a thunk, but it was absent from the
base function set and therefore from generated dispatch. Runtime indirect-call
feedback validated it as executable code. It begins one byte into a bad
linear-sweep decode after an embedded jump table, so the disassembler now
permits a validated seed to correct that narrowly defined one-byte phase drift.

After reseeding, the analysis contains 14,086 translated functions and the
static unresolved-call set fell from 351 to 131. The regenerated executable
has a dispatch entry for `0x0007E434` and again reaches title filesystem and
profile initialization. The next task is to capture the earliest remaining
valid indirect target before later bad state produces noisy, code-like values.

## First graphics bring-up

Direct `Partition1\\TDATA` and `Partition1\\UDATA` paths now route to the
writable title/user save trees rather than the extracted disc directory. The
cache formatter's volume lock, unlock, and dismount controls complete as safe
no-ops for host backing files. With those fixes the title advances through
cache setup into its statically linked D3D code, submits an NV2A push buffer,
and executes more than 3,200 indirect calls without an unresolved target.

Push-buffer execution and the diagnostic framebuffer presenter are enabled by
default for this project. A normal launch now creates the 640x480 `Xbox Recomp
- Framebuffer` window. It is currently black, so the active blocker is
framebuffer/surface discovery or unsupported push-buffer methods rather than
window creation or title startup.

## First vblank delivery

The initial push buffer clears one surface to black, selects a 640x480 surface
at physical `0x00230000`, and stops with DMA PUT and GET both at `0x1B44`.
The title installs its NV2A interrupt on vector 3 and expects PCRTC vblank
delivery after that first flip. `RECOMP_VBLANK` is therefore enabled by
default for this project alongside push-buffer execution and presentation.

The runtime now raises PCRTC and PMC status before calling the ISR. Tracing
confirms that the title first declines an early interrupt and then claims
subsequent vblanks, queuing D3D's DPC object at `0x0023813C` with routine
`0x00231A30`. Deferred-call draining was also corrected to process a snapshot
of the queue: a DPC queued by another DPC runs on the next scheduler pass,
instead of allowing self-requeueing work to monopolize the timer thread.

This removes the missing-frame-clock failure but does not yet produce a second
push buffer. The verified boundary remains DMA `0x1B44`, with one black clear,
zero draws, and no unresolved indirect call. The next analysis target is the
guest D3D synchronization path around `0x0022B7E0`/`0x0022B9B0`; Ghidra is
available at `C:\utilities` for that pass.

## Scene-streaming boundary

Later bring-up work advanced beyond that first-buffer boundary. The title now
renders its One Ring loading overlay, opens `GlobScen.scx`, then opens
`e98c/e98c03.scx` and its companion `.sas`. File tracing confirms successful,
ordered 64 KiB reads from the chapter `.scx`; the observed run advanced beyond
offset `0xC0000` without an I/O failure or unresolved indirect call.

No chapter geometry is submitted during this interval. The NV2A USER PUT and
GET pointers remain equal, so the current blocker is not a full or stalled GPU
queue. The loader worker is sleeping in its normal event wait between chunks,
while the main thread continues the loading/update path. The immediate target
is therefore the producer/consumer handoff that schedules subsequent scene
chunks and eventually changes game state, not additional shader translation.

The stream handoff also exposed two runtime lifetime gaps which are now fixed.
XDK libraries can initialize embedded `KEVENT` objects directly rather than
calling the exported kernel initializer, so the bridge now creates a matching
host event on first use. Closed guest handles retained by an Xbox file object
are no longer expired on a wall-clock timer, and sharing-conflict cleanup is
limited to retired handles for the path being reopened. A verification run
read the chapter stream continuously through offset `0x180000` without the
title's false dirty-or-damaged-disc error.

A subsequent long run exposed a second host-concurrency mismatch in the
title's async completion queue. The original append routine assumes Xbox's
single guest CPU; native worker threads could enqueue the same node twice and
form a one-node cycle, trapping the main thread in an unbounded list walk at
`0x000E4540`. That routine now has a title-specific manual implementation
which rejects duplicate nodes and repairs the observed self-cycle. Regenerated
direct call sites route through the override. The infinite walk disappeared
and verified chapter reads advanced through offset `0x1B0000`.

Path-attributed I/O tracing (`RECOMP_FILE_TRACE_PATHS=1`, together with
`RECOMP_FILE_TRACE=1`) confirmed that the remaining pause is not another disc
or path failure. `globscen.scx` is read completely, then valid selective 64 KiB
reads begin in `e98c03.scx`. A state-gate trace then followed all three
zero-based scene sections (`0/3`, `1/3`, and `2/3`) through the title's
four-slot handoff ring. At the pause the final section reports complete, the
ring and parsed-object queue are drained, and there are no failed reads. The
scene package has therefore finished streaming and parsing. The next bring-up
target was post-load scene activation and render submission, not file I/O or
an additional scene packet.

The activation trace subsequently confirmed real renderer output: 200 textured
batches, 400 rasterised triangles, and roughly 26.7 million pixel writes. The
remaining black framebuffer was a scanout-selection bug. The title selects and
clears its next backbuffer before `FLIP_STALL`, while the runtime window was
following that newly cleared surface. The NV2A executor now switches the
framebuffer window to `drawn_offset` at the flip, matching the completed buffer
hardware would scan out.

`RECOMP_GUEST_SAMPLE=<delay>,<duration>` enables the runtime's non-terminating
guest-function sampler. It samples the main guest thread and registered worker
threads, reports the hottest guest addresses after the requested wall-clock
window, and can be combined with `RECOMP_WATCHDOG_SECS` for a terminating stack
snapshot. This avoids mistaking a worker blocked in a host wait for a CPU-bound
guest loop.

