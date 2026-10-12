# Testing

Each story writes only inside its own slot.

### m1-1-core-contracts
<!-- slot: m1-1-core-contracts -->
<!-- end slot: m1-1-core-contracts -->

### m1-3-edit-actions
<!-- slot: m1-3-edit-actions -->
<!-- end slot: m1-3-edit-actions -->

### m1-2a-engine-target
<!-- slot: m1-2a-engine-target -->
Engine tests live in `Tests/ReelsmithEngineTests` and run with `swift test` on macOS only, first in the compile check. On Linux the target compiles to nothing. A test makes its clips with `writeTestClip` in a folder of its own under the temporary folder. No media file is committed.

- `TestClipMakerTests.swift` holds the five test clips to the table: stored size, H.264, the exact frame count, the exact length of the picture track, the two colours at half the length, the sound track of blue and red with its peak, the 709 colour properties, the stored transform of `turned.mov`, the write under a temporary name and the kept file.
- When `REELSMITH_CLIP_DIR` is set, `testLeavesBlueAndRedInTheClipFolder` leaves `blue.mov` and `red.mov` in that folder. When it is not set the test is skipped.

The helpers in `Support/MediaReading.swift` read a file back. Each takes the file's URL:

- `pixel(of:at:x:y:)`: the colour of one pixel of the stored picture as an `RGB`, x and y from the top left, in the frame shown at a Core `Time`. The turn of the file is not applied.
- `frameCount(of:)`: the number of picture frames, counted without decoding.
- `soundPeak(of:)`: the peak of the first sound track, from 0 to 1 of full scale.
- `storedSize(of:)`: width and height of the picture as stored.
- `tracks(of:)`: one `TrackFacts` per track with `kind` ("vide" or "soun"), `coding` ("avc1" for H.264, "lpcm" for uncompressed sound), `duration`, and for sound `sampleRate`, `channels` and `bitsPerSample`.
- `fileType(of:)`: the major brand the file starts with, "qt  " for a QuickTime movie.
- `colourProperties(of:)`: the primaries, transfer function and matrix the picture track reports, by the platform's names.
- `storedTransform(of:)`: the six numbers a, b, c, d, tx, ty of the picture track.

`UITests/HarnessTests.swift` holds one empty test, so the build for testing has a target. It is built by the compile check and not run there.
<!-- end slot: m1-2a-engine-target -->

### m1-2b-ui-harness
<!-- slot: m1-2b-ui-harness -->
<!-- end slot: m1-2b-ui-harness -->

### m1-2c-wave-run
<!-- slot: m1-2c-wave-run -->
<!-- end slot: m1-2c-wave-run -->

### m1-5-engine
<!-- slot: m1-5-engine -->
<!-- end slot: m1-5-engine -->

### m1-6a-media-facts
<!-- slot: m1-6a-media-facts -->
<!-- end slot: m1-6a-media-facts -->

### m1-8-timeline
<!-- slot: m1-8-timeline -->
<!-- end slot: m1-8-timeline -->

### m1-6b-new-project
<!-- slot: m1-6b-new-project -->
<!-- end slot: m1-6b-new-project -->

### m1-7-preview
<!-- slot: m1-7-preview -->
<!-- end slot: m1-7-preview -->

### m1-9b-trim-handles
<!-- slot: m1-9b-trim-handles -->
<!-- end slot: m1-9b-trim-handles -->

### m1-9a-split-delete
<!-- slot: m1-9a-split-delete -->
<!-- end slot: m1-9a-split-delete -->

### m1-10-export
<!-- slot: m1-10-export -->
<!-- end slot: m1-10-export -->

### m1-11-guard
<!-- slot: m1-11-guard -->
<!-- end slot: m1-11-guard -->

### m1-12-whole-path
<!-- slot: m1-12-whole-path -->
<!-- end slot: m1-12-whole-path -->
