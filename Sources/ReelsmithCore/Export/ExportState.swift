/// The one value the export button and its panel draw.
public enum ExportState: Equatable, Sendable {
    case idle
    /// The percent goes from 0 to 100 and never down.
    case exporting(percent: Int)
    case saved
    /// `notAllowed` is true when the photo library refused the file for lack of the right to add.
    case failed(notAllowed: Bool)

    /// What happened to an export.
    public enum Event: Equatable, Sendable {
        /// She tapped the export button.
        case started
        /// The Engine reported progress, from 0 to 1.
        case progress(Double)
        /// The file is in the photo library.
        case saved
        case failed(notAllowed: Bool)
        /// She closed the saved or the failed panel.
        case closed
    }

    /// Every key `words` can give.
    public static let allWords: [String] = ["export.exporting", "export.saved", "export.failed", "export.notAllowed"]

    public var words: Words? {
        switch self {
        case .idle:
            return nil
        case .exporting:
            return Words("export.exporting")
        case .saved:
            return Words("export.saved")
        case .failed(let notAllowed):
            return Words(notAllowed ? "export.notAllowed" : "export.failed")
        }
    }

    /// The progress while exporting, such as "42%", with the digits 0 to 9 in every language.
    public var percentText: String? {
        guard case .exporting(let percent) = self else { return nil }
        return String(percent) + "%"
    }

    /// Whether a tap on the export button starts an export.
    public func canStart(_ editor: EditorState) -> Bool {
        self == .idle && editor.canExport
    }

    /// The moves between the cases. An event that has no meaning in a case leaves it unchanged.
    public func after(_ event: Event) -> ExportState {
        switch (self, event) {
        case (.idle, .started):
            return .exporting(percent: 0)
        // A value that is not a number is not above zero and changes nothing.
        case (.exporting(let percent), .progress(let value)) where value > 0:
            return .exporting(percent: max(percent, Int(min(value, 1) * 100)))
        case (.exporting, .saved):
            return .saved
        case (.exporting, .failed(let notAllowed)):
            return .failed(notAllowed: notAllowed)
        case (.saved, .closed), (.failed, .closed):
            return .idle
        default:
            return self
        }
    }
}
