#import <AVFoundation/AVFoundation.h>

#include "vex.h"
#include <math.h>
#include <string.h>

#include "audio/audio.h"

#include "nio/mem.h"
#include "oop/oop.h"

;;DEFINITION
/**
 * ============================================================================
 * DEFINITION: Audio_cocoa
 * ============================================================================
 * The macOS AVFoundation backend of audio.h: one shared AVAudioEngine plus
 * one AVAudioPlayerNode per voice, with clips as AVAudioPCMBuffers decoded
 * from disk via AVAudioFile or synthesized sine tones for tests and
 * chiptunes. The engine refuses to start with zero attached nodes, so init
 * only constructs it and the first voice attachment flips it live. All
 * Objective-C objects are ARC-managed; the C-side AudioClip/AudioVoice/Audio
 * handles are arena-allocated and must be freed through their Audio*_free
 * seams so nodes detach before the block is reclaimed.
 * ============================================================================
 */

;;OVERVIEW
/**
 * ============================================================================
 * MODULE: Audio_cocoa (objc/audio_cocoa.m)
 * ============================================================================
 * AVFoundation backend (the macOS half of audio.h).
 *
 * STRUCT FIELDS (local to this file):
 * ----------------------------------------------------------------------------
 *   AudioClip {
 *     AVAudioPCMBuffer *buffer; // decoded or synthesized PCM block
 *     f32 seconds;            // clip duration in seconds
 *   }
 *   AudioVoice {
 *     AVAudioPlayerNode *node;  // attached player node
 *     AudioClip *clip;          // currently assigned clip
 *     bool active;              // buffer scheduled and play() pressed
 *     bool looping;             // loop flag for schedule options
 *   }
 *   Audio {
 *     AVAudioPCMBuffer *buffer; // loaded PCM block
 *     AVAudioPlayerNode *node;  // wired player node
 *     bool active;              // play state
 *     bool looping;             // loop flag
 *     f32 gain;               // volume 0.0 .. 1.0+
 *     f32 pitch;              // rate 1.0 = native
 *     d64 rate;              // sample rate
 *     i32 channels;             // AUDIO_MONO / AUDIO_STEREO
 *   }
 *
 * FUNCTION REGISTRY:
 * ----------------------------------------------------------------------------
 * Constructors:
 *   - Audio_init()
 *   - AudioVoice()
 *   - Audio_0()
 *   - Audio_2(sampleRate, channels)
 *
 * Core Functions:
 *   - sharedEngine()
 *   - ensureRunning()
 *   - Audio_shutdown()
 *   - clipAlloc(seconds)
 *   - AudioClip_load(path)
 *   - AudioClip_tone(frequencyHz, seconds)
 *   - for(i++)
 *   - AudioClip_free(clip)
 *   - Memory_free(clip)
 *   - AudioClip_seconds(clip)
 *   - AudioVoice_free(voice)
 *   - AudioVoice_play(voice)
 *   - AudioVoice_pause(voice)
 *   - AudioVoice_stop(voice)
 *   - audioInitFields(a, rate, channels)
 *   - audioWireUp(a)
 *   - Audio_withRate(sampleRate)
 *   - Audio_load(path)
 *   - Audio_play(a)
 *   - Audio_pause(a)
 *   - Audio_stop(a)
 *   - Audio_free(a)
 *
 * Setters:
 *   - AudioVoice_setClip(voice, clip)
 *   - AudioVoice_setGain(voice, gain)
 *   - AudioVoice_setPitch(voice, pitch)
 *   - AudioVoice_setLooping(voice, looping)
 *   - Audio_setGain(a, gain)
 *   - Audio_setPitch(a, pitch)
 *   - Audio_setLooping(a, looping)
 *   - Audio_setSampleRate(a, rate)
 *   - Audio_setChannels(a, channels)
 *
 * Getters:
 *   - Audio_isReady()
 *   - AudioVoice_isPlaying(voice)
 *   - Audio_isPlaying(a)
 *   - Audio_getGain(a)
 *   - Audio_getPitch(a)
 *   - Audio_getLooping(a)
 *   - Audio_getSampleRate(a)
 *   - Audio_getChannels(a)
 * ============================================================================
 */


// audio/audio_cocoa.m — AVFoundation backend (the macOS half of audio.h).
//
// One shared AVAudioEngine; one AVAudioPlayerNode per voice. Clips are
// AVAudioPCMBuffers, either decoded from disk via AVAudioFile or synthesized
// sine waves for tests and chiptunes. Compiled with -fobjc-arc (see CMake).

