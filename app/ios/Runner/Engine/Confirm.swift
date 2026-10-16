import Flutter
import Foundation
import UIKit

/// The delete question of the project list as a system alert, moved from `App/Start/DraftList.swift`.
///
/// https://developer.apple.com/documentation/uikit/uialertcontroller
/// https://developer.apple.com/documentation/uikit/uialertaction
/// https://developer.apple.com/documentation/uikit/uialertaction/style-swift.enum/destructive
/// https://developer.apple.com/documentation/uikit/uialertaction/style-swift.enum/cancel
/// https://developer.apple.com/documentation/uikit/uiaccessibilityidentification/accessibilityidentifier
/// https://developer.apple.com/documentation/uikit/uiviewcontroller/present(_:animated:completion:)
/// https://developer.apple.com/documentation/uikit/uiviewcontroller/presentedviewcontroller
/// https://developer.apple.com/documentation/uikit/uiviewcontroller/presentingviewcontroller
/// https://api.flutter.dev/ios-embedder/protocol_flutter_plugin_registrar-p.html
/// https://developer.apple.com/documentation/swift/checkedcontinuation
extension Engine {
    /// Shows the question with a destructive button `drafts.deleteConfirm` and a cancel button
    /// `drafts.deleteCancel`, and gives true when she confirmed. It is shown on the topmost controller the view
    /// controller of the registrar presents, since UIKit drops a presentation on one that already presents. With
    /// no view controller at all it is logged and gives false.
    func confirm(question: String, confirmWords: String, cancelWords: String) async throws -> Bool {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                guard var viewController = self.registrar.viewController else {
                    NSLog("%@", "confirm: no view controller to show the question on")
                    continuation.resume(returning: false)
                    return
                }
                while let presented = viewController.presentedViewController {
                    viewController = presented
                }
                let alert = UIAlertController(title: question, message: nil, preferredStyle: .alert)
                let delete = UIAlertAction(title: confirmWords, style: .destructive) { _ in
                    continuation.resume(returning: true)
                }
                delete.accessibilityIdentifier = "drafts.deleteConfirm"
                let cancel = UIAlertAction(title: cancelWords, style: .cancel) { _ in
                    continuation.resume(returning: false)
                }
                cancel.accessibilityIdentifier = "drafts.deleteCancel"
                alert.addAction(delete)
                alert.addAction(cancel)
                viewController.present(alert, animated: true)
                // UIKit drops a presentation on a controller that is being dismissed, with only a warning. A dropped
                // alert has no presenting controller and no button can answer, so the answer is false.
                if alert.presentingViewController == nil {
                    NSLog("%@", "confirm: the question was not shown")
                    continuation.resume(returning: false)
                }
            }
        }
    }
}
