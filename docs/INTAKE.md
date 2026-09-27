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

The executable contains explicit D3D, D3DX, DSOUND, XGRPH, and XPP code
sections. The `DOLBY` section is demand-loaded and must be included in later
analysis rather than treated as ordinary data.

## Immediate risks

1. Correct handling of `XeLoadSection`/`XeUnloadSection`.
2. Dolby and DirectSound/APU behavior.
3. Indirect calls from C++ vtables and Havok/engine callback tables.
4. Accurate x87 state across Havok and game logic.
5. The custom `.sas`/`.scx` streaming containers and `.vid` movie format.

