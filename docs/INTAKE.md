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

