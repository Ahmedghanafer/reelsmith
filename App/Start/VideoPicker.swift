import PhotosUI
import SwiftUI

/// The system photo picker for videos. With the limit 0, the default, more than one may be chosen and the order
/// of choosing is kept. With a limit of one the selection is left at the picker's default.
/// It is made with no photo library, so it runs outside the app and no permission is asked.
/// `closed` gets the chosen videos in the order of choosing, none when she cancelled.
///
/// https://developer.apple.com/documentation/photosui/phpickerviewcontroller
/// https://developer.apple.com/documentation/photosui/phpickerconfiguration/init()
/// https://developer.apple.com/documentation/photosui/phpickerconfiguration/filter
/// https://developer.apple.com/documentation/photosui/phpickerconfiguration/selectionlimit
/// https://developer.apple.com/documentation/photosui/phpickerconfiguration/selection-swift.property
/// https://developer.apple.com/documentation/photosui/phpickerviewcontrollerdelegate/picker(_:didfinishpicking:)
/// https://developer.apple.com/documentation/photosui/phpickerresult/itemprovider
/// https://developer.apple.com/documentation/swiftui/uiviewcontrollerrepresentable
struct VideoPicker: UIViewControllerRepresentable {
    let closed: @MainActor ([NSItemProvider]) -> Void
    /// The most videos she may choose. Zero is no limit.
    var limit: Int = 0

    func makeCoordinator() -> Coordinator {
        Coordinator(closed: closed)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        configuration.selectionLimit = limit
        // The order of choosing is kept only with no limit.
        if limit == 0 {
            configuration.selection = .ordered
        }
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: PHPickerViewController, context: Context) {
    }

    @MainActor
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let closed: @MainActor ([NSItemProvider]) -> Void
        private var reported = false

        init(closed: @escaping @MainActor ([NSItemProvider]) -> Void) {
            self.closed = closed
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // One picker closes once: a second report would start a second copy.
            guard !reported else { return }
            reported = true
            closed(results.map { $0.itemProvider })
        }
    }
}
