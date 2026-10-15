import Foundation
import ReelsmithCore
import ReelsmithEngine
import UniformTypeIdentifiers

/// Copies each picked video to `<folder>/<uuid>.<the picked file's extension>` and reads its facts, and brings each
/// picked photo in as a still movie `<folder>/<uuid>.mov` with `importPhoto`. The folder must be there: it is a
/// media folder. Gives the facts in the order of choosing. An item that cannot be copied, read or imported is left
/// out, and nothing is thrown.
///
/// https://developer.apple.com/documentation/foundation/nsitemprovider/hasitemconformingtotypeidentifier(_:)
/// https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/image
func copyPicked(_ videos: [NSItemProvider], into folder: URL) async -> [MediaInfo] {
    var facts: [MediaInfo] = []
    for video in videos {
        let id = UUID().uuidString
        if !video.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
            && video.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        {
            // The picked file is copied beside the media and removed once the still movie is written or refused.
            guard let picked = await copyFile(video, type: .image, named: id + "-picked", into: folder) else { continue }
            let source = folder.appendingPathComponent(picked)
            let info = try? await importPhoto(from: source, id: MediaID(id), into: folder)
            try? FileManager.default.removeItem(at: source)
            if let info {
                facts.append(info)
            }
            continue
        }
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
    await copyFile(video, type: .movie, named: name, into: folder)
}

/// Copies the file of the type that a provider holds to `<folder>/<name>.<the extension of its file>` inside the
/// completion handler, and gives its file name there, nil when it failed.
func copyFile(_ provider: NSItemProvider, type: UTType, named name: String, into folder: URL) async -> String? {
    await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
        _ = provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { file, _ in
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
