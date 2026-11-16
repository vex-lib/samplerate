#import <AudioToolbox/AudioToolbox.h>
#import <CoreAudio/CoreAudio.h>

#include "vex.h"
#include <stdio.h>
#include <string.h>

#include "stream/audio_stream.h"

#include "core/audio_memory.h"
#include "oop/samplerate_type.h"


;;DEFINITION
/**
 * ============================================================================
 * DEFINITION: AudioStream (platform/audio_stream_cocoa.m)
 * ============================================================================
 * The macOS implementation of stream/audio_stream.h: a default-output AudioUnit
 * HAL with a f32 PCM stream format and a render callback that feeds the
 * caller's realtime callback straight into hardware output at minimal buffer
 * latency. This is the audio counterpart to graphvex's presentation backend —
 * the same contract on every platform, a native unit behind it.
 *
 * The AudioStream block is carved from the Samplerate arena; the AudioUnit is
 * the OS-owned resource and is disposed in AudioStream_free. The render callback
 * runs on the audio thread and never allocates, locks, or waits: it calls the
 * registered callback or zero-fills (the Zero-Allocation Audio Callback Law).
 * ============================================================================
 */

;;OVERVIEW
/**
 * ============================================================================
 * MODULE: AudioStream (platform/audio_stream_cocoa.m)
 * ============================================================================
 * macOS CoreAudio default-output AudioUnit HAL for realtime PCM output.
 *
 * STRUCT FIELDS:
 * ----------------------------------------------------------------------------
 *   AudioComponentInstance unit;        // default-output AudioUnit (OS-owned)
 *   bool   running;                     // AudioOutputUnitStart succeeded
 *   d64 sampleRate;                  // negotiated Hz
 *   u32 channels;                  // negotiated channel count
 *   u32 framesPerBlock;            // requested render quantum (frames)
 *   AudioRenderCallback callback;       // caller's realtime pull
 *   ;;WHAT("caller render context")
 *   any userData;                     // passed back to callback
 *
 * PUBLIC SURFACE (stream/audio_stream.h):
 *   Constructors: AudioStream_0(), AudioStream_1(config)
 *   Lifecycle: AudioStream_open/_start/_stop/_free/_isRunning
 *   Metrics:   AudioStream_getSampleRate/_getChannels/_getFramesPerBlock/_getLatencyMs
 *   Strings:   AudioStream_toString(), AudioStream_toStringStruct()
 * ============================================================================
 */

#define AUDIO_STREAM_DEFAULT_RATE_HZ  48000.0
#define AUDIO_STREAM_DEFAULT_CHANNELS 2u

typedef struct AudioStream {
    AudioComponentInstance unit;
    bool running;
    d64 sampleRate;
    u32 channels;
    u32 framesPerBlock;
    AudioRenderCallback callback;
    ;;WHAT("caller render context")
    any userData;
} AudioStream;

;;GETTER
static inline AudioComponentInstance AudioStream_unit(const AudioStream *self) { return (*self).unit; }
;;SETTER
static inline fn AudioStream_setUnit(AudioStream *self, AudioComponentInstance unit) { (*self).unit = unit; }
;;SETTER
static inline fn AudioStream_setRunning(AudioStream *self, bool running) { (*self).running = running; }
;;SETTER
static inline fn AudioStream_setSampleRate(AudioStream *self, d64 sampleRate) { (*self).sampleRate = sampleRate; }
;;SETTER
static inline fn AudioStream_setChannels(AudioStream *self, u32 channels) { (*self).channels = channels; }
;;SETTER
static inline fn AudioStream_setFramesPerBlock(AudioStream *self, u32 framesPerBlock) { (*self).framesPerBlock = framesPerBlock; }
;;GETTER
static inline AudioRenderCallback AudioStream_callback(const AudioStream *self) { return (*self).callback; }
;;SETTER
static inline fn AudioStream_setCallback(AudioStream *self, AudioRenderCallback callback) { (*self).callback = callback; }
;;GETTER
static inline any AudioStream_userData(const AudioStream *self) { return (*self).userData; }
;;SETTER
static inline fn AudioStream_setUserData(AudioStream *self, any userData) { (*self).userData = userData; }

