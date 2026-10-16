import Flutter
import Foundation
import ReelsmithCore
import ReelsmithEngine
import UIKit

/// The frames of the blocks, made as `App/Editor/Timeline/FramesCache.swift` made them, crossing as PNG bytes.
/// Dart keeps them in memory per media while an editor is open.
///
/// https://developer.apple.com/documentation/uikit/uiimage/pngdata()
/// https://developer.apple.com/documentation/uikit/uiimage/init(cgimage:)
/// https://api.flutter.dev/ios-embedder/interface_flutter_standard_typed_data.html
/// https://developer.apple.com/documentation/foundation/jsondecoder
extension Engine {
    /// The PNG bytes of the frames of the media by their time in ticks. The media is the JSON of its fact. A
    /// media whose frames cannot be made has none, and gives an empty map.
    func blockFrames(media: String, mediaFolder: String) async throws -> [Int64: FlutterStandardTypedData] {
        let info = try JSONDecoder().decode(MediaInfo.self, from: Data(media.utf8))
        let frames = (try? await makeBlockFrames(of: info, mediaFolder: URL(fileURLWithPath: mediaFolder))) ?? [:]
        var bytes: [Int64: FlutterStandardTypedData] = [:]
        for (time, image) in frames {
            if let png = UIImage(cgImage: image).pngData() {
                bytes[time.ticks] = FlutterStandardTypedData(bytes: png)
            }
        }
        return bytes
    }
}
