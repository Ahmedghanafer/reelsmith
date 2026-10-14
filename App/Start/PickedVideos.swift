import Foundation
import ReelsmithCore
import ReelsmithEngine
import UniformTypeIdentifiers

/// Copies each picked video to `<folder>/<uuid>.<the picked file's extension>` and reads its facts. The folder
/// must be there: it is the media folder of a new draft. Gives the facts in the order of choosing. A video that
/// cannot be copied or read is left out, and nothing is thrown.
func copyPicked(_ videos: [NSItemProvider], into folder: URL) async -> [MediaInfo] {
    var facts: [MediaInfo] = []
    for video in videos {
        let id = UUID().uuidString
        guard let fileName = await copyVideo(video, named: id, into: folder) else { continue }
        if let info = try? await readMediaInfo(id: MediaID(id), fileName: fileName, in: folder) {
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
