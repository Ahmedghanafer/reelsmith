import XCTest

// The driver of the system photo picker, shared by every test that chooses a video of the library. The picker
// runs outside the app, so its controls read as not hittable and are tapped by coordinate, in the middle of their
// frames. They carry no identifier of ours and are found by the system's own identifier, by kind and by place,
// never by a word. Every line it prints begins with "picker:".
//
// https://developer.apple.com/documentation/xctest/xcuielement/waitforexistence(timeout:)
// https://developer.apple.com/documentation/xctest/xcuielementtypequeryprovider
// https://developer.apple.com/documentation/xctest/xcuielementquery/matching(identifier:)
// https://developer.apple.com/documentation/xctest/xcuielementsnapshotproviding/snapshot()
// https://developer.apple.com/documentation/xctest/xcuielementsnapshot/children
// https://developer.apple.com/documentation/xctest/xcuielementattributes/elementtype
// https://developer.apple.com/documentation/xctest/xcuielementattributes/frame
// https://developer.apple.com/documentation/xctest/xcuielementattributes/label
// https://developer.apple.com/documentation/xctest/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/withoffset(_:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/tap()
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
extension XCTestCase {
    /// For a picker that is opening or open. Waits for its grid, taps the named cells in the order given, counted
    /// from the end of the grid (1 is the last cell, the oldest video, which is blue, and 2 is red), each at a place
    /// read before the first tap, keeps the picture when one is named, and when `confirms` is true taps the control
    /// on the right of the picker's bar. Nil when all of it was done, else the step that found nothing. A read or a
    /// tap that raises fails the test like any other.
    func chooseInThePhotoPicker(_ app: XCUIApplication, fromTheEnd cells: [Int], confirms: Bool, picture: String?)
        -> String?
    {
        // The videos are the cells of the picker's grid, which the system names PXGGridLayout-Info.
        // The grid lists the newest first. The simulator run puts blue into the library and then red, and every
        // video an export saved is newer, so blue is the last cell and red the one before it.
        let gridCells = app.scrollViews.images.matching(identifier: "PXGGridLayout-Info")
        guard gridCells.firstMatch.waitForExistence(timeout: 40) else {
            return "no cell of the picker's grid came within 40 seconds"
        }
        // The other cells come with the first one. This is a pause, never a limit.
        Thread.sleep(forTimeInterval: 2)
        // The cells are read from one snapshot, in the order of the tree: of the scroll views, the one that
        // holds the most of them.
        guard let before = try? app.snapshot() else {
            return "no snapshot of the picker's grid could be taken"
        }
        var grid: [any XCUIElementSnapshot] = []
        for view in flattened(before) where view.elementType == .scrollView {
            let found = flattened(view).filter { $0.elementType == .image && $0.identifier == "PXGGridLayout-Info" }
            if found.count > grid.count {
                grid = found
            }
        }
        let count = grid.count
        let needed = cells.max() ?? 0
        print("picker: the picker's grid holds " + String(count) + " cells")
        guard count >= needed else {
            return "the picker's grid held " + String(count) + " cells, " + String(needed) + " are needed"
        }
        let chosen = cells.map { grid[count - $0] }
        for (place, cell) in zip(cells, chosen) {
            print("picker: cell \(place) from the end reads: " + cell.label + ", at \(cell.frame)")
        }
        let frames = chosen.map { $0.frame }
        guard frames.allSatisfy({ $0.width > 1 && $0.height > 1 }) else {
            return "a cell of the picker's grid had no frame to tap"
        }
        let top = ([grid[0].frame] + frames).map { $0.minY }.min() ?? 0
        // A tap may change the grid, so every tap goes to a place read before the first one.
        for (index, frame) in frames.enumerated() {
            tap(app, theMiddleOf: frame)
            // One second between two taps, two after the last.
            Thread.sleep(forTimeInterval: index == frames.count - 1 ? 2 : 1)
        }
        if let picture {
            screenshot(picture)
        }

        // The whole tree at each call, for the log of the run, and one snapshot of it for the search:
        // the picker changes after a choice, and a snapshot cannot change under the search.
        print("picker: the whole tree after the taps on the cells")
        print(app.debugDescription)
        guard confirms else {
            return nil
        }
        guard let tree = try? app.snapshot() else {
            return "no snapshot of the picker could be taken"
        }
        let all = flattened(tree).filter { !$0.identifier.hasPrefix("start.") && $0.frame.width > 1 }
        // The bar of the picker is the row of its topmost button.
        let bar = all.filter { $0.elementType == .button && $0.frame.midY < top }
            .min { $0.frame.minY < $1.frame.minY }
        guard let bar else {
            return "no button above the picker's grid was found"
        }
        // The control that confirms is found by place and by no word: of the small elements of any kind
        // in the row of the bar, the one furthest to the right, when it lies in the right third of the screen.
        let row = all.filter { abs($0.frame.midY - bar.frame.midY) <= 24 && $0.frame.width <= 120 }
        for one in row {
            print("picker: in the bar of the picker, kind \(one.elementType.rawValue) at \(one.frame): " + one.label)
        }
        let confirm = row.filter { $0.frame.midX > tree.frame.width * 2 / 3 }
            .max { $0.frame.maxX < $1.frame.maxX }
        guard let confirm else {
            return "no element was found on the right of the picker's bar"
        }
        print("picker: tapped to confirm, kind \(confirm.elementType.rawValue) at \(confirm.frame): " + confirm.label)
        tap(app, theMiddleOf: confirm.frame)
        return nil
    }

    /// Every element of a snapshot, the element itself first.
    func flattened(_ node: any XCUIElementSnapshot) -> [any XCUIElementSnapshot] {
        var all: [any XCUIElementSnapshot] = [node]
        for child in node.children {
            all += flattened(child)
        }
        return all
    }

    /// Taps the screen in the middle of a frame that was read from an element. The app fills the screen,
    /// so its top left corner is the zero point of the frames.
    func tap(_ app: XCUIApplication, theMiddleOf frame: CGRect) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: frame.midX, dy: frame.midY))
            .tap()
    }
}
