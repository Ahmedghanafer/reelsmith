import UIKit
import XCTest

// The picture probe: how much of an element has a colour, read from a screenshot of the screen.
//
// https://developer.apple.com/documentation/xcuiautomation/xcuiscreenshotproviding/screenshot()
// https://developer.apple.com/documentation/xcuiautomation/xcuiscreenshot/image
// https://developer.apple.com/documentation/uikit/uiimage/cgimage
// https://developer.apple.com/documentation/uikit/uiimage/size
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/frame
// https://developer.apple.com/documentation/coregraphics/cgcolorspace/srgb
// https://developer.apple.com/documentation/coregraphics/cgcontext/init(data:width:height:bitspercomponent:bytesperrow:space:bitmapinfo:)-4fkaf
// https://developer.apple.com/documentation/coregraphics/cgimagealphainfo/premultipliedlast
// https://developer.apple.com/documentation/coregraphics/cgbitmapinfo/byteorderdefault
// https://developer.apple.com/documentation/coregraphics/cgcontext/draw(_:in:bytiling:)
// https://developer.apple.com/documentation/coregraphics/cgcontext/data
@MainActor
extension XCTestCase {
    /// The share, from 0 to 1, of the pixels of the element's frame that lie within 48 of 255 per
    /// channel of the colour. Every fourth pixel of every fourth row is read. A test compares the
    /// answer with "more than" or "less than" a number, never with an exact value.
    func share(of colour: (r: Int, g: Int, b: Int), in element: XCUIElement) -> Double {
        let picture = XCUIScreen.main.screenshot().image
        guard let image = picture.cgImage, picture.size.width > 0,
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            // The bitmap info is the alpha value alone, so its byte order bits are zero, which is the
            // default byte order. With 8 bits a component that means one byte for each component in
            // the order the alpha value names: red, green, blue, then alpha last. So of the four bytes
            // of a pixel byte 0 is red, byte 1 is green, byte 2 is blue and byte 3 is alpha. The Engine
            // test `middlePixel` draws into the same kind of bitmap and reads the same three bytes.
            // Were byte 0 blue and byte 2 red, the tests of `PictureTests` that want blue high and red
            // low on the blue clip, and red high and blue low on the red clip, would fail.
            let context = CGContext(
                data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            XCTFail("the probe could not make its bitmap")
            return 0
        }
        // The first row of the bitmap's bytes is the top row of the screenshot, as the frame counts.
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let data = context.data else {
            XCTFail("the probe could not read its bitmap")
            return 0
        }
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        let bytesPerRow = context.bytesPerRow

        // The frame is in points of the screen, the bitmap in pixels. The size of the image is in
        // points too, so the pixels of its width divided by that width is the scale between them.
        let scale = Double(image.width) / Double(picture.size.width)
        let frame = element.frame
        let left = max(0, Int((Double(frame.minX) * scale).rounded(.up)))
        let right = min(image.width, Int((Double(frame.maxX) * scale).rounded(.down)))
        let top = max(0, Int((Double(frame.minY) * scale).rounded(.up)))
        let bottom = min(image.height, Int((Double(frame.maxY) * scale).rounded(.down)))

        var read = 0
        var near = 0
        for y in stride(from: top, to: bottom, by: 4) {
            for x in stride(from: left, to: right, by: 4) {
                let offset = y * bytesPerRow + x * 4
                read += 1
                if abs(Int(bytes[offset]) - colour.r) <= 48
                    && abs(Int(bytes[offset + 1]) - colour.g) <= 48
                    && abs(Int(bytes[offset + 2]) - colour.b) <= 48
                {
                    near += 1
                }
            }
        }
        guard read > 0 else {
            XCTFail("the probe found no pixel of the element on the screen")
            return 0
        }
        return Double(near) / Double(read)
    }
}
