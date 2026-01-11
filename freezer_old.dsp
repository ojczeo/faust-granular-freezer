import("stdfaust.lib");

// buffer size in samples (10 seconds at 48kHz)
BUFFER_SIZE = 480000; // 10 seconds

// maximum voices count
MAX_VOICES = 16; 

// ui elements
play_active = checkbox("Play [style:led]");
update_btn  = button("Update Freeze");

// actuve voices count slider
active_voices_count = hslider("Voices", 1, 1, MAX_VOICES, 1);

// master gain control in dB
master_gain = hslider("Master Vol [unit:dB]", -3, -60, 10, 0.1) : ba.db2linear;

// scaling to prevent clipping when all voices are active
VOICE_SCALE = 0.25;

// default parameters
grain_size_ms = hslider("Grain Size [unit:ms]", 10, 10, 500, 1);
spread_amount = hslider("Spread", 0.005, 0.005, 1, 0.001);

grain_freq_base = 1000.0 / grain_size_ms;
grain_len_samples = (grain_size_ms / 1000.0) * ma.SR;

// buffer write logic
run = int(update_btn);
w_idx = (+(run) : %(BUFFER_SIZE)) ~ _;

// buffer read/write
shared_buffer(in_sig, r_idx) = rwtable(BUFFER_SIZE, 0.0, w_idx, in_sig, r_idx);

// voice logic
granular_voice(in_sig, rate_mod, voice_id) = output
with {
    local_freq = grain_freq_base * rate_mod;
    
    // Phase offset
    phase_offset = voice_id * 0.137; 
    phase = (os.phasor(1.0, local_freq) + phase_offset) : ma.decimal;
    trig = phase < phase';

    // Random position
    rand_pos_val = no.noise : ba.latch(trig) : abs; 
    
    // Voice on/off 
    voice_slot = voice_id % MAX_VOICES;
    should_play = (voice_slot < active_voices_count) : si.smoo;

    // Position calculations
    voice_shift = voice_slot * 900; 
    offset_samples = int(rand_pos_val * spread_amount * (BUFFER_SIZE - grain_len_samples - 2000)) + voice_shift;

    grain_start_pos = ba.latch(trig, w_idx);
    read_ptr_raw = grain_start_pos - offset_samples + (phase * grain_len_samples);
    my_r_idx = (int(read_ptr_raw) + BUFFER_SIZE) % BUFFER_SIZE;

    // buffer grain windowing
    window = sin(phase * ma.PI);

    // Output
    output = shared_buffer(in_sig, my_r_idx) * window * should_play;
};

// process
play_env = play_active : si.smoo;

process(in) = 
    in <: 
    // Sum voices, apply fixed scale and master volume
    (par(i, MAX_VOICES, granular_voice(_, 1.0, i)) :> _ : *(VOICE_SCALE) : *(master_gain)),
    (par(i, MAX_VOICES, granular_voice(_, 1.03, i + MAX_VOICES)) :> _ : *(VOICE_SCALE) : *(master_gain))
    : *(play_env), *(play_env);