static AVAudioEngine *s_engine = nullptr;
static bool s_ready = false;

typedef struct AudioClip {
    AVAudioPCMBuffer *buffer;
    f32 seconds;
} AudioClip;

typedef struct AudioVoice {
    AVAudioPlayerNode *node;
    AudioClip *clip;
    bool active;      // a buffer was scheduled and play() pressed
    bool looping;
} AudioVoice;

;;GETTER
static inline AVAudioPCMBuffer *AudioClip_buffer(const AudioClip *self) { return (*self).buffer; }
;;SETTER
static inline fn AudioClip_setBuffer(AudioClip *self, AVAudioPCMBuffer *buffer) { (*self).buffer = buffer; }
;;SETTER
static inline fn AudioClip_setSeconds(AudioClip *self, f32 seconds) { (*self).seconds = seconds; }

;;GETTER
static inline AVAudioPlayerNode *AudioVoice_node(const AudioVoice *self) { return (*self).node; }
;;SETTER
static inline fn AudioVoice_setNode(AudioVoice *self, AVAudioPlayerNode *node) { (*self).node = node; }
;;GETTER
static inline AudioClip *AudioVoice_clip(const AudioVoice *self) { return (*self).clip; }
;;GETTER
static inline bool AudioVoice_active(const AudioVoice *self) { return (*self).active; }
;;SETTER
static inline fn AudioVoice_setActive(AudioVoice *self, bool active) { (*self).active = active; }
;;GETTER
static inline bool AudioVoice_looping(const AudioVoice *self) { return (*self).looping; }

// The engine refuses to start with zero attached nodes, so init only
// constructs it; the first voice attachment flips it live (ensureRunning).
static AVAudioEngine *sharedEngine() {
    if (!s_engine)
        s_engine = [[AVAudioEngine alloc] init];
    return s_engine;
}

static bool ensureRunning() {
    AVAudioEngine *engine = sharedEngine();
    if (!engine || engine.isRunning)
        return engine != nullptr;
    __block bool ok = true;
    @try {
        ok = [engine startAndReturnError:nullptr];
    } @catch (NSException *e) {
        ok = false;
    }
    return ok;
}

bool Audio_init() {
    @autoreleasepool {
        s_ready = sharedEngine() != nullptr;
        return s_ready;
    }
}

fn Audio_shutdown() {
    if (!s_ready)
        return;
    [s_engine stop];
    s_engine = nullptr;
    s_ready = false;
}

bool Audio_isReady() {
    return s_ready;
}

static AudioClip *clipAlloc(f32 seconds) {
    AudioClip *clip = (AudioClip*) Memory_alloc(TYPE_AUDIO_CLIP_SINGLETON, sizeof(AudioClip));
    if (clip) {
        AudioClip_setBuffer(clip, nullptr);
        AudioClip_setSeconds(clip, seconds);
    }
    return clip;
}

AudioClip *AudioClip_load(const char *path) {
    if (!path || !s_ready)
        return nullptr;
    @autoreleasepool {
        NSString *nsPath = [NSString stringWithUTF8String:path];
        NSURL *url = [NSURL fileURLWithPath:nsPath];
        AVAudioFile *file = [[AVAudioFile alloc] initForReading:url error:nullptr];
        if (!file)
            return nullptr;

        AVAudioFormat *format = [file processingFormat];
        AVAudioFrameCount frames = (AVAudioFrameCount)[file length];
        if (frames == 0)
            return nullptr;

        AVAudioPCMBuffer *buf = [[AVAudioPCMBuffer alloc]
            initWithPCMFormat:format frameCapacity:frames];
        if (!buf)
            return nullptr;
        if (![file readIntoBuffer:buf error:nullptr] || buf.frameLength == 0)
            return nullptr;

        d64 secs = (d64)frames / (d64)format.sampleRate;
        AudioClip *clip = clipAlloc((f32)secs);
        if (!clip)
            return nullptr;
        AudioClip_setBuffer(clip, buf);
        return clip;
    }
}

