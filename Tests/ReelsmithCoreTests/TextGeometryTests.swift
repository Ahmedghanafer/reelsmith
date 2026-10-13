import ReelsmithCore
import XCTest

final class TextGeometryTests: XCTestCase {
    private let one = TextID(1)
    private let two = TextID(2)

    /// The landscape project of two clips with two texts that are not blank, at the two centres.
    private func twoTexts(_ firstX: Double, _ firstY: Double, _ secondX: Double, _ secondY: Double) -> Project {
        var first = textItem(1, "a", .whole)
        first.x = firstX
        first.y = firstY
        var second = textItem(2, "b", .whole)
        second.x = secondX
        second.y = secondY
        var project = Seed.twoClipsWide.project
        project.texts = [first, second]
        project.nextTextID = 3
        return project
    }

    func testTheLimitsOfATextSizeAndOfATextLength() {
        XCTAssertEqual(TextGeometry.minimumSize, 16)
        XCTAssertEqual(TextGeometry.maximumSize, 400)
        XCTAssertEqual(TextGeometry.wrapShare, 0.8)
        XCTAssertEqual(TextGeometry.minimumText, Time(ticks: 60))
        XCTAssertEqual(TextGeometry.minimumText, TimelineGeometry.minimumClip)
    }

    func testPointsOfThePictureBecomeCanvasPixels() {
        XCTAssertEqual(TextGeometry.canvasLength(ofPoints: 100, pictureWidth: 400, canvas: .landscape), 480)
        XCTAssertEqual(TextGeometry.canvasLength(ofPoints: -100, pictureWidth: 400, canvas: .landscape), -480)
        XCTAssertEqual(TextGeometry.canvasLength(ofPoints: 100, pictureWidth: 400, canvas: .portrait), 270)
    }

    func testAPictureWithNoWidthGivesNoLength() {
        XCTAssertEqual(TextGeometry.canvasLength(ofPoints: 100, pictureWidth: 0, canvas: .landscape), 0)
        XCTAssertEqual(TextGeometry.canvasLength(ofPoints: 100, pictureWidth: -400, canvas: .landscape), 0)
    }

    func testTheOneTextIsTheNearestFromAnyPlace() {
        XCTAssertEqual(Seed.textWide.project.text(nearestToX: 0, y: 0, at: .zero), one)
    }

    func testTheNearestOfTwoTextsSideBySide() {
        let project = twoTexts(400, 540, 1500, 540)

        XCTAssertEqual(project.text(nearestToX: 500, y: 540, at: .zero), one)
        XCTAssertEqual(project.text(nearestToX: 1400, y: 540, at: .zero), two)
        XCTAssertEqual(project.text(nearestToX: 949, y: 540, at: .zero), one)
        XCTAssertEqual(project.text(nearestToX: 951, y: 540, at: .zero), two)
    }

    func testTheNearestOfTwoTextsOneAboveTheOther() {
        let project = twoTexts(960, 100, 960, 900)

        XCTAssertEqual(project.text(nearestToX: 960, y: 200, at: .zero), one)
        XCTAssertEqual(project.text(nearestToX: 960, y: 800, at: .zero), two)
    }

    func testTheLaterTextOfTheListWinsATie() {
        XCTAssertEqual(twoTexts(960, 540, 960, 540).text(nearestToX: 100, y: 100, at: .zero), two)
        XCTAssertEqual(twoTexts(400, 540, 1500, 540).text(nearestToX: 950, y: 540, at: .zero), two)
    }

    func testABlankTextIsNeverTheNearest() {
        var project = twoTexts(400, 540, 1500, 540)
        project.texts[1].string = " \n"

        XCTAssertEqual(project.text(nearestToX: 1500, y: 540, at: .zero), one)

        project.texts[0].string = ""

        XCTAssertNil(project.text(nearestToX: 1500, y: 540, at: .zero))
    }

    func testOnlyATextWhoseRangeHoldsTheTimeIsGiven() {
        let project = Seed.textBoxWide.project

        XCTAssertNil(project.text(nearestToX: 960, y: 540, at: Time(ticks: 580)))
        XCTAssertNil(project.text(nearestToX: 960, y: 540, at: Time(ticks: 599)))
        XCTAssertEqual(project.text(nearestToX: 960, y: 540, at: Time(ticks: 600)), one)
        XCTAssertEqual(project.text(nearestToX: 960, y: 540, at: Time(ticks: 1480)), one)
        XCTAssertEqual(project.text(nearestToX: 960, y: 540, at: Time(ticks: 1499)), one)
        XCTAssertNil(project.text(nearestToX: 960, y: 540, at: Time(ticks: 1500)))
    }

    func testAProjectWithNoTextHasNoNearestText() {
        XCTAssertNil(Seed.twoClipsWide.project.text(nearestToX: 960, y: 540, at: .zero))
    }
}
