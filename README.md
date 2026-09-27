# The Lord of the Rings: The Third Age — static recompilation

Clean project scaffolding for a native Windows recompilation of the North
American original-Xbox release (`EA-095`, title ID `4541005F`, version 8).

This repository does not contain the game executable, disc image, or assets.
Supply files from a legally owned copy under `dump/`; that directory is ignored
by Git.

## Verified input

The current reference disc matches Redump metadata:

- Size: `7,825,162,240` bytes
- MD5: `57e3789289a89c860067d3c770e61807`
- SHA-1: `bc97495b5702b11c4ae2c0e53d47ab1844dd3e4b`

The extracted `default.xbe` has SHA-256
`a45ca85284a12b86877ebe37e9e86741f166207bfc5a4355df990fa341a2485d`.

## Initial XBE profile

- Build: XDK 5849
- Entry point: `0x00035326`
- `.text`: `0x20B30C` bytes
- Functions detected: 13,816
- Kernel imports: 117
- Demand-loaded sections: `DOLBY`, `$$XTINFO`, `$$XTIMAGE`, `$$XSIMAGE`, `.XTLID`
- Linked Xbox libraries: XAPILIB, D3DX8, DSOUND, XBOXKRNL, LIBCMT,
  D3D8LTCG, XGRAPHCL

## Layout

- `src/` — game-specific host and manual recompilation overrides
- `vendor/xboxrecomp/` — pinned upstream toolkit submodule
- `dump/` — ignored local executable/assets and generated analysis
- `.tools/` — ignored local utilities

Generated recompilation sources will live under `src/recomp/` once the full
analysis pipeline is run.

