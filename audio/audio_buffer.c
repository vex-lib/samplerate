#include "vex.h"
#include "audio/audio_buffer.h"

#include <stdio.h>
#include <string.h>

#include "audio/audio_format.h"
#include "core/audio_memory.h"
#include "oop/samplerate_type.h"


;;DEFINITION
/**
 * ============================================================================
 * DEFINITION: AudioBuffer (audio/audio_buffer.c)
 * ============================================================================
 * A flat interleaved 32-bit-f32 PCM block. Two arena blocks back one logical
 * buffer: the small AudioBuffer control block and one contiguous sample block,
 * so the class pointer stays stable across a growth while the sample store can
 * be reallocated underneath it. Frames is the valid length; capacity is the
 * allocated frame count. All allocation is cold; the realtime callback only
 * borrows the sample pointer.
 *
 * Overflow is refused, not wrapped: frames * channels * sizeof(f32) is
 * computed with an explicit overflow check (the Cold-Strict, Hot-Minimal
 * Validation Law), and a rejected resize leaves the previous buffer intact.
 * ============================================================================
 */

;;OVERVIEW
/**
 * ============================================================================
 * MODULE: AudioBuffer (audio/audio_buffer.c)
 * ============================================================================
 * Flat interleaved f32 PCM block (opaque; fields live here).
 *
 * STRUCT FIELDS:
 * ----------------------------------------------------------------------------
 *   f32   *data;       // owned interleaved f32 sample block (arena)
 *   u32 frames;     // valid frames (<= capacity)
 *   u32 capacity;   // allocated frames
 *   u32 channels;   // interleaved channel count
 *   d64   sampleRate; // Hz
 *
 * PUBLIC SURFACE (audio/audio_buffer.h):
 *   Constructors: AudioBuffer_0/_1(frames)/_2(frames,ch)/_3(frames,ch,rate)
 *   Core:    AudioBuffer_resize(), AudioBuffer_clear(), AudioBuffer_free()
 *   Access:  AudioBuffer_getConstData/_getData/_getFrames/_getCapacity/
 *            _getChannels/_getSampleRate/_setChannels/_setSampleRate/_isValid
 *   Strings: AudioBuffer_toString(), AudioBuffer_toStringStruct()
 * ============================================================================
 */

typedef struct AudioBuffer {
    f32 *data;
    u32 frames;
    u32 capacity;
    u32 channels;
    d64 sampleRate;
} AudioBuffer;

;;SETTER
static inline fn AudioBuffer_setData(AudioBuffer *self, f32 *data) { (*self).data = data; }
;;SETTER
static inline fn AudioBuffer_setFrames(AudioBuffer *self, u32 frames) { (*self).frames = frames; }
;;SETTER
static inline fn AudioBuffer_setCapacity(AudioBuffer *self, u32 capacity) { (*self).capacity = capacity; }
;;SETTER
static inline fn AudioBuffer_setChannelsRaw(AudioBuffer *self, u32 channels) { (*self).channels = channels; }

// frames * channels * sizeof(f32), with explicit overflow refusal.
static bool audioBufferBytes(u32 frames, u32 channels, bytes *outBytes) {
    if (outBytes == nullptr || frames == 0u || channels == 0u)
        return false;
    if (frames > AUDIO_BUFFER_FRAMES_MAX)
        return false;
    bytes samples = (bytes) frames * (bytes) channels;
    if (samples / (bytes) channels != (bytes) frames)
        return false;                       // multiplication overflowed
    if (samples > SIZE_MAX / sizeof(f32))
        return false;
    *outBytes = samples * sizeof(f32);
    return true;
}

static AudioBuffer *audioBufferAllocControl() {
    AudioBuffer *self = (AudioBuffer*) AudioMemory_alloc(TYPE_AUDIO_BUFFER, sizeof(AudioBuffer));
    if (self == nullptr)
        return nullptr;
    AudioBuffer_setData(self, nullptr);
    AudioBuffer_setFrames(self, 0u);
    AudioBuffer_setCapacity(self, 0u);
    AudioBuffer_setChannelsRaw(self, AUDIO_CHANNELS_DEFAULT);
    AudioBuffer_setSampleRate(self, AUDIO_RATE_DEFAULT);
    return self;
}

