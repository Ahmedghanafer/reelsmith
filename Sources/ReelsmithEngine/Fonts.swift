#if canImport(CoreText)
import CoreGraphics
import CoreText
import Foundation
import ReelsmithCore

/// The two bundled faces: the file of each in the folder `Fonts`, and the PostScript name that file gives.
private let bundledFaces: [TextFont: String] = [.naskh: "Amiri-Regular", .naskhBold: "Amiri-Bold"]

/// Registers the files of `Fonts` for the process, once, from the bundle of the Engine target.
///
/// https://developer.apple.com/documentation/coretext/ctfontmanagerregisterfontsforurl(_:_:_:)
/// https://developer.apple.com/documentation/foundation/bundle/url(forresource:withextension:subdirectory:)
private let facesAreRegistered: Bool = {
    for file in bundledFaces.values {
        if let url = Bundle.module.url(forResource: file, withExtension: "ttf", subdirectory: "Fonts") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
    return true
}()

/// The face of a choice at a size in canvas pixels. A bundled face that cannot be made gives the platform's own
/// face: a name that is not found is answered with a best match, so the name of what came back is compared.
/// The fallback covers a face that cannot be made from its file. A resource bundle that is not inside the app
/// stops the app, in the accessor the package makes for `Bundle.module`.
///
/// https://developer.apple.com/documentation/coretext/ctfontcreatewithname(_:_:_:)
/// https://developer.apple.com/documentation/coretext/ctfontcopypostscriptname(_:)
/// https://developer.apple.com/documentation/coretext/ctfontcreateuifontforlanguage(_:_:_:)
func font(_ choice: TextFont, size: Double) -> CTFont {
    _ = facesAreRegistered
    if let name = bundledFaces[choice] {
        let face = CTFontCreateWithName(name as CFString, CGFloat(size), nil)
        if CTFontCopyPostScriptName(face) as String == name {
            return face
        }
    }
    return CTFontCreateUIFontForLanguage(.system, CGFloat(size), nil)
        ?? CTFontCreateWithName("" as CFString, CGFloat(size), nil)
}

/// The PostScript name of the face that was really made, after any fallback.
public func faceName(of choice: TextFont) -> String {
    CTFontCopyPostScriptName(font(choice, size: 64)) as String
}
#endif