AudioClip *AudioClip_tone(f32 frequencyHz, f32 seconds) {
    if (!s_ready || seconds <= 0.0f || frequencyHz <= 0.0f)
        return nullptr;
    @autoreleasepool {
        AVAudioFormat *format = [[s_engine outputNode] outputFormatForBus:0];
        d64 rate = (d64)format.sampleRate;
        AVAudioFrameCount frames = (AVAudioFrameCount)(rate * (d64)seconds);

        AVAudioPCMBuffer *buf = [[AVAudioPCMBuffer alloc]
            initWithPCMFormat:format frameCapacity:frames];
        if (!buf)
            return nullptr;
        buf.frameLength = frames;

        f32 *left = buf.floatChannelData[0];
        for (AVAudioFrameCount i = 0; i < frames; i++) {
            left[i] = sinf(2.0f * (f32)M_PI * frequencyHz * (f32)i / (f32)rate);
        }
        // mono source into N channels
        i32 channels = (i32)format.channelCount;
        for (i32 c = 1; c < channels; c++) {
            f32 *ch = buf.floatChannelData[c];
            memcpy(ch, left, frames * sizeof(f32));
        }

        AudioClip *clip = clipAlloc(seconds);
        if (!clip)
            return nullptr;
        AudioClip_setBuffer(clip, buf);
        return clip;
    }
}

fn AudioClip_free(AudioClip *clip) {
    if (!clip)
        return;
    AudioClip_setBuffer(clip, nullptr);
    Memory_free(clip);
}

;;GETTER
f32 AudioClip_seconds(AudioClip *clip) {
    return clip ? (*clip).seconds : 0.0f;
}

// --- macOS 27 API carry (the Platform Support Floor Law) ---------------------
// AVAudioEngine gained the error-returning connect:to:format:error:, and
// AVAudioPlayerNode gained playAndReturnError:, in macOS 27. The floor is 14.0,
// so those are reached only on 27+; the pre-27 arms below carry the floor (their
// deprecation on the 27 SDK is silenced narrowly, not globally).

// DEPRECATED-CARRY(connect:to:format: -> connect:to:format:error:, floor 14)
static fn audioConnect(AVAudioEngine *engine, AVAudioNode *node,
                         AVAudioNode *dest, AVAudioFormat *format) {
#if defined(__MAC_27_0) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 270000
    if (@available(macOS 27.0, *)) {
        (discard) [engine connect:node to:dest format:format error:nullptr];
        return;
    }
#endif
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [engine connect:node to:dest format:format];
#pragma clang diagnostic pop
}

// DEPRECATED-CARRY(play -> playAndReturnError:, floor 14)
static bool audioNodePlay(AVAudioPlayerNode *node) {
#if defined(__MAC_27_0) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 270000
    if (@available(macOS 27.0, *))
        return [node playAndReturnError:nullptr];
#endif
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [node play];
#pragma clang diagnostic pop
    return true;
}

AudioVoice *AudioVoice_0() {
    if (!s_ready)
        return nullptr;
    @autoreleasepool {
        AudioVoice *v = (AudioVoice*) Memory_alloc(TYPE_AUDIO_VOICE_SINGLETON, sizeof(AudioVoice));
        if (!v)
            return nullptr;
        AVAudioPlayerNode *node = [[AVAudioPlayerNode alloc] init];
        if (!node) {
            Memory_free(v);
            return nullptr;
        }
        AudioVoice_setNode(v, node);
        [s_engine attachNode:node];
        AVAudioFormat *out = [[s_engine outputNode] outputFormatForBus:0];
        audioConnect(s_engine, node, [s_engine mainMixerNode], out);
        if (!ensureRunning()) {
            [s_engine detachNode:node];
            Memory_free(v);
            return nullptr;
        }
        AudioVoice_setClip(v, nullptr);
        AudioVoice_setActive(v, false);
        AudioVoice_setLooping(v, false);
        return v;
    }
}

fn AudioVoice_free(AudioVoice *voice) {
    if (!voice)
        return;
    @autoreleasepool {
        AVAudioPlayerNode *node = AudioVoice_node(voice);
        [node stop];
        [s_engine detachNode:node];
    }
    AudioVoice_setNode(voice, nullptr);
    Memory_free(voice);
}

fn AudioVoice_setClip(AudioVoice *voice, AudioClip *clip) {
    if (!voice)
        return;
    (*voice).clip = clip;
}

fn AudioVoice_setGain(AudioVoice *voice, f32 gain) {
    if (!voice)
        return;
    [AudioVoice_node(voice) setVolume:gain];
}

fn AudioVoice_setPitch(AudioVoice *voice, f32 pitch) {
    if (!voice || pitch <= 0.0f)
        return;
    [AudioVoice_node(voice) setRate:pitch];
}

fn AudioVoice_setLooping(AudioVoice *voice, bool looping) {
    if (!voice)
        return;
    (*voice).looping = looping;
}

