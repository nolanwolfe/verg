# Sound Files Required

The Ink app requires the following audio files. If not present, the app will fall back to system sounds.

## Required Files

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
