#if canImport(AVFoundation)
import AVFoundation
import CoreMedia
import Foundation
import ReelsmithCore

/// The facts of the music file `<media folder>/<file name>`, under the id, the file name and the title given: the
/// length of its first sound track, rounded down to a tick.
/// Throws `sourceMissing` with the id for a file that is not in the folder, `cannotRead` for a file that cannot be
/// opened or has no sound track or a first sound track of no length, and `protectedFile` by `musicUse`.
///
/// https://developer.apple.com/documentation/avfoundation/avurlasset
/// https://developer.apple.com/documentation/avfoundation/avasset/loadtracks(withmediatype:)
/// https://developer.apple.com/documentation/avfoundation/avasynchronouskeyvalueloading/load(_:)
/// https://developer.apple.com/documentation/avfoundation/avpartialasyncproperty/hasprotectedcontent
/// https://developer.apple.com/documentation/avfoundation/avpartialasyncproperty/iscomposable
/// https://developer.apple.com/documentation/avfoundation/avpartialasyncproperty/isexportable
/// https://developer.apple.com/documentation/avfoundation/avassettrack/timerange
public func readMusicFile(id: MediaID, fileName: String, title: String, in mediaFolder: URL) async throws -> MusicFile {
    let file = mediaFolder.appendingPathComponent(fileName)
    guard FileManager.default.fileExists(atPath: file.path) else { throw EngineError.sourceMissing(id) }

    let asset = AVURLAsset(url: file)
    let soundTracks: [AVAssetTrack]
    let isProtected: Bool
    let isComposable: Bool
    let isExportable: Bool
    var length = CMTime.zero
    do {
        soundTracks = try await asset.loadTracks(withMediaType: .audio)
        isProtected = try await asset.load(.hasProtectedContent)
        isComposable = try await asset.load(.isComposable)
        isExportable = try await asset.load(.isExportable)
        if let first = soundTracks.first {
            length = try await first.load(.timeRange).duration
        }
    } catch {
        throw EngineError.cannotRead
    }

    if let refusal = musicUse(
        hasSound: !soundTracks.isEmpty, isProtected: isProtected, isComposable: isComposable,
        isExportable: isExportable) {
        throw refusal
    }
    let ticks = wholeTicks(of: length)
    guard ticks > 0 else { throw EngineError.cannotRead }
    return MusicFile(id: id, fileName: fileName, title: title, duration: Time(ticks: ticks))
}

/// Copies source to `<mediaFolder>/<a new UUID string>.<the extension of source>`, holding the right to read source
/// only while it copies, makes the folder when it is missing, then reads the facts with `readMusicFile`.
/// The title is the one given, or the name of source without its extension when nil.
/// The answer of the start of security scoped access is kept only to end that access again: the copy is tried
/// whatever it was, since a file that needs no right answers false. A source with no extension is copied with none.
/// After a throw no copy is left. Throws `cannotRead` when the copy fails, and what `readMusicFile` throws.
///
/// https://developer.apple.com/documentation/foundation/url/startaccessingsecurityscopedresource()
/// https://developer.apple.com/documentation/foundation/url/stopaccessingsecurityscopedresource()
/// https://developer.apple.com/documentation/foundation/filemanager/copyitem(at:to:)
/// https://developer.apple.com/documentation/foundation/filemanager/createdirectory(at:withintermediatedirectories:attributes:)
public func importMusic(from source: URL, title: String?, to mediaFolder: URL) async throws -> MusicFile {
    let id = UUID().uuidString
    let fileName = source.pathExtension.isEmpty ? id : id + "." + source.pathExtension
    let copy = mediaFolder.appendingPathComponent(fileName)

    do {
        try FileManager.default.createDirectory(at: mediaFolder, withIntermediateDirectories: true)
    } catch {
        throw EngineError.cannotRead
    }
    let granted = source.startAccessingSecurityScopedResource()
    var copied = true
    do {
        try FileManager.default.copyItem(at: source, to: copy)
    } catch {
        copied = false
    }
    if granted {
        source.stopAccessingSecurityScopedResource()
    }
    guard copied else {
        try? FileManager.default.removeItem(at: copy)
        throw EngineError.cannotRead
    }

    do {
        return try await readMusicFile(
            id: MediaID(id), fileName: fileName, title: title ?? source.deletingPathExtension().lastPathComponent,
            in: mediaFolder)
    } catch {
        try? FileManager.default.removeItem(at: copy)
        throw error
    }
}

/// nil when the file can be music. `protectedFile` when it is protected, or when it has sound and is not composable
/// or not exportable. `cannotRead` when it has no sound and is not protected.
func musicUse(hasSound: Bool, isProtected: Bool, isComposable: Bool, isExportable: Bool) -> EngineError? {
    if isProtected {
        return .protectedFile
    }
    if !hasSound {
        return .cannotRead
    }
    if !isComposable || !isExportable {
        return .protectedFile
    }
    return nil
}
#endif
