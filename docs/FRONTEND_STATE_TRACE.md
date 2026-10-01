# Front-end state trace (2026-10-01)

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
the dispatch result to an optional output pointer at message `+0x10`. It is
referenced from the image's static data near `0x0026F0BC`. It did not appear
in the successful state-2 trace. The next investigation should identify the
registration format around that data address and the producer expected to
emit event 1. Trace resource-manager slot 0 used by state 3 and the resulting
`+0xB0` value. Keep experimental changes out of generated sources in commits.

The game scene files `Data/Game/e98c/e98c03.scx` and `.sas` exist in the local
dump; the private dump must not be committed. Game runs for investigation
should use a hidden window and a watchdog. Closing a user-visible window must
not trigger any automatic relaunch.
