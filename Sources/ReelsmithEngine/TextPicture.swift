#if canImport(CoreText)
import CoreGraphics
import CoreText
import Foundation
import ReelsmithCore

/// The picture of one text: the rectangle of its box, which is the block of its lines grown by 0.3 of the size
/// on every side. The centre of the image is the centre of the block.
///
/// https://developer.apple.com/documentation/coregraphics/cgimage
struct TextPicture {
    /// One image pixel is one canvas pixel. Clear outside the letters, their outline, their shadow and the box.
    let image: CGImage
    /// Canvas pixels, the width of image.
    let width: Double
    let height: Double
}

/// One line as Core Text laid it out, and where its pen starts inside the block.
struct TextBlockLine {
    let line: CTLine
    /// From the left of the block.
    let x: Double
    /// The baseline, from the top of the block downwards.
    let baseline: Double
}

/// The lines of a text and the size of the block they fill, in canvas pixels.
struct TextBlock {
    let lines: [TextBlockLine]
    let width: Double
    let height: Double
}

/// Lays out the string of a layer. Every line as typed is a paragraph of its own, so its direction is left to
/// its own text. A line longer than `lineWidth` wraps. The alignment is a side of the block.
///
/// https://developer.apple.com/documentation/coretext/cttypesettercreatewithattributedstring(_:)
/// https://developer.apple.com/documentation/coretext/cttypesettersuggestlinebreak(_:_:_:)
/// https://developer.apple.com/documentation/coretext/cttypesettercreateline(_:_:)
/// https://developer.apple.com/documentation/coretext/ctlinegettypographicbounds(_:_:_:_:)
/// https://developer.apple.com/documentation/coretext/ctlinegettrailingwhitespacewidth(_:)
/// https://developer.apple.com/documentation/coretext/ctlinegetpenoffsetforflush(_:_:_:)
func textBlock(for layer: TextLayer) -> TextBlock {
    let style = layer.style
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font(style.font, size: style.size),
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): colour(style.colour, alpha: 1),
    ]
    var lines: [CTLine] = []
    for typed in layer.string.split(separator: "\n", omittingEmptySubsequences: false) {
        // A line with nothing typed is set as one space, so it keeps the height of a line.
        let string = NSAttributedString(string: typed.isEmpty ? " " : String(typed), attributes: attributes)
        let typesetter = CTTypesetterCreateWithAttributedString(string as CFAttributedString)
        var start = 0
        while start < string.length {
            let count = max(1, CTTypesetterSuggestLineBreak(typesetter, start, layer.lineWidth))
            lines.append(CTTypesetterCreateLine(typesetter, CFRange(location: start, length: count)))
            start += count
        }
    }

    // The space a line ends with is not part of its width.
    let width = lines.map { CTLineGetTypographicBounds($0, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth($0) }
        .max() ?? 0
    let flush: CGFloat
    switch style.align {
    case .left:
        flush = 0
    case .centre:
        flush = 0.5
    case .right:
        flush = 1
    }
    var placed: [TextBlockLine] = []
    var top = 0.0
    for line in lines {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        _ = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        if !placed.isEmpty {
            top += style.lineSpacing * style.size
        }
        placed.append(
            TextBlockLine(
                line: line, x: CTLineGetPenOffsetForFlush(line, flush, width), baseline: top + Double(ascent)))
        top += Double(ascent) + Double(descent) + Double(leading)
    }
    return TextBlock(lines: placed, width: width, height: top)
}

