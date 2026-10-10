# The Lord of the Rings: The Third Age — Recomp

[![Local milestone](https://img.shields.io/badge/local%20milestone-menu%20%2B%20audio%20verified-brightgreen)](docs/STATUS.md)
[![Platform](https://img.shields.io/badge/platform-Windows-0078D4?logo=windows)](https://github.com/Revan67/ThirdAge-Recomp)
[![Original hardware](https://img.shields.io/badge/original%20hardware-Xbox-107C10?logo=xbox)](https://en.wikipedia.org/wiki/Xbox_(console))
[![Language](https://img.shields.io/github/languages/top/Revan67/ThirdAge-Recomp)](https://github.com/Revan67/ThirdAge-Recomp)
[![CMake](https://img.shields.io/badge/CMake-3.20%2B-064F8C?logo=cmake)](CMakeLists.txt)
[![Local audio checks](https://img.shields.io/badge/local%20audio%20checks-5455%20passing-brightgreen)](docs/STATUS.md#verification)
[![Issues](https://img.shields.io/github/issues/Revan67/ThirdAge-Recomp)](https://github.com/Revan67/ThirdAge-Recomp/issues)
[![Last commit](https://img.shields.io/github/last-commit/Revan67/ThirdAge-Recomp)](https://github.com/Revan67/ThirdAge-Recomp/commits/main)
[![Stars](https://img.shields.io/github/stars/Revan67/ThirdAge-Recomp?style=flat)](https://github.com/Revan67/ThirdAge-Recomp/stargazers)

An early-stage static recompilation of the North American original-Xbox release
of *The Lord of the Rings: The Third Age* (`EA-095`, title ID `4541005F`,
version 8) into a native Windows executable.

This repository contains project-specific source code and research only. It
does **not** contain the game executable, disc image, movies, audio, or other
copyrighted game assets. You must supply files from a legally owned copy.

## Current status

**Startup reaches the main menu with working audio. Gameplay is not yet
verified.** Status reviewed October 9, 2026.

These milestones describe the menu/audio source checkpoint and its matching
runtime submodule revision. Game-code generation is still a local step, so a
fresh clone is not yet a turnkey build. The local-checks badge is a recorded
result, not a GitHub Actions/CI status.

- Loads the original XBE sections and resolves the title's 117 kernel imports.
- Renders the loading ring, legal splash/logo, EA, THX and New Line movies,
  followed by a textured main menu in the diagnostic framebuffer window.
- Completes the startup command queue in roughly 38 seconds on the development
  machine; this is an observation, not a performance guarantee.
- Produces audible movie and menu audio. A listener reports clean THX, New Line
  and main-menu music after the audio pacing correction.
- Passes 5,455 local APU regression checks in both Debug and Release, covering
  sample delivery, mixer advancement, IRQ status, voice-table backing and
  audio-thread lifecycle.

The next milestone is **New Game → opening scene → first controllable
gameplay**, checking input, transitions, 3D rendering, dialogue and effects.
Broader rendering, voice resampling, DSP effects and audio/video synchronization
remain unverified. Slight roughness in the EA logo audio needs a source/emulator
comparison before being classified as a bug. See [project status](docs/STATUS.md).

## Documentation

- [Status, limitations and next milestone](docs/STATUS.md)
- [First working-audio checkpoint](docs/WORKING_AUDIO_CHECKPOINT.md)
- [Front-end investigation and latest verification](docs/FRONTEND_STATE_TRACE.md)
- [Native/emulator startup comparison](docs/STARTUP_COMPARISON.md)
- [Disc intake and historical bring-up](docs/INTAKE.md)

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
- Python 3 with the runtime/tooling dependencies for local analysis and generation
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
one-command reproducible build. Use the matching pinned runtime revision.
Do not substitute an arbitrary newer upstream runtime for the pinned revision.
Once those sources have been generated and the matching runtime is available, build
with:

```powershell
cmake -S . -B build -A x64
cmake --build build --config Release
.\build\Release\third_age_recomp.exe
```

Run from the repository root so the relative game-data paths resolve correctly.
This is a development build, not an installable release. Diagnostic runs should
be bounded and stopped afterward; closing a window must not trigger a relaunch
loop.

## Local regression checks

The current working runtime includes a deterministic audio suite with a silent
fake output sink; it does not require game data or play audio through speakers:

```powershell
cmake -S vendor/xboxrecomp/tests/apu_monitor -B build/tests/apu_monitor -A x64
cmake --build build/tests/apu_monitor --config Release --target apu_monitor_test
.\build\tests\apu_monitor\Release\apu_monitor_test.exe
```

Use `Debug` in both paths/configuration to check that build too. These test
sources are included in the matching runtime submodule revision.
Additional renderer/compiler checks are described in the
[verification notes](docs/STATUS.md#verification).

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

The runtime is a separate Git checkout: its changes must be reviewed and
published before updating the parent repository's submodule pointer. A dirty
submodule alone does not carry runtime fixes into a clone.

## Licensing

No project-root license has been selected yet. The runtime has its own
[license and third-party notices](vendor/xboxrecomp/LICENSE); those do not
automatically assign a license to this project's original files. No game-data
distribution permission is implied.

## Disclaimer

This is an independent preservation and compatibility research project. It is
not affiliated with or endorsed by Electronic Arts, Warner Bros., Tolkien
Enterprises, Microsoft, or the original developers. No game assets are
provided.

