#import "audio/audio_hal.h"

#import <AudioToolbox/AudioToolbox.h>
#import <CoreAudio/CoreAudio.h>

#include "vex.h"
#include <stdlib.h>
#include <string.h>


;;DEFINITION
/**
 * ============================================================================
 * DEFINITION: AudioHal_mac
 * ============================================================================
 * macOS native CoreAudio HAL output unit bridge: creates a default-output
 * AudioUnit with f32 PCM stream format and a render callback that feeds
 * real-time DSP straight into hardware output at minimal buffer latency. The
 * AudioHal struct is heap-allocated (malloc/free) because it must outlive
 * the caller's stack and is owned by the audio subsystem; destroy stops the
 * unit, uninitializes and disposes the AudioComponentInstance, then frees.
 * The render callback runs on the audio thread and must never block or
 * allocate — it calls the registered AudioHalRenderCallback or zero-fills.
 * ============================================================================
 */

;;OVERVIEW
/**
 * ============================================================================
 * MODULE: AudioHal_mac (objc/audio_hal_mac.m)
 * ============================================================================
 * macOS native CoreAudio HAL output unit bridge for real-time DSP feeding
 * into hardware output with minimal buffer latency.
 *
 * STRUCT FIELDS:
 *   - AudioHal: AudioUnit, is_running, sample_rate, channels, buffer_frames,
 *               callback, user_data
 *
 * FUNCTION REGISTRY:
 * ----------------------------------------------------------------------------
 * Constructors:
 *   - AudioHalConfig_0()
 *   - AudioHalConfig_1(callback)
 *   - AudioHalConfig_2(callback, user_data)
 *   - AudioHal_0()
 *   - AudioHal_1(config)
 * Lifecycle & Stream Control:
 *   - AudioHal_start(hal)
 *   - AudioHal_stop(hal)
 *   - AudioHal_destroy(hal)
 * Metrics:
 *   - AudioHal_is_running(hal)
 *   - AudioHal_get_sample_rate(hal)
 *   - AudioHal_get_channels(hal)
 *   - AudioHal_get_buffer_frames(hal)
 *   - AudioHal_get_latency_ms(hal)
 * ============================================================================
 */

;;INTENTION("Direct CoreAudio AudioUnit HAL output engine for real-time low-latency DSP")

struct AudioHal {
    AudioComponentInstance audio_unit;
    bool is_running;
    d64 sample_rate;
    u32 channels;
    u32 buffer_frames;
    AudioHalRenderCallback callback;
    any user_data;
};

;;GETTER
static inline AudioComponentInstance AudioHal_audio_unit(const AudioHal *self) { return (*self).audio_unit; }
;;SETTER
static inline fn AudioHal_setAudio_unit(AudioHal *self, AudioComponentInstance audio_unit) { (*self).audio_unit = audio_unit; }
;;SETTER
static inline fn AudioHal_setIs_running(AudioHal *self, bool is_running) { (*self).is_running = is_running; }
;;SETTER
static inline fn AudioHal_setSample_rate(AudioHal *self, d64 sample_rate) { (*self).sample_rate = sample_rate; }
;;SETTER
static inline fn AudioHal_setChannels(AudioHal *self, u32 channels) { (*self).channels = channels; }
;;SETTER
static inline fn AudioHal_setBuffer_frames(AudioHal *self, u32 buffer_frames) { (*self).buffer_frames = buffer_frames; }
;;GETTER
static inline AudioHalRenderCallback AudioHal_callback(const AudioHal *self) { return (*self).callback; }
;;SETTER
static inline fn AudioHal_setCallback(AudioHal *self, AudioHalRenderCallback callback) { (*self).callback = callback; }
;;GETTER
static inline any AudioHal_user_data(const AudioHal *self) { return (*self).user_data; }
;;SETTER
static inline fn AudioHal_setUser_data(AudioHal *self, any user_data) { (*self).user_data = user_data; }
;;GETTER
static inline UInt32 AudioBufferList_mNumberBuffers(const AudioBufferList *self) { return (*self).mNumberBuffers; }
;;GETTER
static inline void *AudioBufferList_mBuffers0Data(const AudioBufferList *self) { return (*self).mBuffers[0].mData; }

