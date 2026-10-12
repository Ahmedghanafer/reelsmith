import Foundation

public enum FirstOpened: Equatable {
    case date(Date)
    case unavailable
}

/// The date the app first ran, kept in a file in `folder`.
public func firstOpened(in folder: URL, now: Date) -> FirstOpened {
    let file = folder.appendingPathComponent("first-opened.txt")
    if FileManager.default.fileExists(atPath: file.path) {
        guard let text = try? String(contentsOf: file, encoding: .utf8), let seconds = Double(text) else {
            return .unavailable
        }
        return .date(Date(timeIntervalSince1970: seconds))
    }
    do {
        try String(now.timeIntervalSince1970).write(to: file, atomically: true, encoding: .utf8)
        return .date(now)
    } catch {
        return .unavailable
    }
}
