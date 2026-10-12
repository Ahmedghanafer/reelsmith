# Architecture

Each story writes only inside its own slot.

### m1-1-core-contracts
<!-- slot: m1-1-core-contracts -->
`Sources/ReelsmithCore` imports nothing but the standard library and Foundation, and is tested on Linux. The types in the files below are public values, Equatable and Sendable.

- `Model/Time.swift`: `Time`, a whole number of ticks, 600 a second.
- `Model/Media.swift`: `MediaID` and `MediaInfo`, the facts of one media file.
- `Model/Project.swift`: `ClipID`, `Clip` and `Project`. Clips always touch, so every place is computed from the clip lengths.
- `Model/Words.swift`: `Words`, a word key with its arguments. Core never holds a word a person reads.
- `Editor/EditorState.swift`: `EditorState`, the project with selection, playhead and playing.
- `Editor/EditorAction.swift`: `EditorAction`, everything a screen can ask for.
- `Editor/Reduce.swift`: `reduce`, state plus action gives the new state. An action that cannot be done returns the state unchanged.
- `Editor/Edits.swift`: the edit actions and `canSplit`, `canDelete`, bodies by `m1-3-edit-actions`.
- `Plan/RenderPlan.swift`: `renderPlan(for:)` turns a project into segments, each with its source range and the rectangle its upright picture fills on the 1080 by 1920 canvas.
- `Seeds/TestClip.swift`: `RGB` and `TestClip`, the values of the five test clips. No file is written here.
- `Seeds/Seed.swift`: `Seed`, the three demo projects by name.
<!-- end slot: m1-1-core-contracts -->

### m1-3-edit-actions
<!-- slot: m1-3-edit-actions -->
- `Editor/Edits.swift`: the bodies of `addClips`, `split`, `trimStart`, `trimEnd` and `deleteSelected`, which `reduce` calls, and of `canSplit` and `canDelete`. An edit that cannot be done returns the state unchanged. A trim past a limit stops at the limit. Every edit keeps a valid state valid: each clip inside its source, each length whole frames and at least `TimelineGeometry.minimumClip`, the playhead a whole frame inside the project, the selection a clip of the project or none.
- `Editor/TimelineGeometry.swift`: `TimelineGeometry`, the fixed scale of the timeline strip (60 points a second), the shortest clip (60 ticks), and the pure functions between a time and a point and from a drag in points to a trim amount.
<!-- end slot: m1-3-edit-actions -->

### m1-2a-engine-target
<!-- slot: m1-2a-engine-target -->
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
