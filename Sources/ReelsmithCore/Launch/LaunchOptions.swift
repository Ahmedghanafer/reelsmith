import Foundation

/// The launch values. The type always parses what it is given. The debug guard sits in the app:
/// a debug build passes the process arguments, a release build passes an empty list.
public struct LaunchOptions: Equatable, Sendable {
    /// `-seed <name>`. An unknown name gives nil and the app opens as with no seed.
    public var seed: Seed?
    /// `-playhead <ticks>`, used with a seed.
    public var playhead: Time?
    /// `-export-fails`: the export is given an output place that cannot be written.
    public var exportFails: Bool
    /// `-drafts fresh` or `-drafts kept`. Nil for none and for another value.
    public var drafts: DraftsLaunch?
    /// `-draft-fixture <name>`: the fixture `<name>.json` of `Tests/Fixtures/Drafts/swift/`, opened as a draft by a UI
    /// test. Nil when not given.
    public var draftFixture: String?

    public init(arguments: [String]) {
        seed = nil
        playhead = nil
        exportFails = false
        drafts = nil
        draftFixture = nil
        for (index, argument) in arguments.enumerated() {
            let value = index + 1 < arguments.count ? arguments[index + 1] : ""
            switch argument {
            case "-seed":
                seed = Seed(rawValue: value)
            case "-playhead":
                playhead = Int64(value).map { Time(ticks: $0) }
            case "-export-fails":
                exportFails = true
            case "-drafts":
                drafts = DraftsLaunch(rawValue: value)
            case "-draft-fixture":
                draftFixture = value
            default:
                break
            }
        }
    }

    /// A seed is set, or drafts is set.
    public var showsInfo: Bool {
        seed != nil || drafts != nil
    }

    /// `<caches>/TestDrafts` with drafts set, `<applicationSupport>/Drafts` without.
    public func draftsFolder(applicationSupport: URL, caches: URL) -> URL {
        drafts == nil ? applicationSupport.appendingPathComponent("Drafts") : caches.appendingPathComponent("TestDrafts")
    }
}

public enum DraftsLaunch: String, Equatable, Sendable {
    /// `-drafts fresh`
    case fresh
    /// `-drafts kept`
    case kept
}
