#ifndef CORE_AUDIO_MEMORY_H
#define CORE_AUDIO_MEMORY_H

#include "vex.h"
#include "nio/mem.h"

// core/audio_memory.h — the Samplerate MODULE that owns its dedicated
// Relational Engine arena plus the per-block transient scratch.
//
// Every i64-lived samplerate object is carved from this arena; the 16-byte
// self-describing header (MemoryHeader, owned by Relational Engine in
// `nio/mem.h`) carries the TYPE_* id. Allocation is COLD only — the realtime
// audio callback never allocates (the Zero-Allocation Audio Callback Law).
//
// Runtime-varying capacities come from named defaults and grow on demand; the
// defaults below are starting points, never hard ceilings (the No Hardcoding
// Law).

#define AUDIO_MEMORY_DEFAULT_BYTES         (32u * 1024u * 1024u)
#define AUDIO_MEMORY_DEFAULT_SCRATCH_BYTES (4u * 1024u * 1024u)

// Lazily create (once) and return the Samplerate arena; borrowed by callers
// and destroyed only through AudioMemory_shutdown (R1 teardown).
MemoryArena *AudioMemory_arena();

// Allocate a block from the Samplerate arena with the given type id. nullptr on
// failure or a null arena.
any AudioMemory_alloc(u64 typeId, bytes numBytes);

// Grow/shrink an arena block, preserving contents and type. Returns the new
// payload pointer (the old one is freed); nullptr on failure leaves the
// original intact.
any AudioMemory_realloc(any userPtr, bytes newBytes);

// Free a block previously returned by AudioMemory_alloc. Null-safe.
fn AudioMemory_free(any userPtr);

// Bump-allocate per-block scratch (the render-block scratchpad). Excludes
// active users: call only while the stream is stopped (the Bounded Wait Law).
any AudioMemory_scratch(u64 typeId, bytes numBytes);

// Reset the scratch bumper. Excludes active users, like AudioMemory_scratch.
fn AudioMemory_resetScratch();

// Tear down the arena and scratch. Owned by R1 teardown; never the callback.
fn AudioMemory_shutdown();

#endif // CORE_AUDIO_MEMORY_H
