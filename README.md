# The Lord of the Rings: The Third Age — Recomp

[![Status](https://img.shields.io/badge/status-early%20bring--up-orange)](https://github.com/Revan67/ThirdAge-Recomp)
[![Platform](https://img.shields.io/badge/platform-Windows-0078D4?logo=windows)](https://github.com/Revan67/ThirdAge-Recomp)
[![Original hardware](https://img.shields.io/badge/original%20hardware-Xbox-107C10?logo=xbox)](https://en.wikipedia.org/wiki/Xbox_(console))
[![Language](https://img.shields.io/github/languages/top/Revan67/ThirdAge-Recomp)](https://github.com/Revan67/ThirdAge-Recomp)
[![Last commit](https://img.shields.io/github/last-commit/Revan67/ThirdAge-Recomp)](https://github.com/Revan67/ThirdAge-Recomp/commits/main)
[![Stars](https://img.shields.io/github/stars/Revan67/ThirdAge-Recomp?style=flat)](https://github.com/Revan67/ThirdAge-Recomp/stargazers)

An early-stage static recompilation of the North American original-Xbox release
of *The Lord of the Rings: The Third Age* (`EA-095`, title ID `4541005F`,
version 8) into a native Windows executable.

This repository contains project-specific source code and research only. It
does **not** contain the game executable, disc image, movies, audio, or other
copyrighted game assets. You must supply files from a legally owned copy.

## Current status

The project is not yet playable.

- Translates all 14,089 currently discovered guest functions into native C.
- Loads all 13 XBE sections and resolves all 117 imported kernel symbols.
- Initializes cache, profile, audio, and the statically linked Xbox D3D code.
- Creates a 640x480 diagnostic framebuffer window.
- Executes NV2A push buffers, delivers PCRTC vblank interrupts, and renders the
  One Ring loading spinner through the software raster path.
- Streams `GlobScen.scx` and the opening chunks of `e98c03.scx` without
  entering the title's fatal disc-error loop.

The current frontier is the CPU-side scene-streaming handoff. The NV2A queue is
caught up and the loading overlay renders correctly, but the title has not yet
submitted scene geometry after opening the first chapter scene. Once that
handoff completes, broader NV2A method and shader coverage will become the next
rendering frontier.

## Repository layout

| Path | Purpose |
| --- | --- |
| `src/` | Game-specific host entry point and manual recompilation overrides |
| `config/` | Validated analysis seeds |
| `docs/` | Intake notes and technical findings |
| `vendor/xboxrecomp/` | Pinned public runtime/tooling fork |
| `dump/` | Local game executable, extracted assets, and analysis output (ignored) |
| `src/recomp/` | Locally generated recompilation sources (ignored) |

## Requirements

- 64-bit Windows
- Visual Studio 2022 with the Desktop development with C++ workload
- CMake 3.20 or newer
- Git with submodule support
- A legally owned North American Xbox copy of the game

## Setup

Clone the project and its runtime:

```powershell
git clone --recursive https://github.com/Revan67/ThirdAge-Recomp.git
cd ThirdAge-Recomp
```

Extract your own disc so the executable is located at:

```text
dump/game_files/default.xbe
```

The rest of the extracted disc filesystem belongs beneath
`dump/game_files/` as well. Game data is intentionally excluded by
`.gitignore` and must never be committed or redistributed.

Generated files under `src/recomp/` are also kept local. The analysis and
generation workflow is still being stabilized, so a fresh clone is not yet a
one-command reproducible build. Once those sources have been generated, build
with:

```powershell
cmake -S . -B build -A x64
cmake --build build --config Release
.\build\Release\third_age_recomp.exe
```

## Verified reference input

The current research uses a disc matching these Redump values:

| Item | Value |
| --- | --- |
| Disc size | `7,825,162,240` bytes |
| Disc MD5 | `57e3789289a89c860067d3c770e61807` |
| Disc SHA-1 | `bc97495b5702b11c4ae2c0e53d47ab1844dd3e4b` |
| `default.xbe` SHA-256 | `a45ca85284a12b86877ebe37e9e86741f166207bfc5a4355df990fa341a2485d` |

These hashes identify the supported input; they are not links to game data.

## Privacy and repository policy

Disc dumps, extracted assets, generated binaries, logs, saves, local tools,
editor settings, credentials, signing keys, and machine-specific files stay
outside version control. Before opening a pull request, check `git status` and
confirm that no proprietary or personal data is staged.

## Disclaimer

This is an independent preservation and compatibility research project. It is
not affiliated with or endorsed by Electronic Arts, Warner Bros., Tolkien
Enterprises, Microsoft, or the original developers. No game assets are
provided.

