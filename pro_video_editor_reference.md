# pro_video_editor Reference

**Version:** 1.7.0 | **License:** BSD-3-Clause | **Publisher:** waio.ch
**Repo:** https://github.com/hm21/pro_video_editor
**No FFmpeg** — uses native APIs (Media3 on Android, AVFoundation on iOS/macOS)
**No platform setup required** — no AndroidManifest or Info.plist changes needed.

---

## Platform Support

| Feature | Android | iOS | macOS | Web |
|---|---|---|---|---|
| Metadata | ✅ | ✅ | ✅ | ✅ |
| Thumbnail / Keyframes | ✅ | ✅ | ✅ | ✅ |
| Trim / Merge | ✅ | ✅ | ✅ | ❌ |
| Crop / Rotate / Flip / Scale | ✅ | ✅ | ✅ | ❌ |
| Audio extraction | ✅ | ✅ | ✅ | ❌ |
| Waveform | ✅ | ✅ | ✅ | ❌ |
| Color filters / Blur | ✅ | ✅ | ✅ | ❌ |
| Progress tracking | ✅ | ✅ | ✅ | ✅ |
| Cancellation | ✅ | ✅ | ✅ | ❌ |

---

## Setup

```yaml
dependencies:
  pro_video_editor: ^1.7.0
```

```dart
import 'package:pro_video_editor/pro_video_editor.dart';

// All methods accessed via:
ProVideoEditor.instance
```

---

## Video Source — `EditorVideo`

```dart
EditorVideo.asset('assets/video.mp4')
EditorVideo.file(File('/path/to/video.mp4'))
EditorVideo.network('https://example.com/video.mp4')
EditorVideo.memory(Uint8List bytes)
```

---

## Core Render Config — `VideoRenderData`

All editing operations are configured here and passed to `renderVideo` / `renderVideoToFile`.

```dart
VideoRenderData(
  // Source — use ONE of:
  video: EditorVideo.file(file),              // single video
  videoSegments: [VideoSegment(...), ...],    // merge multiple clips

  // Trim
  startTime: Duration(seconds: 5),
  endTime: Duration(seconds: 20),

  // Audio
  enableAudio: true,
  originalAudioVolume: 0.5,           // 0.0–1.0, original audio level
  customAudioPath: '/path/music.mp3', // background music
  customAudioVolume: 0.8,             // 0.0–1.0
  loopCustomAudio: true,              // loop music if shorter than video

  // Speed
  playbackSpeed: 1.5,                 // 0.5 = slow-mo, 2.0 = fast

  // Quality
  bitrate: 5000000,                   // custom bitrate in bps

  // Effects
  blur: 10,                           // 0–100
  colorMatrixList: [ColorMatrix(...)],// color filters (4×5 matrix)

  // Transform
  transform: ExportTransform(
    x: 0, y: 0,                       // crop offset
    width: 1280, height: 720,         // crop size (null = full)
    rotateTurns: 1,                   // 0/1/2/3 → 0°/90°/180°/270°
    flipX: false,                     // horizontal flip
    flipY: false,                     // vertical flip
    scaleX: 1.0,                      // zoom factor
    scaleY: 1.0,
  ),

  // Overlay
  imageBytes: Uint8List bytes,        // image composited on top of video

  // Task ID for progress tracking / cancellation
  id: 'my-task-id',
)
```

### Quality Presets (alternative to `bitrate`)

```dart
VideoRenderData.withQualityPreset(
  video: EditorVideo.file(file),
  qualityPreset: VideoQualityPreset.p1080, // see list below
  bitrateOverride: 5000000,               // optional override
)
```

| Preset | |
|---|---|
| `ultra4K` | Ultra 4K |
| `k4` | Standard 4K |
| `p1080High` | 1080p High |
| `p1080` | 1080p |
| `p720High` | 720p High |
| `p720` | 720p |
| `p480` | 480p |
| `low` | Low quality |
| `custom` | Use `bitrate` field |

---

## Merging — `VideoSegment`

```dart
VideoRenderData(
  videoSegments: [
    VideoSegment(
      video: EditorVideo.file(file1),
      startTime: Duration(seconds: 0),
      endTime: Duration(seconds: 10),
    ),
    VideoSegment(
      video: EditorVideo.file(file2),
      // omit start/end to use full clip
    ),
  ],
)
```

---

## Render Methods

```dart
// Returns Uint8List (loads into memory)
Future<Uint8List> renderVideo(VideoRenderData data)

// Saves to file — preferred for large videos
Future<void> renderVideoToFile(String outputPath, VideoRenderData data)
```

---

## Metadata

