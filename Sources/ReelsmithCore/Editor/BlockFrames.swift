/// The frames along a block of the strip: the times a media's frames are made at, how many square tiles a block
/// holds, and which made frame each tile shows.
public enum BlockFrames {
    /// 600 ticks, one second.
    public static let step: Time = Time(ticks: 600)

    /// 0, step, and on, below the duration. [0] for a photo.
    public static func times(of media: MediaInfo) -> [Time] {
        if media.kind == .photo {
            return [Time.zero]
        }
        return stride(from: Int64(0), to: media.duration.ticks, by: Int(step.ticks)).map { Time(ticks: $0) }
    }

    /// Whole tiles that cover the width, 0 for 0.
    public static func tileCount(width: Double, tile: Double) -> Int {
        guard width.isFinite, tile.isFinite, width > 0, tile > 0 else {
            return 0
        }
        return Int((width / tile).rounded(.up))
    }

    /// The made time nearest the source time under the tile's left edge, never past the last made.
    public static func frameTime(of clip: Clip, media: MediaInfo, tile index: Int, tile: Double, scale: TimelineScale) -> Time {
        // The count of `times(of:)`, without making the list for every tile.
        let made = media.kind == .photo ? 1 : (media.duration.ticks + step.ticks - 1) / step.ticks
        let source = Double(clip.sourceStart.ticks) + Double(index) * tile * 600 / scale.pointsPerSecond
        guard made > 1, source.isFinite else {
            return Time.zero
        }
        let nearest = min(max((source / Double(step.ticks)).rounded(), 0), Double(made - 1))
        return Time(ticks: Int64(nearest) * step.ticks)
    }
}
