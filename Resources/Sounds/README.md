# Sound Files

## Ambient loops (Ascent feature)

| File | Source | License |
|---|---|---|
| `ambient_rain.caf` | BigSoundBank #1019 — "Summer Rain on Terrace" by Joseph SARDIN (2:37, trimmed to 30s loop) | CC0 (public domain) |
| `ambient_fire.caf` | BigSoundBank #2857 — "Fireplace #5" by Joseph SARDIN (0:46, trimmed to 30s loop) | CC0 (public domain) |
| `ambient_focus.caf` | BigSoundBank #0432 — "Pink Noise" by Joseph SARDIN (19s, full) | CC0 (public domain) |

All three are CC0: commercial use permitted, no attribution required.
Source pages: https://bigsoundbank.com/summer-rain-on-terrace-s1019.html ·
https://bigsoundbank.com/fireplace-5-s2857.html ·
https://bigsoundbank.com/pink-noise-s0432.html

Regenerate from source MP3s (in `~/dev/verg/download/sounds/`):
```
ffmpeg -i rain.mp3 -t 30 -af "afade=t=in:d=1,afade=t=out:st=29:d=1" rain-30.wav
afconvert rain-30.wav ambient_rain.caf -d LEI16@44100 -c 2
# same shape for fire; focus keeps its natural length with soft fades
```

Originals kept out of the repo in `download/sounds/`.

---

## Legacy notes (bell sounds)

The app requires the following audio files. If not present, the app will fall back to system sounds.

### 1. bell_start.mp3
- **Purpose**: Plays when the timer begins
- **Description**: A soft, single bell or singing bowl chime
- **Duration**: 1-2 seconds
- **Style**: Meditative, calming, not jarring

### 2. bell_end.mp3
- **Purpose**: Plays when the timer completes
- **Description**: A celebratory triple bell chime or sequence
- **Duration**: 2-3 seconds
- **Style**: Triumphant but still calm, indicating completion

## Recommended Sources for Royalty-Free Sounds

1. **Freesound.org** - Free with attribution
2. **Pixabay.com/sound-effects** - Free for commercial use
3. **Zapsplat.com** - Free with attribution
4. **Mixkit.co** - Free for commercial use

## Technical Requirements

- Format: MP3 (preferred) or WAV
- Sample Rate: 44.1kHz
- Bit Depth: 16-bit
- Channels: Mono or Stereo

## Adding to Xcode Project

1. Download or create the audio files
2. Rename to `bell_start.mp3` and `bell_end.mp3`
3. Drag into this folder in Xcode
4. Ensure "Copy items if needed" is checked
5. Ensure the Ink target is selected in "Add to targets"

## Fallback Behavior

If audio files are missing, the AudioService will play:
- bell_start: System sound 1013 (pleasant chime)
- bell_end: System sound 1025 (completion sound)
