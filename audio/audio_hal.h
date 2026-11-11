#ifndef VEXSPOKE_AUDIO_AUDIO_HAL_H
#define VEXSPOKE_AUDIO_AUDIO_HAL_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "util/constructor.h"

#ifdef __cplusplus
extern "C" {
#endif

// Low-latency CoreAudio HAL Render Callback
// Invoked by the high-priority real-time audio thread.
typedef void (*AudioHalRenderCallback)(
    f32 *interleaved_output,
    u32 frame_count,
    u32 channels,
    void *user_data
);

typedef struct AudioHalConfig {
    d64 sample_rate;             // e.g. 44100.0, 48000.0, 96000.0
    u32 channels;              // 1 = mono, 2 = stereo
    u32 buffer_frames;         // e.g. 128, 256, 512
    AudioHalRenderCallback callback;// Real-time pull render callback
    void *user_data;
} AudioHalConfig;

typedef struct AudioHal AudioHal;

AudioHalConfig AudioHalConfig_0(void);
AudioHalConfig AudioHalConfig_1(AudioHalRenderCallback callback);
AudioHalConfig AudioHalConfig_2(AudioHalRenderCallback callback, void *user_data);
#define AudioHalConfig(...) CONSTRUCTOR_DISPATCH(AudioHalConfig, __VA_ARGS__)
bool AudioHalConfig_set_sample_rate(AudioHalConfig *config, d64 sample_rate);
bool AudioHalConfig_set_channels(AudioHalConfig *config, u32 channels);
bool AudioHalConfig_set_buffer_frames(AudioHalConfig *config, u32 buffer_frames);

AudioHal *AudioHal_0(void);
AudioHal *AudioHal_1(const AudioHalConfig *config);
#define AudioHal(...) CONSTRUCTOR_DISPATCH(AudioHal, __VA_ARGS__)

bool AudioHal_start(AudioHal *hal);
bool AudioHal_stop(AudioHal *hal);
void AudioHal_destroy(AudioHal *hal);

bool AudioHal_is_running(const AudioHal *hal);
d64 AudioHal_get_sample_rate(const AudioHal *hal);
u32 AudioHal_get_channels(const AudioHal *hal);
u32 AudioHal_get_buffer_frames(const AudioHal *hal);
d64 AudioHal_get_latency_ms(const AudioHal *hal);

#ifdef __cplusplus
}
#endif

#endif // VEXSPOKE_AUDIO_AUDIO_HAL_H
