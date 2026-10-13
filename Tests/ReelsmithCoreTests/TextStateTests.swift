import ReelsmithCore
import XCTest

/// The name of a text action. The switch has no default, so a ninth case does not compile.
private func caseName(of action: TextAction) -> String {
    switch action {
    case .add:
        return "add"
    case .select:
        return "select"
    case .setString:
        return "setString"
    case .setStyle:
        return "setStyle"
    case .move:
        return "move"
    case .turn:
        return "turn"
    case .trimStart:
        return "trimStart"
    case .trimEnd:
        return "trimEnd"
    }
}

final class TextStateTests: XCTestCase {
    private func selected(_ project: Project) -> EditorState {
        var state = EditorState(project: project)
        state.selectedText = TextID(1)
        return state
    }

    func testTheEightTextActionsWithTheirLabels() {
        let id = TextID(1)
        let actions: [TextAction] = [
            .add, .select(id), .setString(id, "a"), .setStyle(id, .standard), .move(id, x: 1, y: 2),
            .turn(id, to: 3), .trimStart(id, by: Time(ticks: 20)), .trimEnd(id, by: Time(ticks: 20)),
        ]

        XCTAssertEqual(
            actions.map { caseName(of: $0) },
            ["add", "select", "setString", "setStyle", "move", "turn", "trimStart", "trimEnd"])
        XCTAssertEqual(EditorAction.text(.add), EditorAction.text(.add))
        XCTAssertNotEqual(EditorAction.text(.add), EditorAction.text(.select(id)))
    }

    func testANewStateHasNoSelectedText() {
        XCTAssertNil(EditorState(project: Seed.textWide.project).selectedText)
    }

    func testATextCanBeAddedWhenTheProjectHasAClip() {
        XCTAssertFalse(EditorState(project: Seed.empty.project).canAddText)
        XCTAssertTrue(EditorState(project: Seed.twoClips.project).canAddText)
    }

    func testSelectingAClipClearsTheSelectedText() {
        let next = reduce(selected(Seed.textWide.project), .select(ClipID(1)))

        XCTAssertNil(next.selectedText)
        XCTAssertEqual(next.selection, ClipID(1))
    }

    func testClearSelectionClearsBothSelections() {
        var clipSelected = EditorState(project: Seed.textWide.project)
        clipSelected.selection = ClipID(1)

        let afterText = reduce(selected(Seed.textWide.project), .clearSelection)
        let afterClip = reduce(clipSelected, .clearSelection)

        XCTAssertNil(afterText.selectedText)
        XCTAssertNil(afterText.selection)
        XCTAssertNil(afterClip.selectedText)
        XCTAssertNil(afterClip.selection)
    }

    func testTextInfoIsNoneWithNoSelectedText() {
        XCTAssertEqual(EditorState(project: Seed.textWide.project).textInfo, "none")
    }

    func testTextInfoOfTheTwoTextSeeds() {
        XCTAssertEqual(
            selected(Seed.textWide.project).textInfo, "1 naskh 64 255,255,255 centre 960,540 0 ... 0+4200 0")
        XCTAssertEqual(
            selected(Seed.textBoxWide.project).textInfo, "1 naskh 96 255,214,10 centre 960,540 0 ..b 600+900 0")
    }

    func testTextInfoReadsHiddenForATextWithNoRange() {
        var project = Seed.textBoxWide.project
        project.texts[0].span = .range(TextRange(start: Time(ticks: 4200), duration: Time(ticks: 600)))
        let info = selected(project).textInfo

        XCTAssertEqual(info, "1 naskh 96 255,214,10 centre 960,540 0 ..b hidden 0")
        XCTAssertEqual(info.split(separator: " ").map(String.init)[8], "hidden")
    }

    func testTextInfoRoundsToWholeNumbersAndReadsEveryField() {
        var project = Seed.twoClips.project
        project.texts = [
            textItem(1, "a", .whole),
            TextItem(
                id: TextID(2), string: "b",
                span: .range(TextRange(start: Time(ticks: 20), duration: Time(ticks: 60))),
                x: 100.4, y: 200.6, rotation: -29.6,
                style: TextStyle(
                    font: .naskhBold, size: 63.6, colour: RGB(r: 1, g: 2, b: 3), align: .right, lineSpacing: 0.5,
                    outline: true, shadow: true, box: false)),
        ]
        var state = EditorState(project: project)
        state.selectedText = TextID(2)
        let info = state.textInfo

        XCTAssertEqual(info, "2 naskh-bold 64 1,2,3 right 100,201 -30 os. 20+60 50")
        XCTAssertEqual(info.split(separator: " ").map(String.init)[9], "50")
    }
}
