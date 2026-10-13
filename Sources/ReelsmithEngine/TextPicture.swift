#if canImport(CoreText)
import CoreGraphics
import ReelsmithCore

/// The picture of one text. Nothing is drawn yet.
///
/// https://developer.apple.com/documentation/coregraphics/cgimage
struct TextPicture {
    /// One image pixel is one canvas pixel. Clear outside the letters, their outline, their shadow and the box.
    let image: CGImage
    /// Canvas pixels, the width of image.
    let width: Double
    let height: Double
}

/// Nil for a blank string. Never throws.
func textPicture(for layer: TextLayer) -> TextPicture? {
    nil
}
#endif