// Allocate the sample store for exactly `frames` at the current channel count.
// Cold path; returns false and preserves state on overflow or allocation
// failure.
static bool audioBufferGrowTo(AudioBuffer *self, u32 frames) {
    bytes byteCount = 0u;
    u32 channels = AudioBuffer_getChannels(self);
    if (!audioBufferBytes(frames, channels, &byteCount))
        return false;
    f32 *block = (f32*) AudioMemory_alloc(TYPE_AUDIO_BUFFER, byteCount);
    if (block == nullptr)
        return false;
    u32 curFrames = AudioBuffer_getFrames(self);
    u32 copyFrames = curFrames < frames ? curFrames : frames;
    f32 *oldData = AudioBuffer_getData(self);
    if (oldData != nullptr && copyFrames > 0u) {
        bytes copyFloats = (bytes) copyFrames * (bytes) channels;
        memcpy(block, oldData, copyFloats * sizeof(f32));
    }
    AudioMemory_free(oldData);
    AudioBuffer_setData(self, block);
    AudioBuffer_setCapacity(self, frames);
    return true;
}

AudioBuffer *AudioBuffer_0() {
    AudioBuffer *self = audioBufferAllocControl();
    if (self == nullptr)
        return nullptr;
    if (!audioBufferGrowTo(self, AUDIO_BLOCK_FRAMES_DEFAULT)) {
        AudioMemory_free(self);
        return nullptr;
    }
    AudioBuffer_setFrames(self, AUDIO_BLOCK_FRAMES_DEFAULT);
    return self;
}

AudioBuffer *AudioBuffer_1(u32 frames) {
    AudioBuffer *self = audioBufferAllocControl();
    if (self == nullptr)
        return nullptr;
    if (!audioBufferGrowTo(self, frames)) {
        AudioMemory_free(self);
        return nullptr;
    }
    AudioBuffer_setFrames(self, frames);
    return self;
}

AudioBuffer *AudioBuffer_2(u32 frames, u32 channels) {
    AudioBuffer *self = AudioBuffer_1(frames);
    if (self != nullptr && channels >= 1u && channels <= AUDIO_CHANNELS_MAX)
        AudioBuffer_setChannels(self, channels);
    return self;
}

AudioBuffer *AudioBuffer_3(u32 frames, u32 channels, d64 sampleRate) {
    AudioBuffer *self = AudioBuffer_2(frames, channels);
    if (self != nullptr && sampleRate >= AUDIO_RATE_MIN && sampleRate <= AUDIO_RATE_MAX)
        AudioBuffer_setSampleRate(self, sampleRate);
    return self;
}

fn AudioBuffer_free(AudioBuffer *self) {
    if (self == nullptr)
        return;
    AudioMemory_free(AudioBuffer_getData(self));
    AudioBuffer_setData(self, nullptr);
    AudioMemory_free(self);
}

bool AudioBuffer_resize(AudioBuffer *self, u32 frames) {
    if (self == nullptr) {
        THROW("AudioBuffer_resize: null self");
        return false;
    }
    if (frames == 0u) {
        AudioBuffer_setFrames(self, 0u);
        return true;
    }
    if (frames > AUDIO_BUFFER_FRAMES_MAX) {
        THROW("AudioBuffer_resize: frames out of range");
        return false;
    }
    if (frames > AudioBuffer_getCapacity(self)) {
        if (!audioBufferGrowTo(self, frames)) {
            THROW("AudioBuffer_resize: growth failed");
            return false;
        }
    }
    AudioBuffer_setFrames(self, frames);
    return true;
}

fn AudioBuffer_clear(AudioBuffer *self) {
    f32 *data = AudioBuffer_getData(self);
    if (self == nullptr || data == nullptr)
        return;
    bytes f32s = (bytes) AudioBuffer_getFrames(self) * (bytes) AudioBuffer_getChannels(self);
    memset(data, 0, f32s * sizeof(f32));
}

;;GETTER
const f32 *AudioBuffer_getConstData(const AudioBuffer *self) {
    return self ? (*self).data : nullptr;
}

;;GETTER
f32 *AudioBuffer_getData(AudioBuffer *self) {
    return self ? (*self).data : nullptr;
}

;;GETTER
u32 AudioBuffer_getFrames(const AudioBuffer *self) {
    return self ? (*self).frames : 0u;
}

;;GETTER
u32 AudioBuffer_getCapacity(const AudioBuffer *self) {
    return self ? (*self).capacity : 0u;
}

;;GETTER
u32 AudioBuffer_getChannels(const AudioBuffer *self) {
    return self ? (*self).channels : 0u;
}

;;GETTER
d64 AudioBuffer_getSampleRate(const AudioBuffer *self) {
    return self ? (*self).sampleRate : 0.0;
}

