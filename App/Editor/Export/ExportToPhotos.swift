import Foundation
import Photos
import ReelsmithCore
import ReelsmithEngine

/// Exports the project to a file in the app's temporary folder, adds that file to the photo library with the right
/// to add only, and removes the file, after the save and after a failure alike. Returns how it ended.
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
    project: Project, mediaFolder: URL, fails: Bool, progress: @escaping @Sendable (Double) -> Void
) async -> ExportState.Event {
    let temporary = FileManager.default.temporaryDirectory
    let output = fails
        ? temporary.appendingPathComponent(UUID().uuidString).appendingPathComponent("export.mp4")
        : temporary.appendingPathComponent(UUID().uuidString + ".mp4")
    defer {
        try? FileManager.default.removeItem(at: output)
    }
    do {
        let plan = try renderPlan(for: project)
        try await export(plan: plan, media: project.media, mediaFolder: mediaFolder, to: output, progress: progress)
    } catch {
        return .failed(notAllowed: false)
    }
    guard await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized else {
        return .failed(notAllowed: true)
    }
    do {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: output, options: nil)
        }
        return .saved
    } catch {
        return .failed(notAllowed: false)
    }
}