fn AudioVoice_play(AudioVoice *voice) {
    AudioClip *clip = voice ? AudioVoice_clip(voice) : nullptr;
    if (!voice || !clip)
        return;
    @autoreleasepool {
        AVAudioPCMBuffer *buf = AudioClip_buffer(clip);
        AVAudioPlayerNode *node = AudioVoice_node(voice);
        AVAudioPlayerNodeBufferOptions opts = AudioVoice_looping(voice)
            ? AVAudioPlayerNodeBufferLoops
            : AVAudioPlayerNodeBufferInterrupts;
        [node scheduleBuffer:buf atTime:nil options:opts completionHandler:nil];
        if (!audioNodePlay(node))
            return;
        AudioVoice_setActive(voice, true);
    }
}

fn AudioVoice_pause(AudioVoice *voice) {
    if (!voice)
        return;
    [AudioVoice_node(voice) pause];
}

fn AudioVoice_stop(AudioVoice *voice) {
    if (!voice)
        return;
    [AudioVoice_node(voice) stop];
    AudioVoice_setActive(voice, false);
}

bool AudioVoice_isPlaying(AudioVoice *voice) {
    if (!voice || !AudioVoice_active(voice))
        return false;
    AVAudioPlayerNode *node = AudioVoice_node(voice);
    return node != nullptr && [(AVAudioPlayerNode*) node isPlaying];
}

// --- Audio: one-handle class -------------------------------------------------

typedef struct Audio {
    AVAudioPCMBuffer *buffer;
    AVAudioPlayerNode *node;
    bool active;
    bool looping;
    f32 gain;
    f32 pitch;
    d64 rate;
    i32 channels;
} Audio;

;;GETTER
static inline AVAudioPCMBuffer *Audio_buffer(const Audio *self) { return (*self).buffer; }
;;SETTER
static inline fn Audio_setBuffer(Audio *self, AVAudioPCMBuffer *buffer) { (*self).buffer = buffer; }
;;SETTER
static inline fn Audio_setNode(Audio *self, AVAudioPlayerNode *node) { (*self).node = node; }
;;GETTER
static inline bool Audio_active(const Audio *self) { return (*self).active; }
;;SETTER
static inline fn Audio_setActive(Audio *self, bool active) { (*self).active = active; }
;;SETTER
static inline fn Audio_setGainField(Audio *self, f32 gain) { (*self).gain = gain; }
;;SETTER
static inline fn Audio_setPitchField(Audio *self, f32 pitch) { (*self).pitch = pitch; }

static fn audioInitFields(Audio *a, d64 rate, i32 channels) {
    Audio_setBuffer(a, nullptr);
    Audio_setNode(a, nullptr);
    Audio_setActive(a, false);
    Audio_setLooping(a, false);
    Audio_setGainField(a, 1.0f);
    Audio_setPitchField(a, 1.0f);
    Audio_setSampleRate(a, rate > 0.0 ? rate : 44100.0);
    Audio_setChannels(a, (channels == AUDIO_MONO || channels == AUDIO_STEREO) ? channels : AUDIO_STEREO);
}

static bool audioWireUp(Audio *a) {
    AVAudioPlayerNode *node = [[AVAudioPlayerNode alloc] init];
    if (!node)
        return false;
    [s_engine attachNode:node];
    AVAudioFormat *fmt = [[s_engine outputNode] outputFormatForBus:0];
    audioConnect(s_engine, node, [s_engine mainMixerNode], fmt);
    if (!ensureRunning()) {
        [s_engine detachNode:node];
        return false;
    }
    Audio_setNode(a, node);
    return true;
}

Audio *Audio_0() {
    if (!s_ready)
        return nullptr;
    @autoreleasepool {
        Audio *a = (Audio*) Memory_alloc(TYPE_AUDIO_SINGLETON, sizeof(Audio));
        if (!a)
            return nullptr;
        audioInitFields(a, 44100.0, AUDIO_STEREO);
        return a;
    }
}

Audio *Audio_withRate(d64 sampleRate) {
    Audio *a = Audio_0();
    if (a)
        Audio_setSampleRate(a, sampleRate > 0.0 ? sampleRate : 44100.0);
    return a;
}

Audio *Audio_2(d64 sampleRate, i32 channels) {
    Audio *a = Audio_withRate(sampleRate);
    if (a && (channels == AUDIO_MONO || channels == AUDIO_STEREO))
        Audio_setChannels(a, channels);
    return a;
}