fn AudioBuffer_setChannels(AudioBuffer *self, u32 channels) {
    if (self == nullptr) {
        THROW("AudioBuffer_setChannels: null self");
        return;
    }
    if (channels == 0u || channels > AUDIO_CHANNELS_MAX) {
        THROW("AudioBuffer_setChannels: channels out of range");
        return;
    }
    u32 oldChannels = AudioBuffer_getChannels(self);
    if (channels == oldChannels)
        return;
    f32 *block = nullptr;
    u32 capacity = AudioBuffer_getCapacity(self);
    f32 *oldData = AudioBuffer_getData(self);
    if (capacity > 0u) {
        bytes byteCount = 0u;
        if (!audioBufferBytes(capacity, channels, &byteCount)) {
            THROW("AudioBuffer_setChannels: overflow");
            return;
        }
        block = (f32*) AudioMemory_alloc(TYPE_AUDIO_BUFFER, byteCount);
        if (block == nullptr) {
            THROW("AudioBuffer_setChannels: allocation failed");
            return;
        }
        u32 frames = AudioBuffer_getFrames(self);
        if (oldData != nullptr && frames > 0u) {
            u32 copyChannels = oldChannels < channels ? oldChannels : channels;
            for (u32 f = 0u; f < frames; ++f) {
                f32 *dst = &block[(bytes) f * channels];
                const f32 *src = &oldData[(bytes) f * oldChannels];
                for (u32 c = 0u; c < copyChannels; ++c)
                    dst[c] = src[c];
            }
        }
    }
    AudioMemory_free(oldData);
    AudioBuffer_setData(self, block);
    AudioBuffer_setChannelsRaw(self, channels);
}

fn AudioBuffer_setSampleRate(AudioBuffer *self, d64 sampleRate) {
    if (self == nullptr) {
        THROW("AudioBuffer_setSampleRate: null self");
        return;
    }
    if (!(sampleRate >= AUDIO_RATE_MIN) || sampleRate > AUDIO_RATE_MAX) {
        THROW("AudioBuffer_setSampleRate: rate out of range");
        return;
    }
    (*self).sampleRate = sampleRate;
}

bool AudioBuffer_isValid(const AudioBuffer *self) {
    if (self == nullptr)
        return false;
    u32 capacity = AudioBuffer_getCapacity(self);
    if (AudioBuffer_getConstData(self) == nullptr || capacity == 0u)
        return false;
    u32 channels = AudioBuffer_getChannels(self);
    if (channels < 1u || channels > AUDIO_CHANNELS_MAX)
        return false;
    u32 frames = AudioBuffer_getFrames(self);
    if (frames > capacity || frames > AUDIO_BUFFER_FRAMES_MAX)
        return false;
    d64 sampleRate = AudioBuffer_getSampleRate(self);
    return sampleRate >= AUDIO_RATE_MIN && sampleRate <= AUDIO_RATE_MAX;
}

fn AudioBuffer_toString(const AudioBuffer *self, char *dest, bytes cap, bool *outTruncated) {
    if (outTruncated)
        *outTruncated = false;
    if (dest == nullptr || cap == 0u) {
        if (outTruncated)
            *outTruncated = true;
        return;
    }
    if (self == nullptr) {
        i32 n = snprintf(dest, cap, "nullptr");
        if (outTruncated && n >= 0 && (bytes) n >= cap)
            *outTruncated = true;
        return;
    }
    i32 n = snprintf(dest, cap, "AudioBuffer(%u/%u frames, %u ch, %.1f Hz)",
                     AudioBuffer_getFrames(self), AudioBuffer_getCapacity(self),
                     AudioBuffer_getChannels(self), AudioBuffer_getSampleRate(self));
    if (outTruncated && n >= 0 && (bytes) n >= cap)
        *outTruncated = true;
}

fn AudioBuffer_toStringStruct(const AudioBuffer *self, char *dest, bytes cap, bool *outTruncated) {
    if (outTruncated)
        *outTruncated = false;
    if (dest == nullptr || cap == 0u) {
        if (outTruncated)
            *outTruncated = true;
        return;
    }
    if (self == nullptr) {
        i32 n = snprintf(dest, cap, "nullptr");
        if (outTruncated && n >= 0 && (bytes) n >= cap)
            *outTruncated = true;
        return;
    }
    i32 n = snprintf(dest, cap,
                     "AudioBuffer { data: %p, frames: %u, capacity: %u, channels: %u, sampleRate: %.1f }",
                     (const_any) AudioBuffer_getConstData(self), AudioBuffer_getFrames(self), AudioBuffer_getCapacity(self),
                     AudioBuffer_getChannels(self), AudioBuffer_getSampleRate(self));
    if (outTruncated && n >= 0 && (bytes) n >= cap)
        *outTruncated = true;
}
