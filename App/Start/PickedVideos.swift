import Foundation
import ReelsmithCore
import ReelsmithEngine
import UniformTypeIdentifiers

/// `<documents>/Media/`, the media folder of a project made from picked videos.
/// M1 saves nothing, so the folder is removed with everything in it when this is first read.
/// Swift runs the initialiser of a constant at file level once for a process, so nothing is removed
/// under a running copy. The start screen reads it when it appears, which is at every start of the app.
///
/// https://developer.apple.com/documentation/foundation/filemanager/urls(for:in:)
/// https://developer.apple.com/documentation/foundation/filemanager/removeitem(at:)
let pickedMediaFolder: URL = {
    let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Media")
    try? FileManager.default.removeItem(at: folder)
    return folder
}()

/// Copies each picked video to `<documents>/Media/<uuid>.<the picked file's extension>` and reads its facts.
/// Gives the facts in the order of choosing. A video that cannot be copied or read is left out, and nothing is thrown.
///
/// https://developer.apple.com/documentation/foundation/filemanager/createdirectory(at:withintermediatedirectories:attributes:)
func copyPicked(_ videos: [NSItemProvider]) async -> [MediaInfo] {
    try? FileManager.default.createDirectory(at: pickedMediaFolder, withIntermediateDirectories: true)
    var facts: [MediaInfo] = []
    for video in videos {
        let id = UUID().uuidString
        guard let fileName = await copyVideo(video, named: id, into: pickedMediaFolder) else { continue }
        if let info = try? await readMediaInfo(id: MediaID(id), fileName: fileName, in: pickedMediaFolder) {
            facts.append(info)
        }
    }
    return facts
}

/// Copies the file of one picked video to `<folder>/<name>.<the extension of the picked file>` and gives its file
/// name there, nil when it failed. The folder must be there.
/// The picker's file is only there until the completion handler returns, so the copy is made inside it.
///
/// https://developer.apple.com/documentation/foundation/nsitemprovider/loadfilerepresentation(fortypeidentifier:completionhandler:)
/// https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/movie
/// https://developer.apple.com/documentation/foundation/filemanager/copyitem(at:to:)
/// https://developer.apple.com/documentation/swift/withcheckedcontinuation(isolation:function:_:)
func copyVideo(_ video: NSItemProvider, named name: String, into folder: URL) async -> String? {
    await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
        _ = video.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { file, _ in
            guard let file else {
                continuation.resume(returning: nil)
                return
            }
            let fileName = name + "." + file.pathExtension
            do {
                try FileManager.default.copyItem(at: file, to: folder.appendingPathComponent(fileName))
                continuation.resume(returning: fileName)
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}