```dart
VideoMetadata meta = await ProVideoEditor.instance.getMetadata(EditorVideo.file(file));

meta.duration   // Duration
meta.size       // Size (width × height)
meta.frameRate  // double (fps)
meta.bitrate    // int (bps)
meta.hasAudio   // bool
```

---

## Thumbnails

```dart
List<Uint8List> thumbs = await ProVideoEditor.instance.getThumbnails(
  ThumbnailConfigs(
    video: EditorVideo.file(file),
    outputFormat: ThumbnailFormat.jpeg,   // or .png
    timestamps: [Duration(seconds: 0), Duration(seconds: 5)],
    outputSize: Size(200, 200),
    boxFit: ThumbnailBoxFit.cover,        // cover/contain/fill/fitWidth/fitHeight
  ),
);
```

---

## Keyframes (for trim timeline scrubber)

```dart
List<Uint8List> frames = await ProVideoEditor.instance.getKeyFrames(
  KeyFramesConfigs(
    video: EditorVideo.file(file),
    maxOutputFrames: 20,
    outputSize: Size(80, 80),
    outputFormat: ThumbnailFormat.jpeg,
    boxFit: ThumbnailBoxFit.cover,
  ),
);
```

---

## Audio

### Check for audio track
```dart
bool hasAudio = await ProVideoEditor.instance.hasAudioTrack(EditorVideo.file(file));
```

### Extract audio
```dart
// To memory
Uint8List audio = await ProVideoEditor.instance.extractAudio(
  AudioExtractConfigs(
    video: EditorVideo.file(file),
    format: AudioFormat.mp3,   // mp3 / aac / m4a
    startTime: Duration(seconds: 10),
    endTime: Duration(seconds: 30),
  ),
);

// To file
await ProVideoEditor.instance.extractAudioToFile('/output.mp3', config);
```

### Add background music (in VideoRenderData)
```dart
VideoRenderData(
  video: ...,
  customAudioPath: '/path/to/music.mp3',
  customAudioVolume: 0.8,
  originalAudioVolume: 0.3,
  loopCustomAudio: true,
)
```

---

## Waveform

```dart
// Static (short videos)
WaveformData waveform = await ProVideoEditor.instance.getWaveform(
  WaveformConfigs(
    video: EditorVideo.file(file),
    resolution: WaveformResolution.medium, // low/medium/high/ultra
  ),
);
waveform.sampleCount  // int
waveform.duration     // Duration
waveform.isStereo     // bool
waveform.samples      // List<int>

// Streaming (long videos)
await for (WaveformChunk chunk in ProVideoEditor.instance.getWaveformStream(config)) {
  print('${(chunk.progress * 100).toInt()}%');
  if (chunk.isFinished) { /* use chunk.data */ }
}
```

### Waveform UI Widget
```dart
AudioWaveform(
  waveformData: waveform,
  style: WaveformStyle(height: 64, waveColor: Colors.blue),
)

AudioWaveform.streaming(
  config: WaveformConfigs(...),
  style: WaveformStyle(height: 64, waveColor: Colors.blue),
)
```

---

## Color Filters

Applies a 4×5 color matrix to the video:

```dart
VideoRenderData(
  video: ...,
  colorMatrixList: [
    ColorMatrix.fromList([
      1, 0, 0, 0, 0,   // R
      0, 1, 0, 0, 0,   // G
      0, 0, 1, 0, 0,   // B
      0, 0, 0, 1, 0,   // A
    ]),
  ],
)
```

> Note: Color matrix rendering is experimental — preview may differ from exported output.

---

## Progress Tracking

```dart
// All tasks
ProVideoEditor.instance.progressStream.listen((ProgressModel p) {
  print('${(p.progress * 100).toInt()}%');
});

// Specific task
ProVideoEditor.instance.progressStreamById('my-task-id').listen((p) {
  print(p.progress);
});
```

---

## Cancellation

```dart
await ProVideoEditor.instance.cancel('my-task-id');
// Throws RenderCanceledException on the render future
```

---

## Error Types

| Exception | Cause |
|---|---|
| `RenderCanceledException` | Task was cancelled via `cancel()` |
| `AudioNoTrackException` | Tried to extract audio from a video with no audio track |

---

## Limitations

- Windows / Linux / Web: no trim, merge, transform, or audio ops
- Cancellation: Android, iOS, macOS only
- Color matrix / blur: experimental
- Audio extraction formats: mp3, aac, m4a only
- `imageBytes` overlay: composites a single image over the entire video (no per-frame or animated overlays)
- Text overlays: must be rendered to an image first (Flutter's `Picture.toImage`), then passed as `imageBytes`
