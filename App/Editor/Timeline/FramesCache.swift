import CoreGraphics
import Foundation
import ReelsmithCore
import ReelsmithEngine
import UIKit

/// The frames of each media of one strip view, kept in memory while the view lives, so an editor makes them once
/// per media while it is open. They are made off the main actor and never written into `Media`.
///
/// https://developer.apple.com/documentation/swift/task/detached(priority:operation:)-d24l
@MainActor
final class FramesCache {
    /// Called when the frames of a media come, to draw them.
    var changed: @MainActor () -> Void = {}
    private var made: [MediaID: [Time: CGImage]] = [:]
    private var asked: Set<MediaID> = []

    /// The media whose frames came.
    var madeCount: Int {
        made.values.filter { !$0.isEmpty }.count
    }

    /// The frames of the media, or nil while they are made. The first ask starts making them. A media whose
    /// frames cannot be made has none, and is not asked for again.
    func frames(of media: MediaInfo, in folder: URL) -> [Time: CGImage]? {
        if let frames = made[media.id] {
            return frames
        }
        guard !asked.contains(media.id) else {
            return nil
        }
        asked.insert(media.id)
        Task { [weak self] in
            let frames = await Task.detached {
                (try? await makeBlockFrames(of: media, mediaFolder: folder)) ?? [:]
            }.value
            self?.made[media.id] = frames
            self?.changed()
        }
        return nil
    }
}

/// The tiles of one block: squares as high as the clip row from its left end, each the made frame of its time,
/// filling its square. The element `editor.frames.<n>` with the value "<tiles> <drawn> <made>".
///
/// https://developer.apple.com/documentation/uikit/uiimageview
/// https://developer.apple.com/documentation/uikit/uiview/contentmode-swift.property
/// https://developer.apple.com/documentation/uikit/uiview/clipstobounds
final class FrameTiles: UIView {
    private var tiles: [UIImageView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        semanticContentAttribute = .forceLeftToRight
        clipsToBounds = true
        isUserInteractionEnabled = false
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) {
        return nil
    }

    /// One tile for each image, in order from the left, `side` points square. A nil image is a tile not drawn yet.
    func show(_ images: [CGImage?], side: CGFloat, made: Int) {
        while tiles.count > images.count {
            tiles.removeLast().removeFromSuperview()
        }
        while tiles.count < images.count {
            let tile = UIImageView()
            tile.contentMode = .scaleAspectFill
            tile.clipsToBounds = true
            addSubview(tile)
            tiles.append(tile)
        }
        var drawn = 0
        for (index, (tile, image)) in zip(tiles, images).enumerated() {
            tile.frame = CGRect(x: CGFloat(index) * side, y: 0, width: side, height: side)
            if let image {
                if tile.image?.cgImage !== image {
                    tile.image = UIImage(cgImage: image)
                }
                drawn += 1
            } else {
                tile.image = nil
            }
        }
        accessibilityValue = String(images.count) + " " + String(drawn) + " " + String(made)
    }
}
