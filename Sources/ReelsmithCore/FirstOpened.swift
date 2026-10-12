import Foundation

public enum FirstOpened: Equatable {
    case date(Date)
    case unavailable
}

/// The date the app first ran, kept in a file in `folder`.
public func firstOpened(in folder: URL, now: Date) -> FirstOpened {
    .unavailable
}
