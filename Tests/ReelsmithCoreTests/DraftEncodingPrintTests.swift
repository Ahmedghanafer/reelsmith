import Foundation
import ReelsmithCore
import XCTest

final class DraftEncodingPrintTests: XCTestCase {
    func testPrintTheEncodingOfMusicWide() throws {
        let draft = Draft(
            project: Seed.musicWide.project, exportSettings: ExportSettings(size: .uhd4K, rate: .sixty),
            changed: Date(timeIntervalSince1970: 1_792_011_909))
        print("ENCODED<" + String(decoding: try encodeDraft(draft), as: UTF8.self) + ">ENCODED")
    }
}
