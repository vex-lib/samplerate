# samplerate — Repo-Local Living Preferences

## Constitution Link

gist.md (`../../metadata/gists/preferences/gist.md`) is the compressed law list; all universal laws bind this repository. Read one on demand: `./tools/prefs law "<title>"`. Universal laws are inherited, never restated.

Tier: core (R3 Audio Driver). Owns: platform-agnostic audio surface, macOS AVFoundation backend, portable stub. Borrows: Vexspoke R2 CPU computation/synchronization/behavior, Relational Engine memory/storage/native C search. R5 DAW `impedance` consumes samplerate.

## Exclusive Laws

| Law Title | Scope | Enforcement |
| **Zero-Allocation Audio Callback Law** | R3 Audio Driver | Mandatory for `samplerate` |
| **Lockless Ring Transport Law** | R3 Audio Driver | Mandatory for `samplerate` |
| **Audio Ownership Law** | R3 Audio Driver | Mandatory for `samplerate` |

### Zero-Allocation Audio Callback Law

* The high-priority OS real-time audio callback never allocates heap memory (`malloc`/`free`), makes system calls or file IO, or takes mutexes.
* Allocate all audio buffers and DSP state at stream initialization.
* Inter-thread communication uses wait-free ring buffers only.

### Lockless Ring Transport Law

* Playback/recording devices and DSP engines transport audio packets only through lockless SPSC or MPMC ring buffers.
* Coordinate read/write indices with atomic operations using acquire-release semantics.
* Overflow or underflow fades or silences gracefully, without deadlock.

### Audio Ownership Law

* Samplerate owns the platform-agnostic audio surface (`audio/audio.h`, `audio/audio_hal.h`) plus the macOS AVFoundation backend (`platform/audio_cocoa.m`, `platform/audio_hal_mac.m`) and the portable stub (`audio/audio_stub.c`, `audio/audio_hal_stub.c`).
* The R5 DAW `impedance` consumes samplerate's HAL, never vexspoke's.

## Repo-Local Extensions

* None — no managed exceptions to universal laws.

## Readiness Cross-Reference

* Feature readiness: samplerate readiness gist.
* Open blockers: ecosystem blockers gist.
* Proof lawbook: `tests/test-preferences.md` — `./tools/prefs test "<title>"`.
* Evidence ledger: `metadata/gists/test-checklist.md` — `python3 tools/test_checklist.py check`.
