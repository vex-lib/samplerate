#include "vex.h"
#include "stream/audio_stream.h"

#include <stdio.h>

#include "core/audio_memory.h"
#include "oop/samplerate_type.h"


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

AudioStream *AudioStream_0() {
    return nullptr;
}

AudioStream *AudioStream_1(const AudioStreamConfig *config) {
    (discard) config;
    return nullptr;
}

bool AudioStream_open(AudioStream *self) {
    (discard) self;
    return false;
}

bool AudioStream_start(AudioStream *self) {
    (discard) self;
    return false;
}

bool AudioStream_stop(AudioStream *self) {
    (discard) self;
    return false;
}

bool AudioStream_isRunning(const AudioStream *self) {
    (discard) self;
    return false;
}

fn AudioStream_free(AudioStream *self) {
    (discard) self;
}

d64 AudioStream_getSampleRate(const AudioStream *self) {
    (discard) self;
    return 0.0;
}

u32 AudioStream_getChannels(const AudioStream *self) {
    (discard) self;
    return 0u;
}

u32 AudioStream_getFramesPerBlock(const AudioStream *self) {
    (discard) self;
    return 0u;
}

d64 AudioStream_getLatencyMs(const AudioStream *self) {
    (discard) self;
    return 0.0;
}

fn AudioStream_toString(const AudioStream *self, char *dest, bytes cap, bool *outTruncated) {
    (discard) self;
    if (outTruncated)
        *outTruncated = false;
    if (dest == nullptr || cap == 0u) {
        if (outTruncated)
            *outTruncated = true;
        return;
    }
    (discard) snprintf(dest, cap, "AudioStream(unavailable)");
}

fn AudioStream_toStringStruct(const AudioStream *self, char *dest, bytes cap, bool *outTruncated) {
    (discard) self;
    if (outTruncated)
        *outTruncated = false;
    if (dest == nullptr || cap == 0u) {
        if (outTruncated)
            *outTruncated = true;
        return;
    }
    (discard) snprintf(dest, cap, "AudioStream { unavailable on this host }");
}