AudioHalConfig AudioHalConfig_0() {
    AudioHalConfig cfg;
    cfg.sample_rate = 48000.0;
    cfg.channels = 2;
    cfg.buffer_frames = 256;
    cfg.callback = nullptr;
    cfg.user_data = nullptr;
    return cfg;
}

AudioHalConfig AudioHalConfig_1(AudioHalRenderCallback callback) {
    return AudioHalConfig_2(callback, nullptr);
}

AudioHalConfig AudioHalConfig_2(AudioHalRenderCallback callback, any user_data) {
    AudioHalConfig cfg = AudioHalConfig_0();
    cfg.callback = callback;
    cfg.user_data = user_data;
    return cfg;
}

;;SETTER
static inline fn AudioHalConfig_setSample_rate(AudioHalConfig *self, d64 sample_rate) { (*self).sample_rate = sample_rate; }
;;SETTER
static inline fn AudioHalConfig_setChannels(AudioHalConfig *self, u32 channels) { (*self).channels = channels; }
;;SETTER
static inline fn AudioHalConfig_setBuffer_frames(AudioHalConfig *self, u32 buffer_frames) { (*self).buffer_frames = buffer_frames; }

bool AudioHalConfig_set_sample_rate(AudioHalConfig *config, d64 sample_rate) {
    if (!config || sample_rate <= 0.0) return false;
    AudioHalConfig_setSample_rate(config, sample_rate);
    return true;
}

bool AudioHalConfig_set_channels(AudioHalConfig *config, u32 channels) {
    if (!config || channels == 0) return false;
    AudioHalConfig_setChannels(config, channels);
    return true;
}

bool AudioHalConfig_set_buffer_frames(AudioHalConfig *config, u32 buffer_frames) {
    if (!config || buffer_frames == 0) return false;
    AudioHalConfig_setBuffer_frames(config, buffer_frames);
    return true;
}

static OSStatus audio_hal_render_proc(
    any inRefCon,
    AudioUnitRenderActionFlags *ioActionFlags,
    const AudioTimeStamp *inTimeStamp,
    UInt32 inBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList *ioData
) {
    (discard) ioActionFlags;
    (discard) inTimeStamp;
    (discard) inBusNumber;

    AudioHal *hal = (AudioHal*) inRefCon;
    if (!hal || !ioData || AudioBufferList_mNumberBuffers(ioData) == 0) {
        return noErr;
    }

    f32 *out_buf = (f32*) AudioBufferList_mBuffers0Data(ioData);
    u32 channels = AudioHal_get_channels(hal);
    AudioHalRenderCallback cb = AudioHal_callback(hal);

    if (cb) {
        cb(out_buf, (u32) inNumberFrames, channels, AudioHal_user_data(hal));
    } else {
        bytes Bytes = (bytes) inNumberFrames * channels * sizeof(f32);
        memset(out_buf, 0, Bytes);
    }

    return noErr;
}

AudioHal *AudioHal_0() {
    return AudioHal_1(nullptr);
}

