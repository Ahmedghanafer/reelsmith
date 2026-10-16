import Foundation
import PhotosUI
import ReelsmithCore
import ReelsmithEngine
import UIKit
import UniformTypeIdentifiers

/// The system photo picker and the copy of what she picked, moved from `App/Start/VideoPicker.swift` and
/// `App/Start/PickedVideos.swift`.
///
/// https://developer.apple.com/documentation/uikit/uiviewcontroller/present(_:animated:completion:)
/// https://developer.apple.com/documentation/uikit/uiviewcontroller/presentedviewcontroller
/// https://developer.apple.com/documentation/uikit/uiviewcontroller/presentingviewcontroller
/// https://api.flutter.dev/ios-embedder/protocol_flutter_plugin_registrar-p.html
/// https://developer.apple.com/documentation/swift/checkedcontinuation
/// https://developer.apple.com/documentation/swift/mainactor/run(resulttype:body:)
/// https://developer.apple.com/documentation/foundation/jsonencoder
extension Engine {
    /// Shows the picker on the topmost controller the view controller of the registrar presents, keeps what she
    /// chose in `media.picked` and gives its count. A picker she cancels or swipes away gives 0. With no view
    /// controller, or a picker UIKit did not show, the call is logged and gives 0.
    func pick(photos: Bool, limit: Int64) async throws -> Int64 {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                // One picker shows at a time, as the one sheet of m6: a call while one shows gives 0.
                guard self.media.videoPicker == nil else {
                    NSLog("%@", "pick: a picker shows already")
                    continuation.resume(returning: 0)
                    return
                }
                let picker = VideoPicker(closed: { items in
                    self.media.picked = items
                    self.media.videoPicker = nil
                    continuation.resume(returning: Int64(items.count))
                }, limit: Int(limit), photos: photos)
                guard var viewController = self.registrar.viewController else {
                    NSLog("%@", "pick: no view controller to show the picker on")
                    picker.report([])
                    return
                }
                while let presented = viewController.presentedViewController {
                    viewController = presented
                }
                self.media.videoPicker = picker
                let controller = picker.makeUIViewController()
                viewController.present(controller, animated: true)
                // UIKit drops a presentation on a controller that is being dismissed, with only a warning.
                if controller.presentingViewController == nil {
                    NSLog("%@", "pick: the picker was not shown")
                    picker.report([])
                }
            }
        }
    }

    /// Copies the items of the last `pick` into the folder with `copyPicked(_:into:)` and gives the JSON of each
    /// fact, in the order of choosing.
    func copyPicked(folder: String) async throws -> [String] {
        let items = await MainActor.run { self.media.picked }
        let facts = await Reelsmith.copyPicked(items, into: URL(fileURLWithPath: folder))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try facts.map { String(decoding: try encoder.encode($0), as: UTF8.self) }
    }
}

/// The system photo picker for videos, and for photos too when `photos` is true. With the limit 0, the default,
/// more than one may be chosen and the order of choosing is kept. With a limit, as the one of the music part, the selection is left at the picker's default.
/// It is made with no photo library, so it runs outside the app and no permission is asked.
/// `closed` gets the chosen items in the order of choosing, none when she cancelled or swiped the picker away.
/// It is the delegate of the picker and of its presentation, which hold it weakly, so `media` keeps it while it shows.
///
/// https://developer.apple.com/documentation/photosui/phpickerviewcontroller
/// https://developer.apple.com/documentation/photosui/phpickerconfiguration/init()
/// https://developer.apple.com/documentation/photosui/phpickerconfiguration/filter
/// https://developer.apple.com/documentation/photosui/phpickerfilter/any(of:)
/// https://developer.apple.com/documentation/photosui/phpickerconfiguration/selectionlimit
/// https://developer.apple.com/documentation/photosui/phpickerconfiguration/selection-swift.property
/// https://developer.apple.com/documentation/photosui/phpickerviewcontrollerdelegate/picker(_:didfinishpicking:)
/// https://developer.apple.com/documentation/photosui/phpickerresult/itemprovider
/// https://developer.apple.com/documentation/uikit/uiviewcontroller/presentationcontroller
/// https://developer.apple.com/documentation/uikit/uiadaptivepresentationcontrollerdelegate/presentationcontrollerdiddismiss(_:)
/// https://developer.apple.com/documentation/uikit/uiviewcontroller/dismiss(animated:completion:)
@MainActor
final class VideoPicker: NSObject, PHPickerViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
    private let closed: @MainActor ([NSItemProvider]) -> Void
    /// The most videos she may choose. Zero is no limit.
    private let limit: Int
    /// Photos are offered beside the videos.
    private let photos: Bool
    private var reported = false

    init(closed: @escaping @MainActor ([NSItemProvider]) -> Void, limit: Int = 0, photos: Bool = false) {
        self.closed = closed
        self.limit = limit
        self.photos = photos
    }

    func makeUIViewController() -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = photos ? .any(of: [.videos, .images]) : .videos
        configuration.selectionLimit = limit
        // The order of choosing is kept only with no limit.
        if limit == 0 {
            configuration.selection = .ordered
        }
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        picker.presentationController?.delegate = self
        return picker
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        report(results.map { $0.itemProvider })
    }

    /// She swiped the picker away.
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        report([])
    }

    /// Hands the items to `closed`, once.
    func report(_ items: [NSItemProvider]) {
        // One picker closes once: a second report would start a second copy.
        guard !reported else { return }
        reported = true
        closed(items)
    }
}

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
