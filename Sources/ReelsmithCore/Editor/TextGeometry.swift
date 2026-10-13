public enum TextGeometry {
    /// The smallest font size, in canvas pixels.
    public static let minimumSize: Double = 16
    /// The largest font size, in canvas pixels.
    public static let maximumSize: Double = 400
    /// A line wraps at this share of the canvas width.
    public static let wrapShare: Double = 0.8
    /// No trim makes a text shorter than this.
    public static let minimumText: Time = TimelineGeometry.minimumClip

    /// A length in points of the screen as canvas pixels, signed, for a picture drawn that many points wide.
    /// 0 when the picture width is not above 0.
    public static func canvasLength(ofPoints points: Double, pictureWidth: Double, canvas: Canvas) -> Double {
        guard pictureWidth > 0 else {
            return 0
        }
        return points * Double(canvas.width) / pictureWidth
    }
}
