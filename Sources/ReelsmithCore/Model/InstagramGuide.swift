/// What Instagram's own buttons and caption cover on a Reel, as shares of the 9:16 canvas. The bands are not
/// measured on a Reel: the Owner checks them against one of hers on the phone.
public enum InstagramGuide {
    /// The share of the height covered at the top.
    public static let top: Double = 0.14
    /// The share of the height covered at the bottom, the caption and the name.
    public static let bottom: Double = 0.35
    /// The share of the width covered at each side.
    public static let side: Double = 0.06

    /// The rectangle nothing covers, in canvas pixels from the top left. Nil on the 16:9 canvas, which has no guide.
    public static func safeArea(on canvas: Canvas) -> (x: Double, y: Double, width: Double, height: Double)? {
        guard canvas == .portrait else {
            return nil
        }
        let width = Double(canvas.width)
        let height = Double(canvas.height)
        return (
            x: width * side, y: height * top, width: width * (1 - 2 * side), height: height * (1 - top - bottom)
        )
    }
}
