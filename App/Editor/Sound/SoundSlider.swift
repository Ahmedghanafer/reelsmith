import SwiftUI

/// The slider of a sound value: its word, then the slider, from leading to trailing. It shows `value` while it
/// is not dragged and its own value during a drag, and calls `send` once, when the drag ends. A change with no
/// drag, as an accessibility step makes it, is sent at once. A level refreshes the mix of the player item and the
/// start of the music builds a new item, so a drag must not send at every step. It holds no limit: Core does.
///
/// https://developer.apple.com/documentation/swiftui/slider/init(value:in:step:label:oneditingchanged:)
/// https://developer.apple.com/documentation/swiftui/binding/init(get:set:)
/// https://developer.apple.com/documentation/swiftui/state
/// https://developer.apple.com/documentation/swiftui/localizedstringkey
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
struct SoundSlider: View {
    private let identifier: String
    private let label: LocalizedStringKey
    private let value: Double
    private let range: ClosedRange<Double>
    private let step: Double
    private let send: @MainActor (Double) -> Void

    /// The value of the slider while it is dragged, nil while it is not.
    @State private var dragged: Double?

    init(
        identifier: String, label: LocalizedStringKey, value: Double, range: ClosedRange<Double>, step: Double,
        send: @escaping @MainActor (Double) -> Void
    ) {
        self.identifier = identifier
        self.label = label
        self.value = value
        self.range = range
        self.step = step
        self.send = send
    }

    var body: some View {
        HStack(spacing: 16) {
            Text(label)
            Slider(
                value: Binding(
                    get: { dragged ?? value },
                    set: { moved in
                        if dragged == nil {
                            send(moved)
                        } else {
                            dragged = moved
                        }
                    }
                ),
                in: range,
                step: step,
                label: { Text(label) },
                onEditingChanged: { editing in
                    if editing {
                        dragged = dragged ?? value
                    } else if let ended = dragged {
                        dragged = nil
                        send(ended)
                    }
                }
            )
            .accessibilityIdentifier(identifier)
        }
    }
}
