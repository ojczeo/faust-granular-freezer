import("stdfaust.lib");

// buffer size in samples (10 seconds at 48kHz)
BUFFER_SIZE = 480000; // 10 seconds

// maximum voices count
MAX_VOICES = 16; 

// voices scaling [to prevent clipping when all voices are active.]
// 0.25 is a safe value; with 16 voices it will be loud but clean.
VOICE_SCALE = 0.25;

// processing with ordered UI grouped for consistent layout
process(in) = vgroup("Granular Freeze Processor", outL, outR)
with {
    // Controls in desired order
    // master volume control
    master_gain = hslider("01 Master Vol [unit:dB]", -3, -60, 10, 0.1) : ba.db2linear; 
    // default random; toggle on to force fixed position mode
    position_mode_fixed = checkbox("02 Fixed Position"); 
    // deterministic buffer position (0..1)
    position_frac = hslider("03 Position", 0.5, 0, 1, 0.001); 
    // grain size in milliseconds
    grain_size_ms = hslider("04 Grain Size [unit:ms]", 100, 10, 500, 1);
    // random spread range (used only in random mode)
    spread_amount = hslider("05 Spread", 0.1, 0.0, 1, 0.001); 
    // number of active voices
    active_voices_count = hslider("06 Voices", 8, 1, MAX_VOICES, 1);
    // update buffer button
    update_btn  = button("07 Update Buffer");
    // play on/off
    play_active = checkbox("08 Play [style:led]");

    // Grain size calculations
    // grain rate base frequency
    grain_freq_base = 1000.0 / grain_size_ms;
    // grain length in samples
    grain_len_samples = (grain_size_ms / 1000.0) * ma.SR;

    // Update buffer only while "Update Buffer" is clicked
    // writing to buffer
    run = int(update_btn);
    // Buffer write index
    w_idx = (+(run) : %(BUFFER_SIZE)) ~ _;

    // Shared buffer for all voices
    shared_buffer(in_sig, r_idx) = rwtable(BUFFER_SIZE, 0.0, w_idx, in_sig, r_idx);

    // Voices logic
    granular_voice(in_sig, rate_mod, voice_id) = output
    with {
        // Per-voice phasor; wrap triggers grains
        local_freq = grain_freq_base * rate_mod;
        phase_offset = voice_id * 0.137; 
        phase = (os.phasor(1.0, local_freq) + phase_offset) : ma.decimal;
        trig = phase < phase';

        // Sample random position per grain
        rand_pos_val = no.noise : ba.latch(trig) : abs;

        // Voice slots (for toggling voices on/off when count changes)
        voice_slot = voice_id % MAX_VOICES;
        should_play = (voice_slot < active_voices_count) : si.smoo;

        // Position calculations (based on mode: fixed or random)
        voice_shift = voice_slot * 900; 
        fixed_offset = position_frac * (BUFFER_SIZE - grain_len_samples - 2000);
        random_offset = rand_pos_val * spread_amount * (BUFFER_SIZE - grain_len_samples - 2000);
        offset_samples = int(select2(position_mode_fixed, random_offset, fixed_offset)) + voice_shift;

        // Buffer: read position calculations
        grain_start_pos = ba.latch(trig, w_idx);
        read_ptr_raw = grain_start_pos - offset_samples + (phase * grain_len_samples);
        my_r_idx = (int(read_ptr_raw) + BUFFER_SIZE) % BUFFER_SIZE;
        
        // Windowed grain output
        window = sin(phase * ma.PI);
        output = shared_buffer(in_sig, my_r_idx) * window * should_play;
    };

    // smooth play on/off
    play_env = play_active : si.smoo;

    // Stereo output from two banks of voices read at slightly different rates hack
    bankA = (par(i, MAX_VOICES, granular_voice(in, 1.0, i)) :> _) * VOICE_SCALE * master_gain;
    bankB = (par(i, MAX_VOICES, granular_voice(in, 1.03, i + MAX_VOICES)) :> _) * VOICE_SCALE * master_gain;
    
    // Final output with play control
    outL = bankA * play_env;
    outR = bankB * play_env;
};