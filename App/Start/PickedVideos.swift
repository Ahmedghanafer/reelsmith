import Foundation
import ReelsmithCore
import ReelsmithEngine
import UniformTypeIdentifiers

/// `<documents>/Media/`, the media folder of a project made from picked videos.
///
/// https://developer.apple.com/documentation/foundation/filemanager/urls(for:in:)
let pickedMediaFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("Media")

/// Removes the folder of picked videos with everything in it. M1 saves nothing, so it is called at every start.
///
/// https://developer.apple.com/documentation/foundation/filemanager/removeitem(at:)
func emptyPickedMediaFolder() {
    try? FileManager.default.removeItem(at: pickedMediaFolder)
}

/// Copies each picked video to `<documents>/Media/<uuid>.<the picked file's extension>` and reads its facts.
/// Gives the facts in the order of choosing. A video that cannot be copied or read is left out, and nothing is thrown.
///
/// https://developer.apple.com/documentation/foundation/filemanager/createdirectory(at:withintermediatedirectories:attributes:)
func copyPicked(_ videos: [NSItemProvider]) async -> [MediaInfo] {
    try? FileManager.default.createDirectory(at: pickedMediaFolder, withIntermediateDirectories: true)
    var facts: [MediaInfo] = []
    for video in videos {
        let id = UUID().uuidString
        guard let fileName = await copyVideo(video, named: id) else { continue }
        if let info = try? await readMediaInfo(id: MediaID(id), fileName: fileName, in: pickedMediaFolder) {
            facts.append(info)
        }
    }
    return facts
}

/// Copies the file of one picked video into the media folder and gives its file name there, nil when it failed.
/// The picker's file is only there until the completion handler returns, so the copy is made inside it.
///
/// https://developer.apple.com/documentation/foundation/nsitemprovider/loadfilerepresentation(fortypeidentifier:completionhandler:)
/// https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/movie
/// https://developer.apple.com/documentation/foundation/filemanager/copyitem(at:to:)
/// https://developer.apple.com/documentation/swift/withcheckedcontinuation(isolation:function:_:)
private func copyVideo(_ video: NSItemProvider, named name: String) async -> String? {
    await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
        _ = video.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { file, _ in
            guard let file else {
                continuation.resume(returning: nil)
                return
            }
            let fileName = name + "." + file.pathExtension
            do {
                try FileManager.default.copyItem(at: file, to: pickedMediaFolder.appendingPathComponent(fileName))
                continuation.resume(returning: fileName)
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}
