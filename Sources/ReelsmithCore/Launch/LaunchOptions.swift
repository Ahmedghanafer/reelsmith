/// The three launch values. The type always parses what it is given. The debug guard sits in the app:
/// a debug build passes the process arguments, a release build passes an empty list.
public struct LaunchOptions: Equatable, Sendable {
    /// `-seed <name>`. An unknown name gives nil and the app opens as with no seed.
    public var seed: Seed?
    /// `-playhead <ticks>`, used with a seed.
    public var playhead: Time?
    /// `-export-fails`: the export is given an output place that cannot be written.
    public var exportFails: Bool

    public init(arguments: [String]) {
        seed = nil
        playhead = nil
        exportFails = false
    }
}