Audio *Audio_load(const char *path) {
    if (!path || !s_ready)
        return nullptr;
    @autoreleasepool {
        NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:path]];
        AVAudioFile *file = [[AVAudioFile alloc] initForReading:url error:nullptr];
        if (!file)
            return nullptr;

        AVAudioFormat *format = [file processingFormat];
        AVAudioFrameCount frames = (AVAudioFrameCount)[file length];
        if (frames == 0)
            return nullptr;

        AVAudioPCMBuffer *buf = [[AVAudioPCMBuffer alloc]
            initWithPCMFormat:format frameCapacity:frames];
        if (!buf)
            return nullptr;
        if (![file readIntoBuffer:buf error:nullptr] || buf.frameLength == 0)
            return nullptr;

        Audio *a = Audio_0();
        if (!a)
            return nullptr;
        Audio_setBuffer(a, buf);
        Audio_setSampleRate(a, format.sampleRate);
        Audio_setChannels(a, (i32)format.channelCount);
        if (!audioWireUp(a)) {
            Memory_free(a);
            return nullptr;
        }
        return a;
    }
}

fn Audio_play(Audio *a) {
    AVAudioPCMBuffer *buf = a ? Audio_buffer(a) : nullptr;
    AVAudioPlayerNode *node = a ? Audio_node(a) : nullptr;
    if (!a || !buf || !node)
        return;
    AVAudioPlayerNodeBufferOptions opts = Audio_getLooping(a)
        ? AVAudioPlayerNodeBufferLoops
        : AVAudioPlayerNodeBufferInterrupts;
    [node scheduleBuffer:buf atTime:nil options:opts completionHandler:nil];
    if (!audioNodePlay(node))
        return;
    Audio_setActive(a, true);
}

fn Audio_pause(Audio *a) {
    AVAudioPlayerNode *node = Audio_node(a);
    if (a && node)
        [node pause];
}

fn Audio_stop(Audio *a) {
    AVAudioPlayerNode *node = Audio_node(a);
    if (!a || !node)
        return;
    [node stop];
    Audio_setActive(a, false);
}

bool Audio_isPlaying(Audio *a) {
    AVAudioPlayerNode *node = Audio_node(a);
    if (!a || !Audio_active(a) || !node)
        return false;
    return [(AVAudioPlayerNode*) node isPlaying];
}

;;GETTER
static AVAudioPlayerNode *Audio_node(Audio *a) {
    return a ? (*a).node : nullptr;
}

;;SETTER
static fn AVAudioPlayerNode_setVolume(AVAudioPlayerNode *node, f32 volume) {
    if (node)
        [node setVolume:volume];
}

;;SETTER
static fn AVAudioPlayerNode_setRate(AVAudioPlayerNode *node, f32 rate) {
    if (node)
        [node setRate:rate];
}

fn Audio_setGain(Audio *a, f32 gain) {
    if (!a)
        return;
    (*a).gain = gain;
    AVAudioPlayerNode_setVolume(Audio_node(a), gain);
}

;;GETTER
f32 Audio_getGain(Audio *a) {
    return a ? (*a).gain : 0.0f;
}

fn Audio_setPitch(Audio *a, f32 pitch) {
    if (!a || pitch <= 0.0f)
        return;
    (*a).pitch = pitch;
    AVAudioPlayerNode_setRate(Audio_node(a), pitch);
}

;;GETTER
f32 Audio_getPitch(Audio *a) {
    return a ? (*a).pitch : 1.0f;
}

fn Audio_setLooping(Audio *a, bool looping) {
    if (a)
        (*a).looping = looping;
}

;;GETTER
bool Audio_getLooping(Audio *a) {
    return a ? (*a).looping : false;
}

;;SETTER
fn Audio_setSampleRate(Audio *a, d64 rate) {
    if (!a || rate <= 0.0)
        return;
    (*a).rate = rate;
}

;;GETTER
d64 Audio_getSampleRate(Audio *a) {
    return a ? (*a).rate : 0.0;
}

;;SETTER
fn Audio_setChannels(Audio *a, i32 channels) {
    if (!a || (channels != AUDIO_MONO && channels != AUDIO_STEREO))
        return;
    (*a).channels = channels;
}

;;GETTER
i32 Audio_getChannels(Audio *a) {
    return a ? (*a).channels : 0;
}

fn Audio_free(Audio *a) {
    if (!a)
        return;
    @autoreleasepool {
        AVAudioPlayerNode *node = Audio_node(a);
        if (node) {
            [node stop];
            [s_engine detachNode:node];
        }
    }
    Audio_setNode(a, nullptr);
    Audio_setBuffer(a, nullptr);
    Memory_free(a);
}
