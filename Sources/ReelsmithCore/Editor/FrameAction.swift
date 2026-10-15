public enum FrameAction: Equatable, Sendable {
    case setFit(ClipID, Fit)
    case setBackdrop(ClipID, Backdrop)
    /// Held 1 to 4, offset held again.
    case setZoom(ClipID, Double)
    /// Held by rule 84.
    case setOffset(ClipID, x: Double, y: Double)
    /// Every clip takes the fit and the backdrop of the named clip and keeps its zoom and offset, held again.
    case applyToAll(ClipID)
}
