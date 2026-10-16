import Foundation
import Photos

/// The save to Photos, moved from `App/Editor/Export/ExportToPhotos.swift`.
///
/// https://developer.apple.com/documentation/photos/phphotolibrary/requestauthorization(for:handler:)
/// https://developer.apple.com/documentation/photos/phaccesslevel/addonly
/// https://developer.apple.com/documentation/photos/phphotolibrary/performchanges(_:completionhandler:)
/// https://developer.apple.com/documentation/photos/phassetcreationrequest/forasset()
/// https://developer.apple.com/documentation/photos/phassetcreationrequest/addresource(with:fileurl:options:)
/// https://developer.apple.com/documentation/foundation/filemanager/removeitem(at:)
extension Engine {
    /// Adds the file to the photo library with the right to add only, and removes the file, after the save and
    /// after a failure alike. A photo library that does not allow adding is `notAllowed`, every other error of the
    /// save is `failed`.
    func saveToPhotos(file: String) async throws -> SaveOutcome {
        let output = URL(fileURLWithPath: file)
        defer {
            try? FileManager.default.removeItem(at: output)
        }
        guard await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized else {
            return .notAllowed
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: output, options: nil)
            }
            return .saved
        } catch {
            return .failed
        }
    }
}
