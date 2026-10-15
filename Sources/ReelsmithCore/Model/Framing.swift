// How the picture of a clip stands on the canvas: fit or fill, the backdrop of its bars, a zoom and an offset.

public enum Fit: String, Equatable, Codable, Sendable {
    /// Whole inside the canvas.
    case fit
    /// Covering the canvas.
    case fill
}

public enum Backdrop: String, Equatable, Codable, Sendable {
    case black
    /// The picture itself, filling the canvas and blurred, under the bars.
    case blurred
}

public struct Framing: Equatable, Codable, Sendable {
    public var fit: Fit
    public var backdrop: Backdrop
    /// 1 to 4.
    public var zoom: Double
    /// The picture's centre from the canvas centre, a share of the canvas width.
    public var x: Double
    /// The same, a share of the canvas height, positive down.
    public var y: Double

    public init(fit: Fit = .fit, backdrop: Backdrop = .black, zoom: Double = 1, x: Double = 0, y: Double = 0) {
        self.fit = fit
        self.backdrop = backdrop
        self.zoom = zoom
        self.x = x
        self.y = y
    }

    /// Fit, black, zoom 1, centred: the placement of every clip before framing.
    public static let standard: Framing = Framing()
    public static let leastZoom: Double = 1
    public static let mostZoom: Double = 4

    /// The zoom held from 1 to 4, then on each axis the offset held so the picture's near edge lies between
    /// min(0, W minus w) and max(0, W minus w), for a picture of that upright size on the canvas (rule 84).
    /// An offset inside its limits is kept as it is.
    public func held(uprightWidth: Double, uprightHeight: Double, canvas: Canvas) -> Framing {
        var framing = self
        framing.zoom = min(max(zoom, Framing.leastZoom), Framing.mostZoom)
        let width = Double(canvas.width)
        let height = Double(canvas.height)
        let size = framing.size(uprightWidth: uprightWidth, uprightHeight: uprightHeight, width: width, height: height)
        framing.x = heldShare(x, picture: size.width, canvas: width)
        framing.y = heldShare(y, picture: size.height, canvas: height)
        return framing
    }

    /// The fit size (whole inside width by height) or the fill size (covering it), times the zoom. The side that
    /// limits takes the width or the height itself, so the standard framing gives the fit of before to the bit.
    func size(uprightWidth: Double, uprightHeight: Double, width: Double, height: Double)
        -> (width: Double, height: Double)
    {
        var sizeWidth = width
        var sizeHeight = height
        let wider = uprightWidth * height > uprightHeight * width
        if wider == (fit == .fit) {
            sizeHeight = uprightHeight * width / uprightWidth
        } else {
            sizeWidth = uprightWidth * height / uprightHeight
        }
        return (sizeWidth * zoom, sizeHeight * zoom)
    }
}

/// The near edge of a picture of that length on that axis, centred plus the share of the canvas, held between
/// min(0, canvas minus picture) and max(0, canvas minus picture).
func nearEdge(_ share: Double, picture: Double, canvas: Double) -> Double {
    let edge = (canvas - picture) / 2 + share * canvas
    return min(max(edge, min(0, canvas - picture)), max(0, canvas - picture))
}

/// The share kept when its edge lies inside the limits, else the share of the held edge.
private func heldShare(_ share: Double, picture: Double, canvas: Double) -> Double {
    let middle = (canvas - picture) / 2
    let edge = middle + share * canvas
    let held = nearEdge(share, picture: picture, canvas: canvas)
    return held == edge ? share : (held - middle) / canvas
}
