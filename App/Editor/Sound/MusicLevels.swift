import ReelsmithCore
import SwiftUI

/// The part `levels` of the sound panel. With music: the times of the music, `state.musicLabel`, as
/// `sound.levelsLabel`, so she sees where the music begins while she moves its start, then four sound sliders:
/// the volume of the music from 0 to 1, where it begins in the file in ticks, and its fade in and fade out in
/// ticks. The start slider shows only while `canSetMusicStart` is true, so its step fits into its range. With no
/// music the part shows the words of `music.none` as `sound.noMusic` and no slider. It decides nothing and holds
/// no state: each slider reads the project and sends its action once, at the end of a drag, and Core holds every
/// value inside its limits. Every range and step is read from Core or is a number of the plan. The part lays out
/// from leading to trailing, so Arabic mirrors it. The label of the times is fixed left to right, as the time of
/// the preview is.
///
/// https://developer.apple.com/documentation/swiftui/text/init(verbatim:)
/// https://developer.apple.com/documentation/swiftui/text/monospaceddigit()
/// https://developer.apple.com/documentation/swiftui/environmentvalues/layoutdirection
/// https://developer.apple.com/documentation/swiftui/view/frame(minwidth:idealwidth:maxwidth:minheight:idealheight:maxheight:alignment:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
struct MusicLevels: View {
    let store: EditorStore

    /// The step of both fade sliders in ticks, from the plan (seam T).
    private let fadeStep: Double = 300

    var body: some View {
        let state: EditorState = store.state
        VStack(spacing: 8) {
            if let music = state.project.music {
                if let label = state.musicLabel {
                    Text(verbatim: label)
                        .monospacedDigit()
                        .environment(\.layoutDirection, .leftToRight)
                        .accessibilityIdentifier("sound.levelsLabel")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                SoundSlider(
                    identifier: "sound.musicVolume", label: "music.volume", value: music.volume, range: 0...1,
                    step: 0.05, send: { store.send(.sound(.setMusicVolume($0))) })
                if state.canSetMusicStart {
                    SoundSlider(
                        identifier: "sound.musicStart", label: "music.start", value: Double(music.start.ticks),
                        range: 0...Double(music.largestStart.ticks), step: Double(SoundGeometry.startStep.ticks),
                        send: { store.send(.sound(.setMusicStart(Time(ticks: Int64($0))))) })
                }
                SoundSlider(
                    identifier: "sound.fadeIn", label: "music.fadeIn", value: Double(music.fadeIn.ticks),
                    range: 0...Double(SoundGeometry.maximumFade.ticks), step: fadeStep,
                    send: { store.send(.sound(.setFadeIn(Time(ticks: Int64($0))))) })
                SoundSlider(
                    identifier: "sound.fadeOut", label: "music.fadeOut", value: Double(music.fadeOut.ticks),
                    range: 0...Double(SoundGeometry.maximumFade.ticks), step: fadeStep,
                    send: { store.send(.sound(.setFadeOut(Time(ticks: Int64($0))))) })
            } else {
                Text("music.none")
                    .accessibilityIdentifier("sound.noMusic")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