/// Nil for a blank string. Never throws. Draws from the string, the style and the wrap width alone.
///
/// The shadow is cast by the outline and the letters together, so they are drawn as one transparency layer.
/// In a bitmap context y grows upwards, so a shadow that falls down has a negative offset.
///
/// https://developer.apple.com/documentation/coregraphics/cgcontext/init(data:width:height:bitspercomponent:bytesperrow:space:bitmapinfo:)
/// https://developer.apple.com/documentation/coregraphics/cgcontext/setshadow(offset:blur:color:)
/// https://developer.apple.com/documentation/coregraphics/cgcontext/begintransparencylayer(auxiliaryinfo:)
/// https://developer.apple.com/documentation/coregraphics/cgcontext/setshouldsmoothfonts(_:)
/// https://developer.apple.com/documentation/coregraphics/cgcontext/textposition
/// https://developer.apple.com/documentation/coretext/ctlinedraw(_:_:)
/// https://developer.apple.com/documentation/coregraphics/cgcontext/makeimage()
func textPicture(for layer: TextLayer) -> TextPicture? {
    if layer.string.allSatisfy({ $0 == " " || $0.isNewline }) {
        return nil
    }
    let style = layer.style
    let block = textBlock(for: layer)
    let width = block.width + 0.6 * style.size
    let height = block.height + 0.6 * style.size
    let pixelsWide = Int(width.rounded(.up))
    let pixelsHigh = Int(height.rounded(.up))
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
            data: nil, width: pixelsWide, height: pixelsHigh, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else {
        return nil
    }
    let black = RGB(r: 0, g: 0, b: 0)
    if style.box {
        context.setFillColor(colour(black, alpha: 0.6))
        context.fill(CGRect(x: 0, y: 0, width: pixelsWide, height: pixelsHigh))
    }
    // The letters are the same on a Mac and on a phone.
    context.setShouldSmoothFonts(false)
    if style.shadow {
        context.setShadow(
            offset: CGSize(width: 0, height: -0.06 * style.size), blur: CGFloat(0.12 * style.size),
            color: colour(black, alpha: 0.6))
    }
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    // The pen of each line, from the bottom left of the image.
    let left = (Double(pixelsWide) - block.width) / 2
    let top = (Double(pixelsHigh) - block.height) / 2
    let pens = block.lines.map { CGPoint(x: left + $0.x, y: Double(pixelsHigh) - top - $0.baseline) }
    if style.outline {
        for (line, pen) in zip(block.lines, pens) {
            addGlyphPaths(of: line.line, at: pen, to: context)
        }
        // Half of the line lies under the letters, so 0.08 of the size is seen around them.
        context.setLineWidth(CGFloat(0.16 * style.size))
        context.setLineJoin(.round)
        context.setStrokeColor(colour(style.colour == black ? RGB(r: 255, g: 255, b: 255) : black, alpha: 1))
        context.strokePath()
    }
    context.textMatrix = .identity
    for (line, pen) in zip(block.lines, pens) {
        context.textPosition = pen
        CTLineDraw(line.line, context)
    }
    context.endTransparencyLayer()
    guard let image = context.makeImage() else {
        return nil
    }
    return TextPicture(image: image, width: width, height: height)
}

/// Adds the outline of every glyph of a line to the path of the context, with the pen of the line at a point.
///
/// https://developer.apple.com/documentation/coretext/ctlinegetglyphruns(_:)
/// https://developer.apple.com/documentation/coretext/ctrungetattributes(_:)
/// https://developer.apple.com/documentation/coretext/ctrungetglyphs(_:_:_:)
/// https://developer.apple.com/documentation/coretext/ctrungetpositions(_:_:_:)
/// https://developer.apple.com/documentation/coretext/ctfontcreatepathforglyph(_:_:_:)
private func addGlyphPaths(of line: CTLine, at pen: CGPoint, to context: CGContext) {
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        guard let face = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName as String] else {
            continue
        }
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
        for index in 0..<count {
            var move = CGAffineTransform(translationX: pen.x + positions[index].x, y: pen.y + positions[index].y)
            if let path = CTFontCreatePathForGlyph(face as! CTFont, glyphs[index], &move) {
                context.addPath(path)
            }
        }
    }
}

/// A colour with the numbers of its `RGB`.
///
/// https://developer.apple.com/documentation/coregraphics/cgcolor/init(srgbred:green:blue:alpha:)
private func colour(_ rgb: RGB, alpha: CGFloat) -> CGColor {
    CGColor(
        srgbRed: CGFloat(rgb.r) / 255, green: CGFloat(rgb.g) / 255, blue: CGFloat(rgb.b) / 255, alpha: alpha)
}
#endif
