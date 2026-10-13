public enum TextAction: Equatable, Sendable {
    /// A new text: empty string, whole, the centre of the canvas, rotation 0, TextStyle.standard.
    /// It is selected. Nothing on an empty project.
    case add
    /// Nothing for an unknown id. Leaves isPlaying alone.
    case select(TextID)
    /// Stored as given.
    case setString(TextID, String)
    /// The size and the line spacing are held between their limits.
    case setStyle(TextID, TextStyle)
    /// The new centre in canvas pixels, held inside the canvas, the edge is inside.
    case move(TextID, x: Double, y: Double)
    /// Degrees clockwise, brought above minus 180 and at most 180, and to 0 when at most 3 from it.
    case turn(TextID, to: Double)
    /// A positive amount makes the text shorter. Rounded toward zero to whole frames. Sent once, on release.
    case trimStart(TextID, by: Time)
    /// A positive amount makes the text shorter. Rounded toward zero to whole frames. Sent once, on release.
    case trimEnd(TextID, by: Time)
}
