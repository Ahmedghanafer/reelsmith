import Foundation

public struct DraftID: Hashable, Codable, Sendable {
    /// A UUID string, the name of the draft's folder.
    public let raw: String

    public init(_ raw: String) {
        self.raw = raw
    }
}

/// The stored form of a project: what `draft.json` holds.
public struct Draft: Equatable, Codable, Sendable {
    public static let version: Int = 1

    /// Draft.version when made.
    public var version: Int
    public var project: Project
    public var exportSettings: ExportSettings
    /// The time of the write.
    public var changed: Date

    public init(project: Project, exportSettings: ExportSettings, changed: Date) {
        version = Draft.version
        self.project = project
        self.exportSettings = exportSettings
        self.changed = changed
    }
}

public enum DraftError: Error, Equatable, Sendable {
    /// No draft.json, not the JSON of a Draft, or a version above Draft.version.
    case unreadable
    case cannotWrite
}

/// JSON with sorted keys and the standard coding of a date.
public func encodeDraft(_ draft: Draft) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(draft)
}

/// Every failure, and a version above Draft.version, throws unreadable.
public func decodeDraft(_ data: Data) throws -> Draft {
    let draft: Draft
    do {
        draft = try JSONDecoder().decode(Draft.self, from: data)
    } catch {
        throw DraftError.unreadable
    }
    guard draft.version <= Draft.version else {
        throw DraftError.unreadable
    }
    return draft
}

extension Project {
    /// The file name of every media a clip uses, and of the music, each once, sorted.
    public var fileNames: [String] {
        var names = Set<String>()
        for clip in clips {
            if let info = media[clip.media] {
                names.insert(info.fileName)
            }
        }
        if let music {
            names.insert(music.file.fileName)
        }
        return names.sorted()
    }

    /// Takes out every clip whose media has no facts or whose file name is not in present, every media fact no kept
    /// clip uses, and the music when its file name is not in present. Canvas, texts, ids, volume and mute are kept.
    public func keepingFiles(_ present: Set<String>) -> Project {
        var project = self
        project.clips = clips.filter { clip in
            guard let info = media[clip.media] else {
                return false
            }
            return present.contains(info.fileName)
        }
        let used = Set(project.clips.map(\.media))
        project.media = media.filter { used.contains($0.key) }
        if let music, !present.contains(music.file.fileName) {
            project.music = nil
        }
        return project
    }
}

/// What the list of drafts shows of one draft.
public struct DraftSummary: Equatable, Sendable {
    public var id: DraftID
    /// Nil for an unreadable draft.
    public var changed: Date?
    /// Zero for an unreadable draft.
    public var duration: Time
    public var clipCount: Int
    public var textCount: Int
    /// Standard for an unreadable draft.
    public var exportSettings: ExportSettings
    public var hasCover: Bool

    public init(id: DraftID, draft: Draft, hasCover: Bool) {
        self.id = id
        changed = draft.changed
        duration = draft.project.duration
        clipCount = draft.project.clips.count
        textCount = draft.project.texts.count
        exportSettings = draft.exportSettings
        self.hasCover = hasCover
    }

    private init(unreadable id: DraftID, hasCover: Bool) {
        self.id = id
        changed = nil
        duration = .zero
        clipCount = 0
        textCount = 0
        exportSettings = .standard
        self.hasCover = hasCover
    }

    public static func unreadable(_ id: DraftID, hasCover: Bool) -> DraftSummary {
        DraftSummary(unreadable: id, hasCover: hasCover)
    }

    /// Changed is not nil.
    public var isReadable: Bool {
        changed != nil
    }
}

/// "2026-10-14 21:05": the Gregorian calendar, 24 hours, the digits 0 to 9 in every language.
public func dateText(_ date: Date, in zone: TimeZone) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    func padded(_ value: Int?, _ width: Int) -> String {
        let digits = String(value ?? 0)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }
    return padded(parts.year, 4) + "-" + padded(parts.month, 2) + "-" + padded(parts.day, 2) + " "
        + padded(parts.hour, 2) + ":" + padded(parts.minute, 2)
}

/// The count, then one field for each summary in its order, one space between them. A readable one is
/// "<clips>+<duration ticks>+<texts>+<shortSide>x<framesPerSecond>+<c or .>", c when it has a cover.
/// An unreadable one is "x". "0" for none. Example: "2 1+1800+1+720x60+c 2+4200+0+1080x30+."
public func draftsInfo(_ summaries: [DraftSummary]) -> String {
    var fields = [String(summaries.count)]
    for summary in summaries {
        guard summary.isReadable else {
            fields.append("x")
            continue
        }
        fields.append(
            String(summary.clipCount) + "+" + String(summary.duration.ticks) + "+" + String(summary.textCount) + "+"
                + String(summary.exportSettings.size.shortSide) + "x"
                + String(summary.exportSettings.rate.framesPerSecond) + "+" + (summary.hasCover ? "c" : "."))
    }
    return fields.joined(separator: " ")
}
