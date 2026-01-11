# Granular Freeze Processor in FaustDSP

Granular freeze effect built in Faust. Incoming audio is written into a 10-second circular buffer while **Update Freeze** is held; releasing freezes the content and grains read from it. Two banks of up to 16 voices window each grain with a sine envelope. Mono input feeds the buffer; Bank A goes to left, Bank B (rate-shifted) to right for stereo width.

## Controls
- Master Vol (dB slider, -60..10): output gain, converted from dB. (01)
- Fixed Position (checkbox): off = random positions with Spread; on = use the Position slider. (02)
- Position (0..1): fixed buffer position when fixed mode is enabled. (03)
- Grain Size (ms slider, 10..500): grain length and base trigger rate (1000 / ms). (04)
- Spread (0..1): random offset range used when Fixed Position is off. (05)
- Voices (slider, 1..16): number of active voices per bank (affects both A and B). (06)
- Update Buffer (button): hold to record into the buffer; release to freeze current audio. (07)
- Play (LED): gates the output on/off. (08)

## Signal Flow
```
→ Mono input → 
→ freeze buffer [10 s] → 
→ granular voice banks (A at 1.0×, B at 1.03×) → 
→ gain [level]→ 
→ play [gate] → 
→ stereo out (A→L, B→R). 
```

Voices count applies per bank, so both channels stay audible at low settings. Update button advances the write head only while held.

## Notes
- Buffer size is fixed at 480000 samples (≈10 s at 48 kHz). Adjust `BUFFER_SIZE` if you change the sample rate or want a different duration.
- `VOICE_SCALE` is 0.25 to keep the mix clean with many voices active; raise cautiously if you use fewer voices.
- Random is the default position mode; toggle **Fixed Position** to park grains at the slider-defined point.

## How to use
Press **Update Buffer** to capture, and tweak **Voices**, **Grain Size**, **Spread**, or toggle **Fixed Position** to lock grains to the chosen Position.
