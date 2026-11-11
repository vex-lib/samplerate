#ifndef STREAM_AUDIO_STREAM_H
#define STREAM_AUDIO_STREAM_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "c23/constructor.h"
#include "annotation/annotation.h"

// stream/audio_stream.h — the native output stream: the audio counterpart to
// graphvex's presentation backend. The contract is identical on every platform;
// the platform translation unit implements it (platform/audio_stream_cocoa.m on
// macOS, platform/audio_stream_stub.c elsewhere), exactly as vexspoke's window/
// and audio/ seams do. Callers never see a CoreAudio/AudioUnit type.
//
// The render callback runs on the OS realtime audio thread. It must not
// allocate, lock, log, or wait (the Zero-Allocation Audio Callback Law, the
// Bounded Wait Law): it fills the borrowed interleaved f32 buffer and returns.
//
// Constructors:
//   AudioStream();                 // empty shell, device defaults
//   AudioStream(&config);          // configured shell
//   #define AudioStream(...) CONSTRUCTOR_DISPATCH(...)

// One realtime render callback. Called by the OS audio thread; fills
// interleavedOutput with frames * channels f32s (zero-fill for silence).
typedef void (*AudioRenderCallback)(f32 *interleavedOutput, u32 frames,
                                    u32 channels, void *userData);

typedef struct AudioStreamConfig {
    d64 sampleRate;        // 0 = device default
    u32 channels;        // 0 = device default
    u32 framesPerBlock;  // 0 = device default
    AudioRenderCallback callback;
    ;;WHAT("caller render context")
    void *userData;
} AudioStreamConfig;

// Zeroed config: every field at its "device default" sentinel, no callback.
static inline AudioStreamConfig AudioStreamConfig_default(void) {
    AudioStreamConfig c;
    c.sampleRate = 0.0;
    c.channels = 0u;
    c.framesPerBlock = 0u;
    c.callback = nullptr;
    c.userData = nullptr;
    return c;
}

typedef struct AudioStream AudioStream;

AudioStream *AudioStream_0(void);
AudioStream *AudioStream_1(const AudioStreamConfig *config);
#define AudioStream(...) CONSTRUCTOR_DISPATCH(AudioStream, __VA_ARGS__)

// Release the stream. Stops it first when running; null-safe.
void AudioStream_free(AudioStream *self);

// Bind the platform output unit and prepare it (cold). False on rejection; the
// shell stays usable for a retry after the config is fixed.
bool AudioStream_open(AudioStream *self);

// Start/stop the realtime pull. Bounded, never a blocking wait.
bool AudioStream_start(AudioStream *self);
bool AudioStream_stop(AudioStream *self);
bool AudioStream_isRunning(const AudioStream *self);

// Negotiated stream properties; 0.0 when none. Null-safe.
d64 AudioStream_getSampleRate(const AudioStream *self);
u32 AudioStream_getChannels(const AudioStream *self);
u32 AudioStream_getFramesPerBlock(const AudioStream *self);
d64 AudioStream_getLatencyMs(const AudioStream *self);

// Bounded string projections (the toString Law). Cold path only.
void AudioStream_toString(const AudioStream *self, char *dest, bytes cap, bool *outTruncated);
void AudioStream_toStringStruct(const AudioStream *self, char *dest, bytes cap, bool *outTruncated);

#endif // STREAM_AUDIO_STREAM_H
