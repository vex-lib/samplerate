#ifndef AUDIO_AUDIO_BUFFER_H
#define AUDIO_AUDIO_BUFFER_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "util/constructor.h"

// audio/audio_buffer.h — a flat, interleaved 32-bit-f32 PCM block owned by
// the Samplerate arena. Frames, capacity, channels and sample rate are explicit
// and the backing store is one contiguous arena block, so a consumer sweeps it
// linearly and never pointer-chases (the Data-Oriented Storage Law).
//
// The buffer is prepared cold. The realtime callback only reads the borrowed
// pointer from AudioBuffer_getConstData; it never resizes or allocates (the
// Zero-Allocation Audio Callback Law).
//
// Constructors:
//   AudioBuffer();                              // default block capacity
//   AudioBuffer(512);                           // frames = capacity
//   AudioBuffer(512, AUDIO_CHANNELS_STEREO);
//   AudioBuffer(512, AUDIO_CHANNELS_STEREO, 48000.0);

#define AUDIO_BUFFER_FRAMES_MAX   (1u << 24)   // 16,777,216 frames per block

typedef struct AudioBuffer AudioBuffer;

AudioBuffer *AudioBuffer_0(void);
AudioBuffer *AudioBuffer_1(u32 frames);
AudioBuffer *AudioBuffer_2(u32 frames, u32 channels);
AudioBuffer *AudioBuffer_3(u32 frames, u32 channels, d64 sampleRate);
#define AudioBuffer(...) CONSTRUCTOR_DISPATCH(AudioBuffer, __VA_ARGS__)

// Release the block (and its backing PCM) to the Samplerate arena. Null-safe.
void AudioBuffer_free(AudioBuffer *self);

// Set the valid frame count, growing the backing store when needed. Cold path
// only. Returns false (state preserved) on a null self, an oversized request, or
// allocation failure.
bool AudioBuffer_resize(AudioBuffer *self, u32 frames);

// Zero the valid frames (metadata untouched).
void AudioBuffer_clear(AudioBuffer *self);

// Read-only accessors. The borrowed pointer is valid until resize/free.
const f32 *AudioBuffer_getConstData(const AudioBuffer *self);
f32 *AudioBuffer_getData(AudioBuffer *self);

u32 AudioBuffer_getFrames(const AudioBuffer *self);
u32 AudioBuffer_getCapacity(const AudioBuffer *self);
u32 AudioBuffer_getChannels(const AudioBuffer *self);
d64 AudioBuffer_getSampleRate(const AudioBuffer *self);

// Validated setters (reject-or-preserve with a cold THROW).
void AudioBuffer_setChannels(AudioBuffer *self, u32 channels);
void AudioBuffer_setSampleRate(AudioBuffer *self, d64 sampleRate);

bool AudioBuffer_isValid(const AudioBuffer *self);

// Bounded string projections (the toString Law). Cold path only.
void AudioBuffer_toString(const AudioBuffer *self, char *dest, bytes cap, bool *outTruncated);
void AudioBuffer_toStringStruct(const AudioBuffer *self, char *dest, bytes cap, bool *outTruncated);

#endif // AUDIO_AUDIO_BUFFER_H
