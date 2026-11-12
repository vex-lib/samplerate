#include "stream/audio_stream.h"

#include <stdio.h>

#include "core/audio_memory.h"
#include "oop/samplerate_type.h"

#include "annotation/annotation.h"

;;DEFINITION
/**
 * ============================================================================
 * DEFINITION: AudioStream (platform/audio_stream_stub.c)
 * ============================================================================
 * The silence backend for platforms without the CoreAudio seam yet. Same
 * contract, zero sound: every constructor returns nullptr, every lifecycle call
 * fails closed, and every getter returns a safe zero default, so callers stay
 * identical across platforms while the Windows WASAPI / Linux ALSA backends
 * land. Marked ;;INCOMPLETE until then.
 * ============================================================================
 */

;;OVERVIEW
/**
 * ============================================================================
 * MODULE: AudioStream (platform/audio_stream_stub.c)
 * ============================================================================
 * Non-Apple fallback for stream/audio_stream.h — fails closed, owns no state.
 *
 * STRUCT FIELDS: none — no stream can be constructed on this host.
 *
 * PUBLIC SURFACE (stream/audio_stream.h): every function returns its safe
 * default (nullptr / false / 0.0 / 0).
 * ============================================================================
 */

;;INCOMPLETE // Windows WASAPI and Linux ALSA backends land here.

AudioStream *AudioStream_0(void) {
    return nullptr;
}

AudioStream *AudioStream_1(const AudioStreamConfig *config) {
    (void) config;
    return nullptr;
}

bool AudioStream_open(AudioStream *self) {
    (void) self;
    return false;
}

bool AudioStream_start(AudioStream *self) {
    (void) self;
    return false;
}

bool AudioStream_stop(AudioStream *self) {
    (void) self;
    return false;
}

bool AudioStream_isRunning(const AudioStream *self) {
    (void) self;
    return false;
}

void AudioStream_free(AudioStream *self) {
    (void) self;
}

d64 AudioStream_getSampleRate(const AudioStream *self) {
    (void) self;
    return 0.0;
}

u32 AudioStream_getChannels(const AudioStream *self) {
    (void) self;
    return 0u;
}

u32 AudioStream_getFramesPerBlock(const AudioStream *self) {
    (void) self;
    return 0u;
}

d64 AudioStream_getLatencyMs(const AudioStream *self) {
    (void) self;
    return 0.0;
}

void AudioStream_toString(const AudioStream *self, char *dest, bytes cap, bool *outTruncated) {
    (void) self;
    if (outTruncated)
        *outTruncated = false;
    if (dest == nullptr || cap == 0u) {
        if (outTruncated)
            *outTruncated = true;
        return;
    }
    (void) snprintf(dest, cap, "AudioStream(unavailable)");
}

void AudioStream_toStringStruct(const AudioStream *self, char *dest, bytes cap, bool *outTruncated) {
    (void) self;
    if (outTruncated)
        *outTruncated = false;
    if (dest == nullptr || cap == 0u) {
        if (outTruncated)
            *outTruncated = true;
        return;
    }
    (void) snprintf(dest, cap, "AudioStream { unavailable on this host }");
}
