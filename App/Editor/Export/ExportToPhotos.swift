import Foundation
import Photos
import ReelsmithCore
import ReelsmithEngine

/// Exports the project at the settings to a file in the app's temporary folder, reads the facts of the written file,
/// adds that file to the photo library with the right to add only, and removes the file, after the save and after
/// a failure alike. Returns how it ended, and the facts, nil when no file was written or the read threw.
/// Every error of the plan, of the Engine and of the save is `failed`. Only a photo library that does not
/// allow adding is `failed(notAllowed: true)`. With `fails` the output place lies in a folder that is not there,
/// so the Engine throws `cannotWrite` before any work.
///
/// https://developer.apple.com/documentation/foundation/filemanager/temporarydirectory
/// https://developer.apple.com/documentation/photos/phphotolibrary/requestauthorization(for:handler:)
/// https://developer.apple.com/documentation/photos/phaccesslevel/addonly
/// https://developer.apple.com/documentation/photos/phphotolibrary/performchanges(_:completionhandler:)
/// https://developer.apple.com/documentation/photos/phassetcreationrequest/forasset()
/// https://developer.apple.com/documentation/photos/phassetcreationrequest/addresource(with:fileurl:options:)
func exportToPhotos(
    project: Project, settings: ExportSettings, mediaFolder: URL, fails: Bool,
    progress: @escaping @Sendable (Double) -> Void
) async -> (event: ExportState.Event, facts: VideoFacts?) {
    let temporary = FileManager.default.temporaryDirectory
    let output = fails
        ? temporary.appendingPathComponent(UUID().uuidString).appendingPathComponent("export.mp4")
        : temporary.appendingPathComponent(UUID().uuidString + ".mp4")
    defer {
        try? FileManager.default.removeItem(at: output)
    }
    do {
        let plan = try renderPlan(for: project, settings: settings)
        try await export(plan: plan, media: project.media, mediaFolder: mediaFolder, to: output, progress: progress)
    } catch {
        return (.failed(notAllowed: false), nil)
    }
    let facts = try? await readVideoFacts(of: output)
    guard await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized else {
        return (.failed(notAllowed: true), facts)
    }
    do {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: output, options: nil)
        }
        return (.saved, facts)
    } catch {
        return (.failed(notAllowed: false), facts)
    }
}
