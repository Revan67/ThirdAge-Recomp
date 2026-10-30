# Building ThirdAge-Recomp (Windows)

Build the original-Xbox game's native Windows executable from your own
`default.xbe`, using the verified analysis and recompilation pipeline.

## What you need

- 64-bit Windows
- Visual Studio 2026 (v18) — full IDE or Build Tools — with the "Desktop
  development with C++" workload (MSVC x64 toolset + Windows SDK)
- CMake 3.20 or newer
- The Python virtualenv at `.venv` (Python 3.11, `capstone` only)
- Git with submodule support
- A legally owned North American Xbox copy of the game

Game data is not distributed in this repository; you must supply it yourself.

## One-time setup

```powershell
git clone --recursive https://github.com/Revan67/ThirdAge-Recomp.git
cd ThirdAge-Recomp
```

Extract your own disc so the executable exists at `dump/game_files/default.xbe`
(the rest of the extracted filesystem also belongs under `dump/game_files/`).

Create the virtualenv and install the one third-party dependency the pipeline
needs:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install capstone
```

No requirements file is kept at the repo root; `capstone` is the only package
the tools need beyond the standard library.

## Build

Fastest path — from the repository root (the script locates the repo itself, so
the working directory only matters for how you spell the `-File` path):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1
```

The script supports three switches:

| Switch | Effect |
| --- | --- |
| `-SkipAnalysis` | Skip the analysis/recomp steps (1–5) and run only CMake configure + build. |
| `-Debug` | Build the `Debug` configuration instead of `Release`. |
| `-DryRun` | Print every command that would run, without executing anything. Prerequisite checks still run, so it also proves the paths resolve. |

### Manual steps (no script)

> **Mandatory:** three things below are required for a working build —
> `--exclude-manual src/recomp_manual.c` on the `tools.recomp` step,
> `--seed-functions config/seed_functions.json` on the `tools.disasm` step, and
> `--extra-sections D3D,XPP,XGRPH,D3DX,DSOUND,DOLBY` so the analysis covers every
> executable section. Omitting the first fails at link time, omitting either of
> the others breaks boot. See
> [Mandatory steps most people miss](#mandatory-steps-most-people-miss).

All five python steps must run with the working directory set to
`vendor\xboxrecomp` (using `../../.venv/Scripts/python.exe`). `<repo>` below is
the absolute path to the repository root.

```powershell
cd <repo>\vendor\xboxrecomp

..\..\.venv\Scripts\python.exe -m tools.xbe_parser <repo>\dump\game_files\default.xbe --json <repo>\dump\game_files\tta_analysis.json
..\..\.venv\Scripts\python.exe -m tools.disasm <repo>\dump\game_files\default.xbe --text-only -v --seed-functions <repo>\config\seed_functions.json --extra-sections D3D,XPP,XGRPH,D3DX,DSOUND,DOLBY
..\..\.venv\Scripts\python.exe -m tools.func_id <repo>\dump\game_files\default.xbe -v
..\..\.venv\Scripts\python.exe -m tools.abi_analysis <repo>\dump\game_files\default.xbe -v
..\..\.venv\Scripts\python.exe -m tools.recomp <repo>\dump\game_files\default.xbe --all --split 1000 --exclude-manual <repo>\src\recomp_manual.c --gen-dir <repo>\src\recomp\gen

cd <repo>
cmake -S . -B build -G "Visual Studio 18 2026" -A x64
cmake --build build --config Release
```

Step 5 writes the generated translation units (plus the dispatch headers) into
`src/recomp/gen/`; that tree and `build/` are gitignored local output.

## Mandatory steps most people miss

**`--exclude-manual src/recomp_manual.c` on `tools.recomp`** — required. Without
it, the link fails:

```text
recomp_0005.obj : error LNK2005: sub_000E4540 already defined in recomp_manual.obj
LNK1169
```

`src/recomp_manual.c` contains hand-written overrides; recompiling those same
functions again produces duplicate symbols.

**`--seed-functions config/seed_functions.json` on `tools.disasm`** — required.
Without it the detector finds **13,816** functions instead of **13,829**, and
the built executable fails much earlier at boot.

**`--extra-sections D3D,XPP,XGRPH,D3DX,DSOUND,DOLBY` on `tools.disasm`** —
required, and the least obvious of the three. `--text-only` decodes `.text` and
then only *decodes* the library sections without tracking their branches, so
`_find_function_end` cannot see a function's forward jumps and cuts it at its
first internal branch target. The cut address is then "called by translated
code but not detected as a function", which the translator emits as:

```c
void sub_0023B097(void) { g_esp += 4; /* not detected */ }
```

A stub that consumes the return address and executes nothing. One such stub in
the static-init pass corrupts `esi` and 8 bytes of `esp`, the init loop then
walks low memory for ~179,000 iterations, and the title never leaves a white
framebuffer. With every executable section analysed the count is **14,092**
functions (the project documents 14,088) and boot reaches the intro movies.

## Expected output / known warnings

- `C4717 'sub_0017F840' recursive on all control paths` is a known, benign
  warning; it does not affect the build.
- Final executable: `build\Release\third_age_recomp.exe`.
- Run the executable from the repository root so relative game-data paths
  resolve.

## Verified

Verified on this repository state with Windows 11, Visual Studio 18 Build Tools
`18.8.12021.73` (generator `Visual Studio 18 2026`, `-A x64`), CMake `4.4.4`,
and a Python `3.11.15` `.venv` (`capstone 5.0.9`). Observed counts:
**14,092 functions detected, 0 unresolved indirect calls at runtime**, and the
executable boots through the intro movies without crashing. This is a record
of this input and repository state, not a guarantee for other inputs.

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `LNK2005: sub_000E4540 already defined in recomp_manual.obj` then `LNK1169` | `--exclude-manual` was omitted from `tools.recomp`. |
| Executable fails early at boot, or disasm reports 13,816 functions | `--seed-functions` was omitted from `tools.disasm`. |
| Disasm reports ~13,829 functions, boot spins or the framebuffer stays white | `--extra-sections` was omitted; library sections were decoded but not walked. |
| `dump/game_files/default.xbe` not found | Extract your own disc; the file is not in the repo. |
| Script stops early with a venv/`capstone` or CMake error | Run the one-time setup above; the script names the exact missing path. |
| CMake reports an unknown generator on older Visual Studio | Use `Visual Studio 17 2022`. |
| CMake errors about a different source directory, or the build fails after the repo folder was moved or renamed | `build/` caches absolute paths. Delete `build/` and re-run the configure step (the build script does this automatically). Nothing else in the repo stores absolute paths — `CMakeLists.txt` and `scripts/build.ps1` both resolve paths relative to their own location. |
