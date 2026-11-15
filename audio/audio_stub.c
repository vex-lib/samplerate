#include "audio/audio.h"

// audio/audio_stub.c — the silence backend for platforms without the Cocoa
// seam yet. Same contract, zero sound: every handle fails to allocate and
// every control is a no-op, so callers stay identical across platforms.

#include "annotation/annotation.h"

;;DEFINITION
/**
 * ============================================================================
 * DEFINITION: Audio_stub
 * ============================================================================
 * The silence backend for platforms without the Cocoa seam yet. Same contract,
 * zero sound: every handle fails to allocate and every control is a no-op, so
 * callers stay identical across platforms. Keeps the Audio API surface
 * compilable and linkable on non-Apple hosts while the real backend lands;
 * marked ;;INCOMPLETE until Windows/X11 audio backends arrive.
 * ============================================================================
 */

;;OVERVIEW
/**
 * ============================================================================
 * MODULE: Audio_stub (audio/audio_stub.c)
 * ============================================================================
 * the silence backend for platforms without the Cocoa
 *
 * STRUCT FIELDS: none — procedural (operates on stub audio backend (no state))
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
 *   - Audio_shutdown()
 *   - AudioClip_load(path)
 *   - AudioClip_tone(frequencyHz, seconds)
 *   - AudioClip_free(clip)
 *   - AudioClip_seconds(clip)
 *   - AudioVoice_free(voice)
 *   - AudioVoice_play(voice)
 *   - AudioVoice_pause(voice)
 *   - AudioVoice_stop(voice)
 *   - Audio_load(path)
 *   - Audio_withRate(sampleRate)
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


;;INCOMPLETE // Windows/X11 audio backends land here; until then this platform
;;INCOMPLETE // is silent by design.

bool Audio_init() {
    return false;
}

fn Audio_shutdown() {
}

bool Audio_isReady() {
    return false;
}

AudioClip *AudioClip_load(const char *path) {
    (discard) path;
    return nullptr;
}

AudioClip *AudioClip_tone(f32 frequencyHz, f32 seconds) {
    (discard) frequencyHz;
    (discard) seconds;
    return nullptr;
}

fn AudioClip_free(AudioClip *clip) {
    (discard) clip;
}

f32 AudioClip_seconds(AudioClip *clip) {
    (discard) clip;
    return 0.0f;
}

AudioVoice *AudioVoice_0() {
    return nullptr;
}

fn AudioVoice_free(AudioVoice *voice) {
    (discard) voice;
}

fn AudioVoice_setClip(AudioVoice *voice, AudioClip *clip) {
    (discard) voice;
    (discard) clip;
}

fn AudioVoice_setGain(AudioVoice *voice, f32 gain) {
    (discard) voice;
    (discard) gain;
}

fn AudioVoice_setPitch(AudioVoice *voice, f32 pitch) {
    (discard) voice;
    (discard) pitch;
}

fn AudioVoice_setLooping(AudioVoice *voice, bool looping) {
    (discard) voice;
    (discard) looping;
}

fn AudioVoice_play(AudioVoice *voice) {
    (discard) voice;
}

fn AudioVoice_pause(AudioVoice *voice) {
    (discard) voice;
}

fn AudioVoice_stop(AudioVoice *voice) {
    (discard) voice;
}

bool AudioVoice_isPlaying(AudioVoice *voice) {
    (discard) voice;
    return false;
}

// --- Audio: one-handle class (silent backend) ---

Audio *Audio_0() {
    return nullptr;
}

Audio *Audio_load(const char *path) {
    (discard) path;
    return nullptr;
}

Audio *Audio_withRate(d64 sampleRate) {
    (discard) sampleRate;
    return nullptr;
}

Audio *Audio_2(d64 sampleRate, int channels) {
    (discard) sampleRate;
    (discard) channels;
    return nullptr;
}

fn Audio_play(Audio *a) {
    (discard) a;
}

fn Audio_pause(Audio *a) {
    (discard) a;
}

fn Audio_stop(Audio *a) {
    (discard) a;
}

bool Audio_isPlaying(Audio *a) {
    (discard) a;
    return false;
}

fn Audio_setGain(Audio *a, f32 gain) {
    (discard) a;
    (discard) gain;
}

f32 Audio_getGain(Audio *a) {
    (discard) a;
    return 0.0f;
}

fn Audio_setPitch(Audio *a, f32 pitch) {
    (discard) a;
    (discard) pitch;
}

f32 Audio_getPitch(Audio *a) {
    (discard) a;
    return 1.0f;
}

fn Audio_setLooping(Audio *a, bool looping) {
    (discard) a;
    (discard) looping;
}

bool Audio_getLooping(Audio *a) {
    (discard) a;
    return false;
}

fn Audio_setSampleRate(Audio *a, d64 rate) {
    (discard) a;
    (discard) rate;
}

d64 Audio_getSampleRate(Audio *a) {
    (discard) a;
    return 0.0;
}

fn Audio_setChannels(Audio *a, int channels) {
    (discard) a;
    (discard) channels;
}

int Audio_getChannels(Audio *a) {
    (discard) a;
    return 0;
}

fn Audio_free(Audio *a) {
    (discard) a;
}
