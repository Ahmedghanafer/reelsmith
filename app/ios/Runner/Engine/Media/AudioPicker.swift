import Foundation
import UIKit
import UniformTypeIdentifiers

/// The system file browser for one audio file, moved from the file importer of `App/Editor/Sound/MusicPart.swift`.
///
/// https://developer.apple.com/documentation/uikit/uiviewcontroller/present(_:animated:completion:)
/// https://developer.apple.com/documentation/uikit/uiviewcontroller/presentedviewcontroller
/// https://developer.apple.com/documentation/uikit/uiviewcontroller/presentingviewcontroller
/// https://api.flutter.dev/ios-embedder/protocol_flutter_plugin_registrar-p.html
/// https://developer.apple.com/documentation/swift/checkedcontinuation
extension Engine {
    /// Shows the browser on the topmost controller the view controller of the registrar presents, keeps the file
    /// she chose in `media.audio` and gives true. The file's URL carries the right to read it, which `importMusic`
    /// holds while it copies. A browser she cancels or swipes away gives false. With no view controller, or a
    /// browser UIKit did not show, the call is logged and gives false.
    func pickAudio() async throws -> Bool {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                let browser = AudioPicker { file in
                    self.media.audio = file
                    self.media.audioPicker = nil
                    continuation.resume(returning: file != nil)
                }
                guard var viewController = self.registrar.viewController else {
                    NSLog("%@", "pickAudio: no view controller to show the browser on")
                    browser.report(nil)
                    return
                }
                while let presented = viewController.presentedViewController {
                    viewController = presented
                }
                self.media.audioPicker = browser
                let controller = browser.makeUIViewController()
                viewController.present(controller, animated: true)
                // UIKit drops a presentation on a controller that is being dismissed, with only a warning.
                if controller.presentingViewController == nil {
                    NSLog("%@", "pickAudio: the browser was not shown")
                    browser.report(nil)
                }
            }
        }
    }
}

/// The system's file browser for one audio file, opened in place as the file importer of SwiftUI opens it.
/// `closed` gets the file she chose, nil when she cancelled or swiped the browser away. A failure of the browser
/// itself is taken as no pick. It is the delegate of the browser and of its presentation, which hold it weakly, so
/// `media` keeps it while it shows.
///
/// https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller/init(foropeningcontenttypes:ascopy:)
/// https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/audio
/// https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller/allowsmultipleselection
/// https://developer.apple.com/documentation/uikit/uidocumentpickerdelegate/documentpicker(_:didpickdocumentsat:)
/// https://developer.apple.com/documentation/uikit/uidocumentpickerdelegate/documentpickerwascancelled(_:)
/// https://developer.apple.com/documentation/uikit/uiviewcontroller/presentationcontroller
/// https://developer.apple.com/documentation/uikit/uiadaptivepresentationcontrollerdelegate/presentationcontrollerdiddismiss(_:)
@MainActor
final class AudioPicker: NSObject, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
    private let closed: @MainActor (URL?) -> Void
    private var reported = false

    init(closed: @escaping @MainActor (URL?) -> Void) {
        self.closed = closed
    }

    func makeUIViewController() -> UIDocumentPickerViewController {
        let browser = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.audio], asCopy: false)
        browser.allowsMultipleSelection = false
        browser.delegate = self
        browser.presentationController?.delegate = self
        return browser
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        report(urls.first)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        report(nil)
    }

    /// She swiped the browser away.
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        report(nil)
    }

    /// Hands the file to `closed`, once.
    func report(_ file: URL?) {
        guard !reported else { return }
        reported = true
        closed(file)
    }
}
