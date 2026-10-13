import ReelsmithCore
import XCTest

final class TextEditsTests: XCTestCase {
    private let one = TextID(1)
    private let blue = ClipID(1)
    private let red = ClipID(2)
    private let wide = EditorState(project: Seed.twoClipsWide.project)
    private let tall = EditorState(project: Seed.twoClips.project)
    private let textWide = EditorState(project: Seed.textWide.project)
    private let textBoxWide = EditorState(project: Seed.textBoxWide.project)

    private func assertValid(_ state: EditorState, line: UInt = #line) {
        let project = state.project
        let ids = project.texts.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count, "a text id is used twice", line: line)
        for text in project.texts {
            if case .range(let range) = text.span {
                XCTAssertGreaterThanOrEqual(range.start, Time.zero, "the start of a range", line: line)
                XCTAssertEqual(range.start.ticks % Time.frame.ticks, 0, "the start of a range", line: line)
                XCTAssertEqual(range.duration.ticks % Time.frame.ticks, 0, "the length of a range", line: line)
                XCTAssertGreaterThanOrEqual(range.duration, TextGeometry.minimumText, "the length of a range", line: line)
            }
            XCTAssertGreaterThanOrEqual(text.style.size, 16, "the size", line: line)
            XCTAssertLessThanOrEqual(text.style.size, 400, "the size", line: line)
            XCTAssertGreaterThanOrEqual(text.x, 0, "the centre", line: line)
            XCTAssertLessThanOrEqual(text.x, Double(project.canvas.width), "the centre", line: line)
            XCTAssertGreaterThanOrEqual(text.y, 0, "the centre", line: line)
            XCTAssertLessThanOrEqual(text.y, Double(project.canvas.height), "the centre", line: line)
            XCTAssertGreaterThan(text.rotation, -180, "the rotation", line: line)
            XCTAssertLessThanOrEqual(text.rotation, 180, "the rotation", line: line)
            if text.isBlank {
                XCTAssertEqual(state.selectedText, text.id, "a blank text that is not selected", line: line)
            }
        }
        if let selected = state.selectedText {
            XCTAssertNotNil(project.text(selected), "the selected text is not in the project", line: line)
        }
        XCTAssertFalse(state.selection != nil && state.selectedText != nil, "two selections", line: line)
    }

    /// Sends the actions one by one. The state must be valid after each.
    private func send(_ state: EditorState, _ actions: EditorAction..., line: UInt = #line) -> EditorState {
        var next = state
        for action in actions {
            next = reduce(next, action)
            assertValid(next, line: line)
        }
        return next
    }

    private func sendText(_ state: EditorState, _ actions: TextAction..., line: UInt = #line) -> EditorState {
        var next = state
        for action in actions {
            next = reduce(next, .text(action))
            assertValid(next, line: line)
        }
        return next
    }

    private func playing(_ state: EditorState) -> EditorState {
        var next = state
        next.isPlaying = true
        return next
    }

    /// The state of a two clip seed with its red clip deleted and its blue clip cut to the length.
    private func shortened(_ state: EditorState, to ticks: Int64) -> EditorState {
        send(state, .select(red), .deleteSelected, .trimEnd(blue, by: Time(ticks: 1800 - ticks)))
    }

    private func range(_ start: Int64, _ duration: Int64) -> TextSpan {
        TextSpan.range(TextRange(start: Time(ticks: start), duration: Time(ticks: duration)))
    }

    private func span(_ state: EditorState) -> TextSpan? {
        state.project.text(one)?.span
    }

    private func afterTrimStart(_ state: EditorState, by ticks: Int64, line: UInt = #line) -> TextSpan? {
        span(sendText(state, .trimStart(one, by: Time(ticks: ticks)), line: line))
    }

    private func afterTrimEnd(_ state: EditorState, by ticks: Int64, line: UInt = #line) -> TextSpan? {
        span(sendText(state, .trimEnd(one, by: Time(ticks: ticks)), line: line))
    }

    private func sizeAfter(_ size: Double, line: UInt = #line) -> Double? {
        var style = TextStyle.standard
        style.size = size
        return sendText(textWide, .setStyle(one, style), line: line).project.text(one)?.style.size
    }

    private func spacingAfter(_ spacing: Double, line: UInt = #line) -> Double? {
        var style = TextStyle.standard
        style.lineSpacing = spacing
        return sendText(textWide, .setStyle(one, style), line: line).project.text(one)?.style.lineSpacing
    }

    /// The centre of text 1 after a move, as x then y.
    private func centreAfter(_ state: EditorState, _ x: Double, _ y: Double, line: UInt = #line) -> [Double] {
        let text = sendText(state, .move(one, x: x, y: y), line: line).project.text(one)
        return [text?.x ?? -1, text?.y ?? -1]
    }

    private func angleAfter(_ angle: Double, line: UInt = #line) -> Double? {
        sendText(textWide, .turn(one, to: angle), line: line).project.text(one)?.rotation
    }

    // Add

    func testAddPutsOneStandardTextInTheMiddleOfTheCanvasAndSelectsIt() {
        var start = playing(wide)
        start.selection = blue

        let next = sendText(start, .add)

        XCTAssertEqual(next.project.texts, [
            TextItem(id: one, string: "", span: .whole, x: 960, y: 540, rotation: 0, style: .standard),
        ])
        XCTAssertEqual(next.project.texts.first?.style.size, 64)
        XCTAssertEqual(next.selectedText, one)
        XCTAssertNil(next.selection)
        XCTAssertEqual(next.project.nextTextID, 2)
        XCTAssertFalse(next.isPlaying)
    }

    func testAddOnThePortraitCanvasPutsTheTextInItsMiddle() {
        let next = sendText(tall, .add)

        XCTAssertEqual(next.project.texts.map { [$0.x, $0.y] }, [[540, 960]])
    }

    func testAddOnAnEmptyProjectChangesNothing() {
        let empty = playing(EditorState(project: Seed.empty.project))

        XCTAssertEqual(sendText(empty, .add), empty)
    }

    func testASecondTextIsTheLastOfTheListWithId2() {
        let next = sendText(wide, .add, .setString(one, "a"), .add)

        XCTAssertEqual(next.project.texts.map { $0.id }, [one, TextID(2)])
        XCTAssertEqual(next.selectedText, TextID(2))
        XCTAssertEqual(next.project.nextTextID, 3)
    }

    func testAnIdIsNotUsedAgainAfterADelete() {
        let next = send(wide, .text(.add), .deleteSelected, .text(.add))

        XCTAssertEqual(next.project.texts.map { $0.id }, [TextID(2)])
        XCTAssertEqual(next.project.nextTextID, 3)
    }

    // Select

    func testSelectSetsTheSelectedTextClearsTheClipAndLeavesPlayingAlone() {
        var start = textWide
        start.selection = blue

        let paused = sendText(start, .select(one))
        let played = sendText(playing(start), .select(one))

        XCTAssertEqual(paused.selectedText, one)
        XCTAssertNil(paused.selection)
        XCTAssertFalse(paused.isPlaying)
        XCTAssertEqual(played.selectedText, one)
        XCTAssertNil(played.selection)
        XCTAssertTrue(played.isPlaying)
    }

    func testSelectOfAnUnknownTextChangesNothing() {
        var start = textWide
        start.selection = blue

        XCTAssertEqual(sendText(start, .select(TextID(99))), start)
    }

    // The blank rule

    func testABlankTextGoesWhenTheSelectionIsCleared() {
        let next = send(wide, .text(.add), .clearSelection)

        XCTAssertEqual(next.project.texts, [])
        XCTAssertNil(next.selectedText)
    }

    func testABlankTextGoesWhenAClipIsSelected() {
        let next = send(wide, .text(.add), .select(blue))

        XCTAssertEqual(next.project.texts, [])
        XCTAssertEqual(next.selection, blue)
    }

    func testABlankTextGoesWhenAnotherTextIsAdded() {
        let next = sendText(wide, .add, .add)

        XCTAssertEqual(next.project.texts.map { $0.id }, [TextID(2)])
        XCTAssertEqual(next.selectedText, TextID(2))
    }

    func testATextWithALetterStaysWhenTheSelectionIsCleared() {
        let next = send(wide, .text(.add), .text(.setString(one, "a")), .clearSelection)

        XCTAssertEqual(next.project.texts.map { $0.string }, ["a"])
        XCTAssertNil(next.selectedText)
    }

    func testATextSetBackToOneSpaceGoesWhenTheSelectionIsCleared() {
        let next = send(
            wide, .text(.add), .text(.setString(one, "a")), .text(.setString(one, " ")), .clearSelection)

        XCTAssertEqual(next.project.texts, [])
    }

    func testATextThatIsNotBlankStaysAsItWasAfterSelectAndClear() {
        let next = send(textWide, .text(.select(one)), .clearSelection)

        XCTAssertEqual(next.project.texts, Seed.textWide.project.texts)
        XCTAssertNil(next.selectedText)
    }

    // The string

    func testAStringIsStoredAsGivenScalarForScalar() {
        let given = "  a\n" + arabicLine() + "  "
        let head: [UInt32] = [0x20, 0x20, 0x61, 0x0A]
        let tail: [UInt32] = [0x20, 0x20]
        let expected: [UInt32] = head + arabicLineScalars + tail

        let next = sendText(playing(wide), .add, .setString(one, given))
        let stored: [UInt32] = (next.project.text(one)?.string ?? "").unicodeScalars.map { $0.value }

        XCTAssertEqual(stored, expected)
    }

    func testSetStringPauses() {
        let next = sendText(playing(textWide), .setString(one, "a"))

        XCTAssertEqual(next.project.text(one)?.string, "a")
        XCTAssertFalse(next.isPlaying)
    }

    // The style

    func testASizeIsHeldAt16FromBelow() {
        XCTAssertEqual(sizeAfter(16.5), 16.5)
        XCTAssertEqual(sizeAfter(16), 16)
        XCTAssertEqual(sizeAfter(15.5), 16)
        XCTAssertEqual(sizeAfter(5), 16)
    }

    func testASizeIsHeldAt400FromAbove() {
        XCTAssertEqual(sizeAfter(399.5), 399.5)
        XCTAssertEqual(sizeAfter(400), 400)
        XCTAssertEqual(sizeAfter(400.5), 400)
        XCTAssertEqual(sizeAfter(1000), 400)
    }

    func testALineSpacingIsHeldAt0FromBelow() {
        XCTAssertEqual(spacingAfter(0.25), 0.25)
        XCTAssertEqual(spacingAfter(0), 0)
        XCTAssertEqual(spacingAfter(-0.25), 0)
        XCTAssertEqual(spacingAfter(-1), 0)
    }

    func testALineSpacingIsHeldAt2FromAbove() {
        XCTAssertEqual(spacingAfter(1.75), 1.75)
        XCTAssertEqual(spacingAfter(2), 2)
        XCTAssertEqual(spacingAfter(2.25), 2)
        XCTAssertEqual(spacingAfter(3), 2)
    }

    func testTheRestOfAStyleIsStoredAsGivenAndSetStylePauses() {
        let given = TextStyle(
            font: .system, size: 100, colour: RGB(r: 10, g: 132, b: 255), align: .right, lineSpacing: 1,
            outline: true, shadow: true, box: true)

        let next = sendText(playing(textWide), .setStyle(one, given))

        XCTAssertEqual(next.project.text(one)?.style, given)
        XCTAssertFalse(next.isPlaying)
    }

    // The centre

    func testAMoveInsideTheCanvasIsStoredAsGivenAndPauses() {
        let next = sendText(playing(textWide), .move(one, x: 300, y: 200))

        XCTAssertEqual(next.project.text(one)?.x, 300)
        XCTAssertEqual(next.project.text(one)?.y, 200)
        XCTAssertFalse(next.isPlaying)
    }

    func testACentreIsHeldAtTheLeftEdge() {
        XCTAssertEqual(centreAfter(textWide, 1, 500), [1, 500])
        XCTAssertEqual(centreAfter(textWide, 0, 500), [0, 500])
        XCTAssertEqual(centreAfter(textWide, -1, 500), [0, 500])
    }

    func testACentreIsHeldAtTheRightEdge() {
        XCTAssertEqual(centreAfter(textWide, 1919, 500), [1919, 500])
        XCTAssertEqual(centreAfter(textWide, 1920, 500), [1920, 500])
        XCTAssertEqual(centreAfter(textWide, 1921, 500), [1920, 500])
    }

    func testACentreIsHeldAtTheTopEdge() {
        XCTAssertEqual(centreAfter(textWide, 500, 1), [500, 1])
        XCTAssertEqual(centreAfter(textWide, 500, 0), [500, 0])
        XCTAssertEqual(centreAfter(textWide, 500, -1), [500, 0])
    }

    func testACentreIsHeldAtTheBottomEdge() {
        XCTAssertEqual(centreAfter(textWide, 500, 1079), [500, 1079])
        XCTAssertEqual(centreAfter(textWide, 500, 1080), [500, 1080])
        XCTAssertEqual(centreAfter(textWide, 500, 1081), [500, 1080])
    }

    func testTheCornersOfTheLandscapeCanvasAreInside() {
        XCTAssertEqual(centreAfter(textWide, 5000, -5), [1920, 0])
        XCTAssertEqual(centreAfter(textWide, 1920, 1080), [1920, 1080])
        XCTAssertEqual(centreAfter(textWide, 0, 0), [0, 0])
    }

    func testACentreIsHeldInsideThePortraitCanvas() {
        let start = sendText(tall, .add)

        XCTAssertEqual(centreAfter(start, -1, 3000), [0, 1920])
        XCTAssertEqual(centreAfter(start, 1080, 1920), [1080, 1920])
        XCTAssertEqual(centreAfter(start, 1081, 1921), [1080, 1920])
    }

    // The rotation

    func testATurnInsideTheLimitsIsStoredAsGivenAndPauses() {
        let next = sendText(playing(textWide), .turn(one, to: 90))

        XCTAssertEqual(next.project.text(one)?.rotation, 90)
        XCTAssertFalse(next.isPlaying)
    }

    func testATurnPast180ComesBackFromTheOtherSide() {
        XCTAssertEqual(angleAfter(179), 179)
        XCTAssertEqual(angleAfter(180), 180)
        XCTAssertEqual(angleAfter(181), -179)
        XCTAssertEqual(angleAfter(190), -170)
        XCTAssertEqual(angleAfter(540), 180)
    }

    func testATurnToMinus180OrBelowComesBackFromTheOtherSide() {
        XCTAssertEqual(angleAfter(-179), -179)
        XCTAssertEqual(angleAfter(-180), 180)
        XCTAssertEqual(angleAfter(-181), 179)
        XCTAssertEqual(angleAfter(-190), 170)
    }

    func testATurnAtMost3Above0Becomes0() {
        XCTAssertEqual(angleAfter(2), 0)
        XCTAssertEqual(angleAfter(3), 0)
        XCTAssertEqual(angleAfter(3.5), 3.5)
        XCTAssertEqual(angleAfter(362), 0)
    }

    func testATurnAtMost3Below0Becomes0() {
        XCTAssertEqual(angleAfter(-2), 0)
        XCTAssertEqual(angleAfter(-3), 0)
        XCTAssertEqual(angleAfter(-3.5), -3.5)
    }

    // The trims

    func testATrimOfTheStartStoresARangeRoundedTowardZeroToWholeFrames() {
        XCTAssertEqual(afterTrimStart(textWide, by: 600), range(600, 3600))
        XCTAssertEqual(afterTrimStart(textWide, by: 619), range(600, 3600))
        XCTAssertEqual(afterTrimStart(textBoxWide, by: -39), range(580, 920))
    }

    func testATrimOfTheEndStoresARangeRoundedTowardZeroToWholeFrames() {
        XCTAssertEqual(afterTrimEnd(textWide, by: 600), range(0, 3600))
        XCTAssertEqual(afterTrimEnd(textWide, by: 619), range(0, 3600))
        XCTAssertEqual(afterTrimEnd(textBoxWide, by: -39), range(600, 920))
    }

    func testATrimOfTheStartLeavesAtLeastTheMinimumText() {
        XCTAssertEqual(afterTrimStart(textBoxWide, by: 820), range(1420, 80))
        XCTAssertEqual(afterTrimStart(textBoxWide, by: 840), range(1440, 60))
        XCTAssertEqual(afterTrimStart(textBoxWide, by: 860), range(1440, 60))
        XCTAssertEqual(afterTrimStart(textWide, by: 9000), range(4140, 60))
    }

    func testATrimOfTheEndLeavesAtLeastTheMinimumText() {
        XCTAssertEqual(afterTrimEnd(textBoxWide, by: 820), range(600, 80))
        XCTAssertEqual(afterTrimEnd(textBoxWide, by: 840), range(600, 60))
        XCTAssertEqual(afterTrimEnd(textBoxWide, by: 860), range(600, 60))
        XCTAssertEqual(afterTrimEnd(textWide, by: 9000), range(0, 60))
    }

    func testATrimOfTheStartIsHeldAtTheStartOfTheProject() {
        XCTAssertEqual(afterTrimStart(textBoxWide, by: -580), range(20, 1480))
        XCTAssertEqual(afterTrimStart(textBoxWide, by: -600), range(0, 1500))
        XCTAssertEqual(afterTrimStart(textBoxWide, by: -620), range(0, 1500))
        XCTAssertEqual(afterTrimStart(textBoxWide, by: -9000), range(0, 1500))
    }

    func testATrimOfTheEndIsHeldAtTheEndOfTheProject() {
        XCTAssertEqual(afterTrimEnd(textBoxWide, by: -2680), range(600, 3580))
        XCTAssertEqual(afterTrimEnd(textBoxWide, by: -2700), range(600, 3600))
        XCTAssertEqual(afterTrimEnd(textBoxWide, by: -2720), range(600, 3600))
        XCTAssertEqual(afterTrimEnd(textBoxWide, by: -9000), range(600, 3600))
    }

    func testAResultFromZeroToTheProjectLengthIsStoredAsWhole() {
        let fromZero = sendText(textBoxWide, .trimStart(one, by: Time(ticks: -9000)))
        let fromTwenty = sendText(textWide, .trimStart(one, by: Time(ticks: 20)))

        XCTAssertEqual(span(fromZero), range(0, 1500))
        XCTAssertEqual(afterTrimEnd(fromZero, by: -2680), range(0, 4180))
        XCTAssertEqual(afterTrimEnd(fromZero, by: -9000), TextSpan.whole)
        XCTAssertEqual(span(fromTwenty), range(20, 4180))
        XCTAssertEqual(afterTrimStart(fromTwenty, by: -20), TextSpan.whole)
    }

    func testANegativeTrimOfAWholeTextLeavesItWhole() {
        XCTAssertEqual(afterTrimStart(textWide, by: -600), TextSpan.whole)
        XCTAssertEqual(afterTrimEnd(textWide, by: -600), TextSpan.whole)
    }

    func testATrimWorksOnTheRangeAsItIsSeen() {
        let cut = shortened(textBoxWide, to: 1200)

        XCTAssertEqual(cut.project.range(of: one), TextRange(start: Time(ticks: 600), duration: Time(ticks: 600)))
        XCTAssertEqual(afterTrimEnd(cut, by: 200), range(600, 400))
    }

    func testATrimOfATextWithNoRangeChangesNothing() {
        let past = playing(shortened(textBoxWide, to: 300))

        XCTAssertNil(past.project.range(of: one))
        XCTAssertEqual(sendText(past, .trimStart(one, by: Time(ticks: 20))), past)
        XCTAssertEqual(sendText(past, .trimEnd(one, by: Time(ticks: 20))), past)
    }

    func testATrimPauses() {
        XCTAssertFalse(sendText(playing(textWide), .trimStart(one, by: Time(ticks: 600))).isPlaying)
        XCTAssertFalse(sendText(playing(textWide), .trimEnd(one, by: Time(ticks: 600))).isPlaying)
    }

    func testATrimOfTheStartOfAShortRangeMovesTheStartBackToTheMinimumText() {
        let short = shortened(textBoxWide, to: 620)

        XCTAssertEqual(short.project.range(of: one), TextRange(start: Time(ticks: 600), duration: Time(ticks: 20)))
        XCTAssertEqual(afterTrimStart(short, by: 20), range(560, 60))
        XCTAssertEqual(afterTrimStart(short, by: 0), range(560, 60))
        XCTAssertEqual(afterTrimStart(short, by: 9000), range(560, 60))
    }

    func testATrimOfTheEndOfAShortRangeChangesNothing() {
        let short = playing(shortened(textBoxWide, to: 620))

        XCTAssertEqual(sendText(short, .trimEnd(one, by: Time(ticks: 20))), short)
        XCTAssertEqual(sendText(short, .trimEnd(one, by: Time(ticks: -20))), short)
    }

    // Delete

    func testDeleteRemovesTheSelectedTextAndTouchesNoClip() {
        let start = sendText(textWide, .select(one))

        let next = send(start, .deleteSelected)

        XCTAssertEqual(next.project.texts, [])
        XCTAssertNil(next.selectedText)
        XCTAssertEqual(next.project.clips, start.project.clips)
        XCTAssertEqual(next.project.clips.map { $0.id }, [blue, red])
        XCTAssertEqual(next.project.duration, Time(ticks: 4200))
    }

    func testDeleteIsEnabledForASelectedTextOfTheProject() {
        var unknown = textWide
        unknown.selectedText = TextID(99)
        let selected = sendText(textWide, .select(one))

        XCTAssertNil(selected.selection)
        XCTAssertTrue(selected.canDelete)
        XCTAssertFalse(textWide.canDelete)
        XCTAssertFalse(unknown.canDelete)
    }

    // Texts and clip actions

    func testNoClipActionChangesAText() {
        let texts = Seed.textBoxWide.project.texts
        var state = send(textBoxWide, .addClips([TestClip.green.info]))
        XCTAssertEqual(state.project.texts, texts)

        state = send(state, .movePlayhead(Time(ticks: 600)), .split)
        XCTAssertEqual(state.project.clips.count, 4)
        XCTAssertEqual(state.project.texts, texts)

        state = send(state, .trimStart(red, by: Time(ticks: 600)))
        XCTAssertEqual(state.project.texts, texts)

        state = send(state, .trimEnd(red, by: Time(ticks: 600)))
        XCTAssertEqual(state.project.duration, Time(ticks: 4200))
        XCTAssertEqual(state.project.texts, texts)

        while let first = state.project.clips.first {
            state = send(state, .select(first.id), .deleteSelected)
            XCTAssertEqual(state.project.texts, texts)
        }
        XCTAssertEqual(state.project.duration, Time.zero)
    }

    func testATextPastAShortenedProjectKeepsItsValuesAndComesBack() throws {
        let past = sendText(shortened(textBoxWide, to: 300), .select(one))

        XCTAssertEqual(past.project.texts, Seed.textBoxWide.project.texts)
        XCTAssertNil(past.project.range(of: one))
        XCTAssertEqual(past.textInfo.split(separator: " ").map(String.init)[8], "hidden")
        XCTAssertEqual(try renderPlan(for: past.project).texts, [])

        let longer = send(past, .addClips([TestClip.green.info, TestClip.fast.info]))

        XCTAssertEqual(longer.project.duration, Time(ticks: 2700))
        XCTAssertEqual(
            longer.project.range(of: one), TextRange(start: Time(ticks: 600), duration: Time(ticks: 900)))
    }

    func testAWholeTextFollowsTheProjectWhenAClipIsDeleted() {
        let next = send(textWide, .select(red), .deleteSelected)

        XCTAssertEqual(next.project.range(of: one), TextRange(start: .zero, duration: Time(ticks: 1800)))
    }

    // An unknown text

    func testEveryActionOnAnUnknownTextChangesNothing() {
        let unknown = TextID(99)
        let start = playing(textWide)
        let actions: [TextAction] = [
            .select(unknown), .setString(unknown, "a"), .setStyle(unknown, .standard),
            .move(unknown, x: 1, y: 2), .turn(unknown, to: 90), .trimStart(unknown, by: Time(ticks: 600)),
            .trimEnd(unknown, by: Time(ticks: 600)),
        ]

        for action in actions {
            XCTAssertEqual(sendText(start, action), start, "\(action)")
        }
    }
}