AudioHal *AudioHal_1(const AudioHalConfig *config) {
    AudioHalConfig cfg = config ? (*config) : AudioHalConfig_0();
    if (cfg.channels == 0 || cfg.sample_rate <= 0.0 || cfg.buffer_frames == 0) {
        return nullptr;
    }

    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_DefaultOutput;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;

    AudioComponent comp = AudioComponentFindNext(nullptr, &desc);
    if (!comp) {
        return nullptr;
    }

    AudioComponentInstance au = nullptr;
    OSStatus err = AudioComponentInstanceNew(comp, &au);
    if (err != noErr || !au) {
        return nullptr;
    }

    AudioStreamBasicDescription asbd;
    memset(&asbd, 0, sizeof(asbd));
    asbd.mSampleRate = cfg.sample_rate;
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
    asbd.mBytesPerPacket = cfg.channels * sizeof(f32);
    asbd.mFramesPerPacket = 1;
    asbd.mBytesPerFrame = cfg.channels * sizeof(f32);
    asbd.mChannelsPerFrame = cfg.channels;
    asbd.mBitsPerChannel = 32;

    err = AudioUnitSetProperty(
        au,
        kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Input,
        0,
        &asbd,
        sizeof(asbd)
    );
    if (err != noErr) {
        AudioComponentInstanceDispose(au);
        return nullptr;
    }

    AudioHal *hal = (AudioHal*) malloc(sizeof(AudioHal));
    if (!hal) {
        AudioComponentInstanceDispose(au);
        return nullptr;
    }

    AudioHal_setAudio_unit(hal, au);
    AudioHal_setIs_running(hal, false);
    AudioHal_setSample_rate(hal, cfg.sample_rate);
    AudioHal_setChannels(hal, cfg.channels);
    AudioHal_setBuffer_frames(hal, cfg.buffer_frames);
    AudioHal_setCallback(hal, cfg.callback);
    AudioHal_setUser_data(hal, cfg.user_data);

    AURenderCallbackStruct cb_struct;
    cb_struct.inputProc = audio_hal_render_proc;
    cb_struct.inputProcRefCon = (any) hal;

    err = AudioUnitSetProperty(
        au,
        kAudioUnitProperty_SetRenderCallback,
        kAudioUnitScope_Input,
        0,
        &cb_struct,
        sizeof(cb_struct)
    );
    if (err != noErr) {
        AudioComponentInstanceDispose(au);
        free(hal);
        return nullptr;
    }

    err = AudioUnitInitialize(au);
    if (err != noErr) {
        AudioComponentInstanceDispose(au);
        free(hal);
        return nullptr;
    }

    return hal;
}

bool AudioHal_start(AudioHal *hal) {
    AudioComponentInstance au = hal ? AudioHal_audio_unit(hal) : nullptr;
    if (!hal || !au) {
        return false;
    }
    if (AudioHal_is_running(hal)) {
        return true;
    }

    OSStatus err = AudioOutputUnitStart(au);
    if (err == noErr) {
        AudioHal_setIs_running(hal, true);
        return true;
    }
    return false;
}

bool AudioHal_stop(AudioHal *hal) {
    AudioComponentInstance au = hal ? AudioHal_audio_unit(hal) : nullptr;
    if (!hal || !au) {
        return false;
    }
    if (!AudioHal_is_running(hal)) {
        return true;
    }

    OSStatus err = AudioOutputUnitStop(au);
    if (err == noErr) {
        AudioHal_setIs_running(hal, false);
        return true;
    }
    return false;
}

fn AudioHal_destroy(AudioHal *hal) {
    if (!hal) {
        return;
    }
    if (AudioHal_is_running(hal)) {
        AudioHal_stop(hal);
    }
    AudioComponentInstance au = AudioHal_audio_unit(hal);
    if (au) {
        AudioUnitUninitialize(au);
        AudioComponentInstanceDispose(au);
        AudioHal_setAudio_unit(hal, nullptr);
    }
    free(hal);
}

;;GETTER
bool AudioHal_is_running(const AudioHal *hal) {
    return hal ? (*hal).is_running : false;
}

;;GETTER
d64 AudioHal_get_sample_rate(const AudioHal *hal) {
    return hal ? (*hal).sample_rate : 0.0;
}

;;GETTER
u32 AudioHal_get_channels(const AudioHal *hal) {
    return hal ? (*hal).channels : 0;
}

;;GETTER
u32 AudioHal_get_buffer_frames(const AudioHal *hal) {
    return hal ? (*hal).buffer_frames : 0;
}

d64 AudioHal_get_latency_ms(const AudioHal *hal) {
    d64 sr = AudioHal_get_sample_rate(hal);
    if (!hal || sr <= 0.0) {
        return 0.0;
    }
    return (1000.0 * (d64) AudioHal_get_buffer_frames(hal)) / sr;
}