;;GETTER
static inline d64 AudioStreamConfig_sampleRate(const AudioStreamConfig *self) { return (*self).sampleRate; }
;;GETTER
static inline u32 AudioStreamConfig_channels(const AudioStreamConfig *self) { return (*self).channels; }
;;GETTER
static inline u32 AudioStreamConfig_framesPerBlock(const AudioStreamConfig *self) { return (*self).framesPerBlock; }
;;GETTER
static inline AudioRenderCallback AudioStreamConfig_callback(const AudioStreamConfig *self) { return (*self).callback; }
;;GETTER
static inline any AudioStreamConfig_userData(const AudioStreamConfig *self) { return (*self).userData; }

;;GETTER
static inline UInt32 AudioBufferList_mNumberBuffers(const AudioBufferList *self) { return (*self).mNumberBuffers; }
;;GETTER
static inline void *AudioBufferList_mBuffers0Data(const AudioBufferList *self) { return (*self).mBuffers[0].mData; }

static OSStatus audioStreamRender(any inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
    (discard) ioActionFlags;
    (discard) inTimeStamp;
    (discard) inBusNumber;

    AudioStream *self = (AudioStream*) inRefCon;
    if (self == nullptr || ioData == nullptr || AudioBufferList_mNumberBuffers(ioData) == 0u)
        return noErr;
    f32 *out = (f32*) AudioBufferList_mBuffers0Data(ioData);
    if (out == nullptr)
        return noErr;
    u32 channels = AudioStream_getChannels(self);
    AudioRenderCallback cb = AudioStream_callback(self);
    if (cb != nullptr)
        cb(out, (u32) inNumberFrames, channels, AudioStream_userData(self));
    else
        memset(out, 0, (bytes) inNumberFrames * (bytes) channels * sizeof(f32));
    return noErr;
}

AudioStream *AudioStream_1(const AudioStreamConfig *config) {
    AudioStream *self = (AudioStream*) AudioMemory_alloc(TYPE_AUDIO_STREAM, sizeof(AudioStream));
    if (self == nullptr)
        return nullptr;
    AudioStream_setUnit(self, nullptr);
    AudioStream_setRunning(self, false);
    AudioStream_setSampleRate(self, (config && AudioStreamConfig_sampleRate(config) > 0.0)
        ? AudioStreamConfig_sampleRate(config) : AUDIO_STREAM_DEFAULT_RATE_HZ);
    AudioStream_setChannels(self, (config && AudioStreamConfig_channels(config) > 0u)
        ? AudioStreamConfig_channels(config) : AUDIO_STREAM_DEFAULT_CHANNELS);
    AudioStream_setFramesPerBlock(self, (config && AudioStreamConfig_framesPerBlock(config) > 0u)
        ? AudioStreamConfig_framesPerBlock(config) : 0u);
    AudioStream_setCallback(self, config ? AudioStreamConfig_callback(config) : nullptr);
    AudioStream_setUserData(self, config ? AudioStreamConfig_userData(config) : nullptr);
    return self;
}

AudioStream *AudioStream_0() {
    return AudioStream_1(nullptr);
}

bool AudioStream_open(AudioStream *self) {
    if (self == nullptr) {
        THROW("AudioStream_open: null self");
        return false;
    }
    if (AudioStream_unit(self) != nullptr)
        return true;

    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_DefaultOutput;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;

    AudioComponent comp = AudioComponentFindNext(nullptr, &desc);
    if (comp == nullptr) {
        THROW("AudioStream_open: no default output unit");
        return false;
    }

    AudioComponentInstance au = nullptr;
    OSStatus err = AudioComponentInstanceNew(comp, &au);
    if (err != noErr || au == nullptr) {
        THROW("AudioStream_open: instance creation failed");
        return false;
    }

    AudioStreamBasicDescription asbd;
    memset(&asbd, 0, sizeof(asbd));
    u32 channels = AudioStream_getChannels(self);
    asbd.mSampleRate = AudioStream_getSampleRate(self);
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
    asbd.mBytesPerPacket = channels * sizeof(f32);
    asbd.mFramesPerPacket = 1;
    asbd.mBytesPerFrame = channels * sizeof(f32);
    asbd.mChannelsPerFrame = channels;
    asbd.mBitsPerChannel = 32;

    err = AudioUnitSetProperty(au, kAudioUnitProperty_StreamFormat,
                               kAudioUnitScope_Input, 0, &asbd, sizeof(asbd));
    if (err != noErr) {
        AudioComponentInstanceDispose(au);
        THROW("AudioStream_open: stream format rejected");
        return false;
    }

    AURenderCallbackStruct cb;
    cb.inputProc = audioStreamRender;
    cb.inputProcRefCon = (any) self;
    err = AudioUnitSetProperty(au, kAudioUnitProperty_SetRenderCallback,
                               kAudioUnitScope_Input, 0, &cb, sizeof(cb));
    if (err != noErr) {
        AudioComponentInstanceDispose(au);
        THROW("AudioStream_open: render callback rejected");
        return false;
    }

    err = AudioUnitInitialize(au);
    if (err != noErr) {
        AudioComponentInstanceDispose(au);
        THROW("AudioStream_open: unit initialize failed");
        return false;
    }

    AudioStream_setUnit(self, au);
    return true;
}

