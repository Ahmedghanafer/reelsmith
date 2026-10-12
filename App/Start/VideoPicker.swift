import PhotosUI
import SwiftUI

/// The system photo picker for videos: more than one may be chosen and the order of choosing is kept.
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

    func makeCoordinator() -> Coordinator {
        Coordinator(closed: closed)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        // Zero is no limit.
        configuration.selectionLimit = 0
        configuration.selection = .ordered
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: PHPickerViewController, context: Context) {
    }

    @MainActor
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let closed: @MainActor ([NSItemProvider]) -> Void

        init(closed: @escaping @MainActor ([NSItemProvider]) -> Void) {
            self.closed = closed
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            closed(results.map { $0.itemProvider })
        }
    }
}
