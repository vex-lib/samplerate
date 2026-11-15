#ifndef AUDIO_AUDIO_H
#define AUDIO_AUDIO_H

#include "vex.h"

// audio/audio.h — platform-agnostic audio API.
//
// The implementation is audio_cocoa.m (AVAudioEngine) on macOS and
// audio_stub.c (silence) elsewhere — the same seam pattern as window/.
// C callers never see Core Audio: opaque handles, load or synthesize a clip,
// route it through a voice, press play.
//
// Surface mirrors legacy audio/AudioSystem.java + AudioSource.java:
// pitch/gain/looping/play/pause/stop/isPlaying, minus the OpenAL ids.

// Opaque handles; contents live in the backend file.
typedef struct AudioClip AudioClip;
typedef struct AudioVoice AudioVoice;

bool Audio_init();        // start the shared output engine; idempotent
fn Audio_shutdown();
bool Audio_isReady();

// Clips: decoded media (wav/mp3/m4a/aiff) or synthesized tone. Blocks are
// self-describing; nullptr on failure.
AudioClip *AudioClip_load(const char *path);
AudioClip *AudioClip_tone(f32 frequencyHz, f32 seconds);
fn AudioClip_free(AudioClip *clip);
f32 AudioClip_seconds(AudioClip *clip);

// Voices: one player channel each. A voice holds at most one clip reference;
// re-set clips freely between plays.
AudioVoice *AudioVoice_0();
#define AudioVoice(...) CONSTRUCTOR_DISPATCH(AudioVoice, __VA_ARGS__)
fn AudioVoice_free(AudioVoice *voice);
fn AudioVoice_setClip(AudioVoice *voice, AudioClip *clip);
fn AudioVoice_setGain(AudioVoice *voice, f32 gain);    // 0.0 .. 1.0+
fn AudioVoice_setPitch(AudioVoice *voice, f32 pitch);  // 1.0 = native rate
fn AudioVoice_setLooping(AudioVoice *voice, bool looping);
fn AudioVoice_play(AudioVoice *voice);
fn AudioVoice_pause(AudioVoice *voice);
fn AudioVoice_stop(AudioVoice *voice);
bool AudioVoice_isPlaying(AudioVoice *voice);

// --- Audio: the one-handle class (constructor-overloaded) -------------------
//
//   Audio();                    // defaults — 44100 Hz, stereo, silent
//   Audio("hit.wav");           // decoded file, ready to play
//   Audio(22050);               // custom rate
//   Audio(48000, AUDIO_MONO);   // rate + channel tag
//
// One-arg calls resolve by TYPE: strings load files, numbers set the rate.

#define AUDIO_MONO   1
#define AUDIO_STEREO 2

typedef struct Audio Audio;

Audio *Audio_0();
Audio *Audio_load(const char *path);
Audio *Audio_withRate(d64 sampleRate);
Audio *Audio_2(d64 sampleRate, i32 channels);

#define Audio_1(a) _Generic((a),                    \
    char *: Audio_load,                             \
    const char *: Audio_load,                       \
    default: Audio_withRate)(a)

#define Audio(...) CONSTRUCTOR_DISPATCH(Audio, __VA_ARGS__)

// --- lifecycle ---
fn Audio_play(Audio *a);       // schedules and plays (loops if looping)
fn Audio_pause(Audio *a);
fn Audio_stop(Audio *a);
bool Audio_isPlaying(Audio *a);
fn Audio_free(Audio *a);       // final — detached and released

// --- setters / getters (the X in Audio_setX / Audio_getX) ---
fn Audio_setGain(Audio *a, f32 gain);
f32 Audio_getGain(Audio *a);
fn Audio_setPitch(Audio *a, f32 pitch);
f32 Audio_getPitch(Audio *a);
fn Audio_setLooping(Audio *a, bool looping);
bool Audio_getLooping(Audio *a);
fn Audio_setSampleRate(Audio *a, d64 rate);
d64 Audio_getSampleRate(Audio *a);
fn Audio_setChannels(Audio *a, i32 channels);
i32 Audio_getChannels(Audio *a);

#endif