bool AudioStream_start(AudioStream *self) {
    AudioComponentInstance unit = self ? AudioStream_unit(self) : nullptr;
    if (self == nullptr || unit == nullptr) {
        THROW("AudioStream_start: stream not open");
        return false;
    }
    if (AudioStream_isRunning(self))
        return true;
    OSStatus err = AudioOutputUnitStart(unit);
    if (err != noErr) {
        THROW("AudioStream_start: output start failed");
        return false;
    }
    AudioStream_setRunning(self, true);
    return true;
}

bool AudioStream_stop(AudioStream *self) {
    AudioComponentInstance unit = self ? AudioStream_unit(self) : nullptr;
    if (self == nullptr || unit == nullptr)
        return false;
    if (!AudioStream_isRunning(self))
        return true;
    OSStatus err = AudioOutputUnitStop(unit);
    if (err != noErr) {
        THROW("AudioStream_stop: output stop failed");
        return false;
    }
    AudioStream_setRunning(self, false);
    return true;
}

;;GETTER
bool AudioStream_isRunning(const AudioStream *self) {
    return self ? (*self).running : false;
}

fn AudioStream_free(AudioStream *self) {
    if (self == nullptr)
        return;
    if (AudioStream_isRunning(self))
        AudioStream_stop(self);
    AudioComponentInstance unit = AudioStream_unit(self);
    if (unit != nullptr) {
        AudioUnitUninitialize(unit);
        AudioComponentInstanceDispose(unit);
        AudioStream_setUnit(self, nullptr);
    }
    AudioMemory_free(self);
}

;;GETTER
d64 AudioStream_getSampleRate(const AudioStream *self) {
    return self ? (*self).sampleRate : 0.0;
}

;;GETTER
u32 AudioStream_getChannels(const AudioStream *self) {
    return self ? (*self).channels : 0u;
}

;;GETTER
u32 AudioStream_getFramesPerBlock(const AudioStream *self) {
    return self ? (*self).framesPerBlock : 0u;
}

d64 AudioStream_getLatencyMs(const AudioStream *self) {
    d64 sampleRate = AudioStream_getSampleRate(self);
    u32 framesPerBlock = AudioStream_getFramesPerBlock(self);
    if (self == nullptr || sampleRate <= 0.0 || framesPerBlock == 0u)
        return 0.0;
    return (1000.0 * (d64) framesPerBlock) / sampleRate;
}

fn AudioStream_toString(const AudioStream *self, char *dest, bytes cap, bool *outTruncated) {
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
    i32 n = snprintf(dest, cap, "AudioStream(%s, %.1f Hz, %u ch, %.2f ms)",
                     AudioStream_isRunning(self) ? "running" : "stopped",
                     AudioStream_getSampleRate(self), AudioStream_getChannels(self),
                     AudioStream_getLatencyMs(self));
    if (outTruncated && n >= 0 && (bytes) n >= cap)
        *outTruncated = true;
}

fn AudioStream_toStringStruct(const AudioStream *self, char *dest, bytes cap, bool *outTruncated) {
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
                     "AudioStream { unit: %s, running: %s, sampleRate: %.1f, channels: %u, framesPerBlock: %u, callback: %s }",
                     AudioStream_unit(self) ? "open" : "closed",
                     AudioStream_isRunning(self) ? "true" : "false",
                     AudioStream_getSampleRate(self), AudioStream_getChannels(self),
                     AudioStream_getFramesPerBlock(self),
                     AudioStream_callback(self) ? "set" : "none");
    if (outTruncated && n >= 0 && (bytes) n >= cap)
        *outTruncated = true;
}
