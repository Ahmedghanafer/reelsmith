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
/// https://api.flutter.dev/ios-embedder/protocol_flutter_plugin_registrar-p.html
/// https://developer.apple.com/documentation/swift/checkedcontinuation
extension Engine {
    /// Shows the question with a destructive button `drafts.deleteConfirm` and a cancel button
    /// `drafts.deleteCancel`, and gives true when she confirmed. With no view controller to show it on, or one that already shows
    /// something, false.
    func confirm(question: String, confirmWords: String, cancelWords: String) async throws -> Bool {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                // UIKit drops a second presentation, so a question asked while one shows gives false at once.
                guard let viewController = self.registrar.viewController,
                      viewController.presentedViewController == nil else {
                    continuation.resume(returning: false)
                    return
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
            }
        }
    }
}
