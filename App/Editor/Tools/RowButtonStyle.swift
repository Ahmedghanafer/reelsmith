import SwiftUI

/// The style of the buttons of the tools row and of the part row of the text panel: the word in the accent
/// colour, grey when the button is not enabled, and dimmed while it is pressed. The style of the system
/// lets the word of a released button float from where it was pressed to where its row now stands, when
/// the tap changed the height of the layout. This one draws the word where the row is, with no animation.
///
/// https://developer.apple.com/documentation/swiftui/buttonstyle
/// https://developer.apple.com/documentation/swiftui/buttonstyleconfiguration
/// https://developer.apple.com/documentation/swiftui/environmentvalues/isenabled
/// https://developer.apple.com/documentation/swiftui/view/animation(_:value:)
struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        RowButtonLabel(configuration: configuration)
    }
}

/// A view of its own, because a style cannot read the environment itself.
private struct RowButtonLabel: View {
    let configuration: ButtonStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .foregroundStyle(isEnabled ? Color.accentColor : Color(uiColor: .tertiaryLabel))
            .opacity(configuration.isPressed ? 0.4 : 1)
            .animation(nil, value: configuration.isPressed)
    }
}
